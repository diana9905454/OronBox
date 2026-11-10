import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';

const _channel = MethodChannel('oronbox/background_tasks');

bool get _isSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.ohos);

/// Keeps the device session active using the platform background service.
Future<void> beginConnectionKeepAlive(String label, {int? battery}) async {
  if (!_isSupported) return;
  await _invoke('beginConnection', {'label': label, 'battery': battery});
}

Future<void> updateConnectionKeepAlive(String label, {int? battery}) async {
  if (!_isSupported) return;
  await _invoke('updateConnection', {'label': label, 'battery': battery});
}

Future<void> endConnectionKeepAlive() async {
  if (!_isSupported) return;
  await _invoke('endConnection');
}

Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
  try {
    await _channel.invokeMethod<void>(method, arguments);
  } catch (error, stackTrace) {
    getLogger('ConnectionKeepAlive').warning(
      'Background connection service failed: $method',
      error,
      stackTrace,
    );
  }
}
