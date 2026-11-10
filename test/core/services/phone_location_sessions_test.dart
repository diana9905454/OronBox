import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox_location/oronbox_location.dart';
import 'package:oronbox/src/core/services/phone_location_sessions.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';

class _Platform extends OronboxLocation {
  final updates = StreamController<Position>.broadcast();
  int starts = 0, stops = 0;
  int cancellations = 0;
  bool reject = false;
  @override
  Stream<Position> get positions => updates.stream;
  @override
  Future<void> startUpdates({
    required String notificationTitle,
    required String notificationText,
    required String channelName,
    String? recoveryTitle,
    String? recoveryText,
  }) async {
    starts++;
    if (reject) throw PlatformException(code: 'BACKGROUND_START_RESTRICTED');
  }

  @override
  Future<void> cancelCurrentPosition() async {
    cancellations++;
  }

  @override
  Future<void> stopUpdates() async {
    stops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      PhoneLocationSessions.enabledKey: true,
    });
    await SharedPrefsService.instance.init();
  });
  test('devices share one session until the last lease is released', () async {
    final platform = _Platform();
    final sessions = PhoneLocationSessions(platform: platform);
    final first = Object(), second = Object();
    await Future.wait([sessions.acquire(first), sessions.acquire(second)]);
    expect(platform.starts, 1);
    await sessions.release(first);
    expect(platform.stops, 0);
    await sessions.release(second);
    expect(platform.stops, 1);
    await platform.updates.close();
  });
  test(
    'a failed background start can be retried without a stranded lease',
    () async {
      final platform = _Platform()..reject = true;
      final sessions = PhoneLocationSessions(platform: platform);
      final device = Object();
      await expectLater(
        sessions.acquire(device),
        throwsA(isA<PlatformException>()),
      );
      platform.reject = false;
      await sessions.acquire(device);
      await sessions.release(device);
      expect(platform.starts, 2);
      expect(platform.stops, 1);
      await platform.updates.close();
    },
  );
  test('disable informs consumers and stops the native subscription', () async {
    final platform = _Platform();
    final sessions = PhoneLocationSessions(platform: platform);
    final errors = <Object>[];
    final subscription = sessions.positions.listen((_) {}, onError: errors.add);
    await sessions.acquire(Object());
    await sessions.disable();
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<PlatformException>());
    expect(platform.cancellations, 1);
    expect(platform.stops, 1);
    await subscription.cancel();
    await platform.updates.close();
  });
}
