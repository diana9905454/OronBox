// ohos_wasm_runtime.dart
//
// OpenHarmony implementation of the wasm_run interface, backed by wasm3 via
// dart:ffi (see ohos_wasm3_ffi.dart and the native bridge in
// ohos/entry/src/main/cpp/).
//
// It implements the *same* public abstract interfaces that package:wasm_run
// exports (WasmModule, WasmInstance, WasmInstanceBuilder, WasmMemory, ...) so
// that the rest of the OronBox code (opus decoder, webp encoder) keeps
// compiling unchanged — only the runtime backend differs on OpenHarmony.
//
// Because wasm3 is a simple interpreter, we support the subset of wasm
// features the OronBox assets actually use: single linear memory, host
// function imports with i32/i64/f32/f64 params/returns, and exported
// functions of the same value types. WASI and threads are not supported.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' show malloc, Utf8, StringUtf8Pointer;

import 'package:wasm_run/wasm_run.dart'
    show
        ValueTy,
        WasmModule,
        WasmInstance,
        WasmInstanceBuilder,
        WasmMemory,
        WasmFunction,
        WasmExternal,
        WasmExternalKind,
        WasmModuleImport,
        WasmModuleExport,
        WasmGlobal,
        WasmTable,
        WasiConfig,
        WasmImport,
        WasmInstanceFuel;

// ignore: implementation_imports
import 'package:wasm_run/src/wasm_bindings/wasm_interface.dart'
    show
        // ignore: experimental_member_use
        WasmSharedMemory,
        WasmValue,
        MemoryTy,
        WasiFile;

import 'ohos_wasm3_ffi.dart';

/// Compiles a wasm binary on OpenHarmony using the wasm3 interpreter.
Future<WasmModule> compileWasmModule(
  Uint8List bytes, {
  Object? config,
}) async {
  return compileWasmModuleSync(bytes, config: config);
}

/// Synchronous compile (wasm3 parses synchronously anyway).
WasmModule compileWasmModuleSync(
  Uint8List bytes, {
  Object? config,
}) {
  final bindings = Wasm3Bindings.open();

  final env = bindings.newEnvironment();
  if (env == nullptr) {
    throw StateError('wasm3: failed to create environment');
  }

  // A runtime per module keeps memory/instances isolated and lifetime simple.
  // 512 KB of interpreter stack is plenty for opus/webp decode.
  const stackSize = 512 * 1024;
  final runtime = bindings.newRuntime(env, stackSize, nullptr);
  if (runtime == nullptr) {
    bindings.freeEnvironment(env);
    throw StateError('wasm3: failed to create runtime');
  }

  final bytesPtr = malloc.allocate<Uint8>(bytes.length);
  try {
    bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
    final module = bindings.compile(runtime, bytesPtr, bytes.length);
    if (module == nullptr) {
      bindings.freeRuntime(runtime);
      bindings.freeEnvironment(env);
      throw StateError('wasm3: compile failed: ${_error(bindings, runtime)}');
    }
    return _OhosWasmModule._(bindings, env, runtime, module);
  } finally {
    malloc.free(bytesPtr);
  }
}

String _error(Wasm3Bindings b, Pointer<Void> runtime) {
  final buf = malloc.allocate<Uint8>(512);
  try {
    final n = b.getError(runtime, buf.cast<Utf8>(), 512);
    if (n <= 0) return 'unknown error';
    return String.fromCharCodes(buf.asTypedList(n));
  } finally {
    malloc.free(buf);
  }
}

/// Maps a wasm3 type id (see wasm3_bridge.h type ids:
/// 0=none 1=i32 2=i64 3=f32 4=f64) to a [ValueTy].
ValueTy _typeFromId(int id) => switch (id) {
      1 => ValueTy.i32,
      2 => ValueTy.i64,
      3 => ValueTy.f32,
      4 => ValueTy.f64,
      _ => ValueTy.i32,
    };

final class _OhosWasmModule implements WasmModule {
  _OhosWasmModule._(this._bindings, this._env, this._runtime, this._module);

  final Wasm3Bindings _bindings;
  final Pointer<Void> _env;
  final Pointer<Void> _runtime;
  final Pointer<Void> _module;

  bool _disposed = false;

  Pointer<Void> get moduleHandle => _module;
  Pointer<Void> get runtimeHandle => _runtime;
  Wasm3Bindings get bindings => _bindings;

  @override
  WasmInstanceBuilder builder({WasiConfig? wasiConfig, Object? workersConfig}) {
    return _OhosWasmInstanceBuilder._(this, wasiConfig);
  }

  @override
  // ignore: experimental_member_use
  WasmSharedMemory createSharedMemory({
    required int minPages,
    required int maxPages,
  }) {
    throw UnsupportedError('wasm3: shared memory not supported');
  }

  @override
  List<WasmModuleImport> getImports() {
    // wasm3 does not expose a full import/export reflection API through our
    // minimal bridge. The OronBox assets never call these, so return empty.
    return const [];
  }

  @override
  List<WasmModuleExport> getExports() {
    return const [];
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Freeing the runtime releases any loaded module and the environment.
    _bindings.freeRuntime(_runtime);
    _bindings.freeEnvironment(_env);
  }
}

final class _OhosWasmInstanceBuilder implements WasmInstanceBuilder {
  _OhosWasmInstanceBuilder._(this._module, WasiConfig? wasiConfig);

  final _OhosWasmModule _module;

  final List<_PendingImport> _imports = [];

  @override
  WasmModule get module => _module;

  @override
  WasmMemory createMemory({required int minPages, int? maxPages}) {
    throw UnsupportedError('wasm3: explicit memory creation not supported');
  }

  @override
  WasmGlobal createGlobal(WasmValue value, {required bool mutable}) {
    throw UnsupportedError('wasm3: global creation not supported');
  }

  @override
  WasmTable createTable({
    required WasmValue value,
    required int minSize,
    int? maxSize,
  }) {
    throw UnsupportedError('wasm3: table creation not supported');
  }

  @override
  WasmInstanceBuilder addImport(
    String moduleName,
    String name,
    WasmExternal value,
  ) {
    if (value is WasmFunction) {
      _imports.add(_PendingImport(moduleName, name, value));
    }
    // Ignore non-function imports (wasm3 memory/global/table imports are not
    // used by our assets).
    return this;
  }

  @override
  WasmInstanceBuilder addImports(List<WasmImport> imports) {
    for (final import in imports) {
      addImport(import.moduleName, import.name, import.value);
    }
    return this;
  }

  @override
  WasmInstanceFuel? fuel() => null;

  @override
  Future<WasmInstance> build() async => buildSync();

  @override
  WasmInstance buildSync() {
    final b = _module.bindings;

    // 1. Link all host function imports against the (parsed, not-yet-loaded)
    //    module. wasm3 links imports before instantiation.
    for (final imp in _imports) {
      _linkImport(b, _module, imp);
    }

    // 2. Instantiate (load) the module now that all imports are linked.
    final rc = b.instantiate(_module.moduleHandle);
    if (rc != 0) {
      throw StateError(
        'wasm3: instantiate failed: ${_error(b, _module.runtimeHandle)}',
      );
    }

    return _OhosWasmInstance._(_module);
  }
}

class _PendingImport {
  _PendingImport(this.moduleName, this.name, this.function);
  final String moduleName;
  final String name;
  final WasmFunction function;
}

/// Registers a host function import with wasm3 against [module].
void _linkImport(
  Wasm3Bindings b,
  _OhosWasmModule module,
  _PendingImport imp,
) {
  // Build the wasm3 signature string from the Dart WasmFunction.
  final params = imp.function.params;
  final results = imp.function.results ?? const <ValueTy>[];

  String sigChar(ValueTy t) => switch (t) {
        ValueTy.i32 => 'i',
        ValueTy.i64 => 'I',
        ValueTy.f32 => 'f',
        ValueTy.f64 => 'F',
        _ => 'i',
      };

  // wasm3's signature language requires a leading return-type token even for
  // void returns: "v(i)", not "(i)". An empty result list must map to 'v'.
  final retPart = results.isEmpty ? 'v' : results.map(sigChar).join();
  final argPart = params.map((p) => sigChar(p ?? ValueTy.i32)).join();
  final signature = '$retPart($argPart)';

  // Create a Dart callback trampoline that marshals the raw wasm3 stack.
  // The NativeCallable is stored globally to keep it alive; the returned
  // nativeFunction pointer is handed to wasm3.
  final callable = _makeHostCall(imp.function);
  _hostCallRegistry.add(callable);

  final modNamePtr = imp.moduleName.toNativeUtf8();
  final namePtr = imp.name.toNativeUtf8();
  final sigPtr = signature.toNativeUtf8();
  try {
    final rc = b.linkFunction(
      module.moduleHandle,
      modNamePtr,
      namePtr,
      sigPtr,
      callable.nativeFunction,
      nullptr,
    );
    if (rc != 0) {
      throw StateError(
        'wasm3: link import ${imp.moduleName}.${imp.name} failed: '
        '${_error(b, module.runtimeHandle)}',
      );
    }
  } finally {
    malloc.free(modNamePtr);
    malloc.free(namePtr);
    malloc.free(sigPtr);
  }
}

/// Global registry to keep host-call callables alive (prevent GC).
final List<NativeCallable<WbHostCall>> _hostCallRegistry = [];

final class _OhosWasmInstance implements WasmInstance {
  _OhosWasmInstance._(this._module);

  final _OhosWasmModule _module;

  late final Map<String, WasmExternal> _exports = <String, WasmExternal>{};

  @override
  WasmModule get module => _module;

  @override
  WasmFunction? getFunction(String name) {
    final b = _module.bindings;
    final out = malloc.allocate<Pointer<Void>>(1);
    try {
      final namePtr = name.toNativeUtf8();
      try {
        final found = b.findFunction(out, _module.runtimeHandle, namePtr);
        if (found == 0) return null;
        final fn = out.value;
        return _wrapExportedFunction(b, fn);
      } finally {
        malloc.free(namePtr);
      }
    } finally {
      malloc.free(out);
    }
  }

  @override
  WasmGlobal? getGlobal(String name) => null;

  @override
  WasmTable? getTable(String name) => null;

  @override
  WasmMemory? getMemory(String name) {
    final b = _module.bindings;
    final sizePtr = malloc.allocate<Uint64>(1);
    try {
      final mem = b.getMemory(_module.moduleHandle, 0, sizePtr);
      if (mem == nullptr) return null;
      return _OhosWasmMemory._(b, mem, sizePtr.value, _module.moduleHandle);
    } finally {
      malloc.free(sizePtr);
    }
  }

  @override
  T? getExportTyped<T extends WasmExternal>(String name) {
    final e = switch (name) {
      _ when name == 'memory' => getMemory(name),
      _ => getFunction(name),
    };
    return e is T ? e : null;
  }

  @override
  Future<List<List<Object?>>> runParallel(
    WasmFunction function,
    List<List<Object?>> argsLists,
  ) {
    throw UnsupportedError('wasm3: runParallel not supported');
  }

  @override
  WasmInstanceFuel? fuel() => null;

  @override
  Map<String, WasmExternal> get exports => _exports;

  @override
  Future<WasiFile?> wasiOpenFile(
    String path, {
    bool create = false,
    bool truncate = false,
    bool exclusive = false,
  }) async {
    return null;
  }

  @override
  Stream<Uint8List> get stderr => const Stream.empty();

  @override
  Stream<Uint8List> get stdout => const Stream.empty();

  @override
  void dispose() {
    // Instances share the module's runtime; disposal of the module frees it.
    // Nothing per-instance to release in wasm3.
  }
}

/// Wraps a wasm3 exported function into a [WasmFunction].
WasmFunction _wrapExportedFunction(Wasm3Bindings b, Pointer<Void> fn) {
  final argCount = b.argCount(fn);
  final retCount = b.retCount(fn);

  final params = List<ValueTy>.generate(
    argCount,
    (i) => _typeFromId(b.argType(fn, i)),
  );
  final results = List<ValueTy>.generate(
    retCount,
    (i) => _typeFromId(b.retType(fn, i)),
  );

  List<Object?> call([List<Object?>? args]) {
    final argList = args ?? const [];
    if (argList.length != argCount) {
      throw StateError(
        'wasm3: expected $argCount arguments, got ${argList.length}',
      );
    }

    // Pack arguments into 64-bit slots.
    final argSlots = malloc.allocate<Uint64>(argCount == 0 ? 1 : argCount);
    final retSlots = malloc.allocate<Uint64>(retCount == 0 ? 1 : retCount);
    try {
      for (var i = 0; i < argCount; i++) {
        argSlots[i] = _encodeValue(argList[i], params[i]);
      }

      final rc = b.call(fn, argSlots, argCount, retSlots, retCount);
      if (rc != 0) {
        throw StateError('wasm3: call failed (code $rc)');
      }

      if (retCount == 0) return const [];
      return List<Object?>.generate(
        retCount,
        (i) => _decodeValue(retSlots[i], results[i]),
      );
    } finally {
      malloc.free(argSlots);
      malloc.free(retSlots);
    }
  }

  return WasmFunction(
    _noop,
    params: params,
    results: results,
    call: call,
  );
}

void _noop() {}

/// Encodes a Dart value into a 64-bit slot for the C bridge.
int _encodeValue(Object? v, ValueTy t) {
  switch (t) {
    case ValueTy.i32:
      return (v as int) & 0xFFFFFFFF;
    case ValueTy.i64:
      return v as int;
    case ValueTy.f32:
      // Encode as the f32 bit pattern in the low 32 bits.
      final f = v as double;
      final bytes = ByteData(4)..setFloat32(0, f, Endian.little);
      return bytes.getUint32(0);
    case ValueTy.f64:
      final f = v as double;
      final bytes = ByteData(8)..setFloat64(0, f, Endian.little);
      return bytes.getUint64(0);
    default:
      return (v as num?)?.toInt() ?? 0;
  }
}

/// Decodes a 64-bit slot into a Dart value.
Object? _decodeValue(int slot, ValueTy t) {
  switch (t) {
    case ValueTy.i32:
      return (slot & 0xFFFFFFFF).toSigned(32);
    case ValueTy.i64:
      return slot.toSigned(64);
    case ValueTy.f32:
      final bytes = ByteData(4)..setUint32(0, slot & 0xFFFFFFFF, Endian.little);
      return bytes.getFloat32(0);
    case ValueTy.f64:
      final bytes = ByteData(8)..setUint64(0, slot, Endian.little);
      return bytes.getFloat64(0);
    default:
      return slot;
  }
}

/// Creates a native trampoline for a host import function.
///
/// Returns a [NativeCallable] that the caller must keep alive (stored in
/// [_hostCallRegistry]).
NativeCallable<WbHostCall> _makeHostCall(WasmFunction function) {
  final params = function.params;
  final results = function.results ?? const <ValueTy>[];

  Pointer<Void> trampoline(
    Pointer<Void> runtime,
    Pointer<Void> userdata,
    Pointer<Uint64> sp,
    Pointer<Void> mem,
  ) {
    // `sp` points at return slots first, then arguments.
    // wasm3 uses 64-bit slots in the raw call stack.
    final nParams = params.length;
    final nRets = results.length;

    // Read arguments (they follow the return slots).
    final args = <Object?>[];
    for (var i = 0; i < nParams; i++) {
      final slot = (sp + (nRets + i)).value;
      final t = params[i] ?? ValueTy.i32;
      args.add(_decodeHostArg(slot, t));
    }

    // Call the Dart function.
    final out = function.call(args);

    // Write return values back into the return slots.
    for (var i = 0; i < nRets; i++) {
      final val = out.length > i ? out[i] : null;
      final t = results[i];
      (sp + i).value = _encodeHostRet(val, t);
    }

    // Return m3Err_none (null pointer == 0).
    return nullptr;
  }

  return NativeCallable<WbHostCall>.isolateLocal(trampoline);
}

Object? _decodeHostArg(int slot, ValueTy t) => _decodeValue(slot, t);

int _encodeHostRet(Object? v, ValueTy t) => _encodeValue(v, t);

final class _OhosWasmMemory implements WasmMemory {
  _OhosWasmMemory._(this._bindings, this._base, this._sizeBytes, this._module);

  final Wasm3Bindings _bindings;
  final Pointer<Uint8> _base;
  final int _sizeBytes;
  final Pointer<Void> _module;

  @override
  void grow(int deltaPages) {
    _bindings.growMemory(_module, deltaPages);
  }

  @override
  int get lengthInBytes => _sizeBytes;

  @override
  int get lengthInPages => _sizeBytes ~/ WasmMemory.bytesPerPage;

  @override
  Uint8List get view => _base.asTypedList(_sizeBytes);

  @override
  MemoryTy? get type => null;

  @override
  T when<T>({
    required T Function(WasmMemory memory) memory,
    required T Function(WasmTable table) table,
    required T Function(WasmGlobal global) global,
    required T Function(WasmFunction function) function,
  }) =>
      memory(this);

  @override
  WasmExternalKind get kind => WasmExternalKind.memory;
}
