// ohos_wasm_runtime_stub.dart
//
// Web-only stub for the OpenHarmony wasm3 backend. The real backend
// (ohos_wasm_runtime.dart) pulls in `dart:ffi`, which is unavailable on web,
// so this file is substituted via conditional import when building for web.
// It is never reached at runtime on web because the OpenHarmony branch in
// wasm_runtime.dart is guarded by `defaultTargetPlatform == ohos`.

import 'dart:typed_data';

import 'package:wasm_run_flutter/wasm_run_flutter.dart';

/// Unreachable on web: the caller only invokes the ohos backend when running
/// on OpenHarmony.
Future<WasmModule> compileWasmModule(
  Uint8List bytes, {
  Object? config,
}) {
  throw UnsupportedError('OpenHarmony wasm3 backend is not available on web');
}
