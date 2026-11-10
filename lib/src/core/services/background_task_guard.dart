import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('oronbox/background_tasks');

bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.ohos);

class BackgroundTaskHandle {
  const BackgroundTaskHandle(this.id);
  final int? id;

  Future<void> end() async {
    if (id == null || !_isMobile) return;
    await _channel.invokeMethod<void>('end', {'id': id});
  }
}

Future<BackgroundTaskHandle> beginBackgroundTask(String label) async {
  if (!_isMobile) {
    return const BackgroundTaskHandle(null);
  }
  final id = await _channel.invokeMethod<int>('begin', {'label': label});
  return BackgroundTaskHandle(id);
}
