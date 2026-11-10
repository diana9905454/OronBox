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

/// Prepares a reusable wasm3 module. Native parsing happens per instance.
Future<WasmModule> compileWasmModule(Uint8List bytes, {Object? config}) async {
  return _OhosWasmModule(Uint8List.fromList(bytes));
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
  _OhosWasmModule(this.bytes);

  final Uint8List bytes;

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
    final instance = _OhosWasmInstance.create(_module);
    final b = instance.bindings;
    try {
      // wasm3 must load the module before linking host functions.
      final loadRc = b.loadModule(
        instance.runtimeHandle,
        instance.moduleHandle,
      );
      if (loadRc != 0) {
        throw StateError(
          'wasm3: load module failed: ${_error(b, instance.runtimeHandle)}',
        );
      }

      for (final imp in _imports) {
        _linkImport(b, instance, imp);
      }

      final startRc = b.runStart(instance.moduleHandle);
      if (startRc != 0) {
        throw StateError(
          'wasm3: run start failed: ${_error(b, instance.runtimeHandle)}',
        );
      }
      return instance;
    } catch (_) {
      instance.dispose();
      rethrow;
    }
  }
}

class _PendingImport {
  _PendingImport(this.moduleName, this.name, this.function);
  final String moduleName;
  final String name;
  final WasmFunction function;
}

/// Registers a host function import with wasm3 against [instance].
void _linkImport(
  Wasm3Bindings b,
  _OhosWasmInstance instance,
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
  final callable = _makeHostCall(imp.function);
  instance._hostCalls.add(callable);

  final modNamePtr = imp.moduleName.toNativeUtf8();
  final namePtr = imp.name.toNativeUtf8();
  final sigPtr = signature.toNativeUtf8();
  try {
    final rc = b.linkFunction(
      instance.moduleHandle,
      modNamePtr,
      namePtr,
      sigPtr,
      callable.nativeFunction,
      nullptr,
    );
    if (rc != 0) {
      throw StateError(
        'wasm3: link import ${imp.moduleName}.${imp.name} failed: '
        '${_error(b, instance.runtimeHandle)}',
      );
    }
  } finally {
    malloc.free(modNamePtr);
    malloc.free(namePtr);
    malloc.free(sigPtr);
  }
}

final class _OhosWasmInstance implements WasmInstance {
  _OhosWasmInstance._(
    this._module,
    this.bindings,
    this._environment,
    this.runtimeHandle,
    this.moduleHandle,
    this._bytes,
  );

  factory _OhosWasmInstance.create(_OhosWasmModule module) {
    final b = Wasm3Bindings.open();
    final environment = b.newEnvironment();
    if (environment == nullptr) {
      throw StateError('wasm3: failed to create environment');
    }

    // Each parsed module binds to one runtime. Its byte buffer must also
    // outlive the runtime because wasm3 compiles function bodies lazily.
    Pointer<Void> runtime = nullptr;
    Pointer<Uint8> bytes = nullptr;
    try {
      runtime = b.newRuntime(environment, 512 * 1024, nullptr);
      if (runtime == nullptr) {
        throw StateError('wasm3: failed to create runtime');
      }

      bytes = malloc.allocate<Uint8>(module.bytes.length);
      bytes.asTypedList(module.bytes.length).setAll(0, module.bytes);
      final handle = b.compile(runtime, bytes, module.bytes.length);
      if (handle == nullptr) {
        throw StateError('wasm3: compile failed: ${_error(b, runtime)}');
      }
      return _OhosWasmInstance._(
        module,
        b,
        environment,
        runtime,
        handle,
        bytes,
      );
    } catch (_) {
      if (runtime != nullptr) b.freeRuntime(runtime);
      b.freeEnvironment(environment);
      if (bytes != nullptr) malloc.free(bytes);
      rethrow;
    }
  }

  final _OhosWasmModule _module;
  final Wasm3Bindings bindings;
  final Pointer<Void> _environment;
  final Pointer<Void> runtimeHandle;
  final Pointer<Void> moduleHandle;
  final Pointer<Uint8> _bytes;
  final List<NativeCallable<WbHostCall>> _hostCalls = [];
  bool _disposed = false;

  late final Map<String, WasmExternal> _exports = <String, WasmExternal>{};

  @override
  WasmModule get module => _module;

  @override
  WasmFunction? getFunction(String name) {
    _ensureActive();
    final b = bindings;
    final out = malloc<Pointer<Void>>();
    try {
      final namePtr = name.toNativeUtf8();
      try {
        final found = b.findFunction(out, runtimeHandle, namePtr);
        if (found == 0) return null;
        final fn = out.value;
        return _wrapExportedFunction(b, fn, _ensureActive);
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
    _ensureActive();
    final b = bindings;
    final sizePtr = malloc<Uint64>();
    try {
      final mem = b.getMemory(moduleHandle, 0, sizePtr);
      if (mem == nullptr) return null;
      return _OhosWasmMemory._(
        b,
        mem,
        sizePtr.value,
        moduleHandle,
        _ensureActive,
      );
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
    if (_disposed) return;
    _disposed = true;
    // The bridge frees only parsed modules that were never loaded.
    bindings.freeModule(moduleHandle);
    bindings.freeRuntime(runtimeHandle);
    bindings.freeEnvironment(_environment);
    for (final callable in _hostCalls) {
      callable.close();
    }
    _hostCalls.clear();
    malloc.free(_bytes);
  }

  void _ensureActive() {
    if (_disposed) throw StateError('wasm3: instance is disposed');
  }
}

/// Wraps a wasm3 exported function into a [WasmFunction].
WasmFunction _wrapExportedFunction(
  Wasm3Bindings b,
  Pointer<Void> fn,
  void Function() ensureActive,
) {
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
    ensureActive();
    final argList = args ?? const [];
    if (argList.length != argCount) {
      throw StateError(
        'wasm3: expected $argCount arguments, got ${argList.length}',
      );
    }

    // Pack arguments into 64-bit slots.
    final argSlots = malloc<Uint64>(argCount == 0 ? 1 : argCount);
    final retSlots = malloc<Uint64>(retCount == 0 ? 1 : retCount);
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

  return WasmFunction(_noop, params: params, results: results, call: call);
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
/// The instance retains the [NativeCallable] until its runtime is released.
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
  _OhosWasmMemory._(
    this._bindings,
    this._base,
    this._sizeBytes,
    this._module,
    this._ensureActive,
  );

  final Wasm3Bindings _bindings;
  final Pointer<Uint8> _base;
  final int _sizeBytes;
  final Pointer<Void> _module;
  final void Function() _ensureActive;

  @override
  void grow(int deltaPages) {
    _ensureActive();
    _bindings.growMemory(_module, deltaPages);
  }

  @override
  int get lengthInBytes => _sizeBytes;

  @override
  int get lengthInPages => _sizeBytes ~/ WasmMemory.bytesPerPage;

  @override
  Uint8List get view {
    _ensureActive();
    return _base.asTypedList(_sizeBytes);
  }

  @override
  MemoryTy? get type => null;

  @override
  T when<T>({
    required T Function(WasmMemory memory) memory,
    required T Function(WasmTable table) table,
    required T Function(WasmGlobal global) global,
    required T Function(WasmFunction function) function,
  }) => memory(this);

  @override
  WasmExternalKind get kind => WasmExternalKind.memory;
}
