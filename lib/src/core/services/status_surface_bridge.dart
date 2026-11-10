import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('oronbox/status_surfaces');

Future<void> _invoke(String method, [Object? arguments]) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _channel.invokeMethod<void>(method, arguments);
  } on MissingPluginException {
    // The Android host is optional on desktop and during tests.
  } on PlatformException {
    // A widget or notification must never make the Flutter operation fail.
  }
}

Future<void> updateDeviceStatusSurface(Map<String, Object?> data) =>
    _invoke('updateDeviceStatus', data);

Future<void> updateHealthStatusSurface(Map<String, Object?> data) =>
    _invoke('updateHealthStatus', data);

Future<void> updateQueueActivitySurface(Map<String, Object?> data) =>
    _invoke('updateQueueActivity', data);

Future<void> clearQueueActivitySurface() => _invoke('clearQueueActivity');
