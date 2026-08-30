// ohos_wasm3_ffi.dart
//
// Low-level dart:ffi bindings to libwasm3.so (the wasm3 interpreter + our
// C ABI bridge, see ohos/entry/src/main/cpp/wasm3_bridge.h). This file only
// declares the raw C functions and small helper views; the higher-level
// WasmModule/WasmInstance implementation lives in ohos_wasm_runtime.dart.
//
// Only loaded on OpenHarmony.

import 'dart:ffi';
import 'package:ffi/ffi.dart' show Utf8;

/// Opaque handle to a wasm3 object (environment/runtime/module/function).
typedef WbHandle = Pointer<Void>;

/// Native signature of the host callback (must use only dart:ffi types).
/// Both the `lookupFunction` native type and the `NativeCallable` generic use
/// this same function type, since it already consists solely of dart:ffi
/// types (Pointer/Uint64/Void).
typedef WbHostCall = Pointer<Void> Function(
  Pointer<Void> runtime,
  Pointer<Void> userdata,
  Pointer<Uint64> sp,
  Pointer<Void> mem,
);

/// Binds the wasm3 bridge shared library.
final class Wasm3Bindings {
  Wasm3Bindings._(this._lib);

  final DynamicLibrary _lib;

  static Wasm3Bindings? _instance;

  /// Opens libwasm3.so. The .so is packaged into the HAP under the app's
  /// native library dir; on OpenHarmony `DynamicLibrary.open('libwasm3.so')`
  /// resolves it from there.
  static Wasm3Bindings open() {
    return _instance ??= Wasm3Bindings._(DynamicLibrary.open('libwasm3.so'));
  }

  late final Pointer<Void> Function() newEnvironment = _lib
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'wb_wasm_new_environment',
      );

  late final void Function(Pointer<Void>) freeEnvironment = _lib
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'wb_wasm_free_environment',
      );

  late final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>)
      newRuntime = _lib.lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Uint32, Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>)>(
        'wb_wasm_new_runtime',
      );

  late final void Function(Pointer<Void>) freeRuntime = _lib
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'wb_wasm_free_runtime',
      );

  late final int Function(Pointer<Void>, Pointer<Utf8>, int) getError = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32),
        int Function(Pointer<Void>, Pointer<Utf8>, int)>(
        'wb_wasm_get_error',
      );

  late final Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, int)
      compile = _lib.lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, Uint32),
        Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, int)>(
        'wb_wasm_compile',
      );

  late final int Function(Pointer<Void>) instantiate = _lib
      .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'wb_wasm_instantiate',
      );

  late final void Function(Pointer<Void>) freeModule = _lib
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'wb_wasm_free_module',
      );

  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<NativeFunction<WbHostCall>>,
    Pointer<Void>,
  ) linkFunction = _lib.lookupFunction<
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<NativeFunction<WbHostCall>>,
      Pointer<Void>,
    ),
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<NativeFunction<WbHostCall>>,
      Pointer<Void>,
    )>('wb_wasm_link_function');

  late final int Function(Pointer<Pointer<Void>>, Pointer<Void>, Pointer<Utf8>)
      findFunction = _lib.lookupFunction<
        Int32 Function(Pointer<Pointer<Void>>, Pointer<Void>, Pointer<Utf8>),
        int Function(Pointer<Pointer<Void>>, Pointer<Void>, Pointer<Utf8>)>(
        'wb_wasm_find_function',
      );

  late final int Function(
    Pointer<Void>,
    Pointer<Uint64>,
    int,
    Pointer<Uint64>,
    int,
  ) call = _lib.lookupFunction<
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint64>,
      Uint32,
      Pointer<Uint64>,
      Uint32,
    ),
    int Function(
      Pointer<Void>,
      Pointer<Uint64>,
      int,
      Pointer<Uint64>,
      int,
    )>('wb_wasm_call');

  late final int Function(Pointer<Void>) argCount = _lib
      .lookupFunction<Uint32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'wb_wasm_arg_count',
      );

  late final int Function(Pointer<Void>) retCount = _lib
      .lookupFunction<Uint32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'wb_wasm_ret_count',
      );

  late final int Function(Pointer<Void>, int) argType = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int)>(
        'wb_wasm_arg_type',
      );

  late final int Function(Pointer<Void>, int) retType = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int)>(
        'wb_wasm_ret_type',
      );

  late final Pointer<Uint8> Function(Pointer<Void>, int, Pointer<Uint64>)
      getMemory = _lib.lookupFunction<
        Pointer<Uint8> Function(Pointer<Void>, Uint32, Pointer<Uint64>),
        Pointer<Uint8> Function(Pointer<Void>, int, Pointer<Uint64>)>(
        'wb_wasm_get_memory',
      );

  late final int Function(Pointer<Void>) memoryPages = _lib
      .lookupFunction<Uint32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'wb_wasm_memory_pages',
      );

  late final int Function(Pointer<Void>, int) growMemory = _lib
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int)>(
        'wb_wasm_grow_memory',
      );
}
