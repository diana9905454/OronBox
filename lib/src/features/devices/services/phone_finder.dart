import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PhoneFinder {
  const PhoneFinder._();

  static const _channel = MethodChannel('oronbox/find_phone');

  static Future<void> setFinding(bool finding) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>(finding ? 'start' : 'stop');
  }
}
