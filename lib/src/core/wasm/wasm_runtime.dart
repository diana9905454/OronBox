import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wasm_run_flutter/wasm_run_flutter.dart';

import 'ohos_wasm_runtime.dart'
    if (dart.library.html) 'ohos_wasm_runtime_stub.dart' as ohos_backend;

typedef WasmInstanceConfigurator = void Function(WasmInstanceBuilder builder);

final class WasmRuntime {
  WasmRuntime._();

  static final WasmRuntime shared = WasmRuntime._();

  final Map<String, Future<WasmModule>> _compiledModules = {};
  Future<void>? _libraryInitialization;

  WasmScope openScope(String owner) => WasmScope._(this, owner);

  /// Compiles a wasm binary on the correct backend.
  ///
  /// OpenHarmony uses the wasm3 interpreter backend (libwasm3.so via dart:ffi)
  /// because `wasm_run` ships no native dynamic library for it; every other
  /// platform uses the bundled `wasm_run` native runtime.
  Future<WasmModule> _compileModule(Uint8List bytes) {
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      return ohos_backend.compileWasmModule(bytes);
    }
    return compileWasmModule(bytes);
  }

  Future<WasmModule> _compile(
    Uint8List bytes, {
    required String? cacheKey,
  }) async {
    await _ensureLibraryInitialized();

    if (cacheKey == null) return _compileModule(bytes);

    final cached = _compiledModules[cacheKey];
    if (cached != null) return cached;

    late final Future<WasmModule> pending;
    pending = () async {
      try {
        return await _compileModule(bytes);
      } catch (_) {
        if (identical(_compiledModules[cacheKey], pending)) {
          _compiledModules.remove(cacheKey);
        }
        rethrow;
      }
    }();
    _compiledModules[cacheKey] = pending;
    return pending;
  }

  Future<void> _ensureLibraryInitialized() async {
    final pending = _libraryInitialization;
    if (pending != null) {
      return pending;
    }

    // OpenHarmony's wasm3 backend opens libwasm3.so directly and never needs
    // the `wasm_run` native library, whose `setUp` would otherwise try to
    // locate/download a desktop dynamic library and fail on-device with
    // "Could not find package root with .dart_tool/package_config.json".
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      _libraryInitialization = Future<void>.value();
      return;
    }

    final initialization = WasmRunLibrary.setUp(
      override: false,
      isFlutter: true,
      loadAsset: rootBundle.load,
    );
    _libraryInitialization = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_libraryInitialization, initialization)) {
        _libraryInitialization = null;
      }
      rethrow;
    }
  }
}

final class WasmScope {
  WasmScope._(this._runtime, this.owner);

  final WasmRuntime _runtime;
  final String owner;
  final Set<ScopedWasmInstance> _instances = {};
  bool _disposed = false;

  bool get isDisposed => _disposed;

  Future<ScopedWasmInstance> instantiateAsset(
    String assetPath, {
    WasmInstanceConfigurator? configure,
    WasiConfig? wasiConfig,
  }) async {
    _ensureActive();
    final data = await rootBundle.load(assetPath);
    return instantiate(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      cacheKey: 'asset:$assetPath',
      configure: configure,
      wasiConfig: wasiConfig,
    );
  }

  Future<ScopedWasmInstance> instantiate(
    Uint8List bytes, {
    String? cacheKey,
    WasmInstanceConfigurator? configure,
    WasiConfig? wasiConfig,
  }) async {
    _ensureActive();
    final module = await _runtime._compile(bytes, cacheKey: cacheKey);
    _ensureActive();

    final builder = module.builder(wasiConfig: wasiConfig);
    configure?.call(builder);
    final instance = await builder.build();
    if (_disposed) {
      instance.dispose();
      throw StateError('WASM scope "$owner" was disposed during startup');
    }

    late final ScopedWasmInstance scoped;
    scoped = ScopedWasmInstance._(instance, () => _instances.remove(scoped));
    _instances.add(scoped);
    return scoped;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final instance in _instances.toList(growable: false)) {
      instance.dispose();
    }
    _instances.clear();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('WASM scope "$owner" is disposed');
  }
}

final class ScopedWasmInstance {
  ScopedWasmInstance._(this._instance, this._onDispose);

  final WasmInstance _instance;
  final void Function() _onDispose;
  bool _disposed = false;

  Stream<Uint8List> get stdout => _instance.stdout;
  Stream<Uint8List> get stderr => _instance.stderr;

  WasmFunction function(String name) {
    _ensureActive();
    final function = _instance.getFunction(name);
    if (function == null) {
      throw StateError('WASM function "$name" is not exported');
    }
    return function;
  }

  WasmFunction? functionOrNull(String name) {
    _ensureActive();
    return _instance.getFunction(name);
  }

  WasmMemory memory(String name) {
    _ensureActive();
    final memory = _instance.getMemory(name);
    if (memory == null) {
      throw StateError('WASM memory "$name" is not exported');
    }
    return memory;
  }

  List<Object?> call(String name, [List<Object?> arguments = const []]) {
    return function(name).call(arguments);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _instance.dispose();
    _onDispose();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('WASM instance is disposed');
  }
}
