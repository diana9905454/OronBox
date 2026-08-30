import 'package:flutter/services.dart';

/// Encodes RGBA pixels to WebP using the OpenHarmony native ImagePacker.
///
/// wasm3 (the interpreter backend for `package:wasm_run` on OpenHarmony) cannot
/// load `webp_encoder.wasm`: zig compiles it as a freestanding module whose
/// data segments live at 0x08000000, far beyond the 16 MB linear memory it
/// declares, and wasm3's `InitDataSegments` fails the out-of-bounds check.
/// OpenHarmony's own ImagePacker encodes WebP natively, so we use it instead.
///
/// The native side is `ImageEncodeBridge` (MethodChannel "oronbox/image_encode").
final class OhosWebpEncoder {
  const OhosWebpEncoder._();

  /// Shared encoder; the MethodChannel is stateless so a single instance
  /// serves the whole app.
  static final OhosWebpEncoder instance = OhosWebpEncoder._();

  static const _channel = MethodChannel('oronbox/image_encode');

  /// Encodes [rgba] (width * height * 4 bytes, RGBA order) as WebP.
  ///
  /// Returns null on failure so callers can fall back, mirroring
  /// [WasmWebpEncoder.encode]'s contract.
  Future<Uint8List?> encode(
    Uint8List rgba,
    int width,
    int height, {
    double quality = 75,
  }) async {
    try {
      final Object? result = await _channel.invokeMethod<Object>(
        'encodeWebp',
        <String, Object>{
          'rgba': rgba,
          'width': width,
          'height': height,
          'quality': quality,
        },
      );
      if (result is Uint8List) return result;
      if (result is List<int>) return Uint8List.fromList(result);
      return null;
    } catch (_) {
      return null;
    }
  }
}
