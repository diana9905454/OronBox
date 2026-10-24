import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox_location/oronbox_location.dart';
import 'package:oronbox/src/core/services/device_location_service.dart';

class _LocationPlatform extends OronboxLocation {
  bool enabled = true;
  bool precise = true;
  LocationPermission permission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int fixes = 0;
  int cancellations = 0;
  Completer<Position>? pending;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<bool> isPreciseLocationEnabled() async => precise;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 30),
    Duration maximumAge = Duration.zero,
  }) {
    expect(timeout, const Duration(seconds: 30));
    expect(maximumAge, Duration.zero);
    fixes++;
    return (pending = Completer<Position>()).future;
  }

  @override
  Future<void> cancelCurrentPosition() async {
    cancellations++;
    pending?.completeError(PlatformException(code: 'CANCELLED'));
  }
}

Position _position({int age = 0, bool hasAltitude = false}) => Position(
  latitude: 0,
  longitude: 0,
  timestamp: DateTime.now(),
  accuracy: 8,
  hasAccuracy: true,
  ageMilliseconds: age,
  altitude: 0,
  hasAltitude: hasAltitude,
);

void main() {
  test('desktop does not access location services', () async {
    final platform = _LocationPlatform();
    final service = DeviceLocationService(
      isSupportedOverride: false,
      platform: platform,
    );
    expect(await service.ensurePermission(), isFalse);
    expect(await service.getGpsInfo(), isNull);
    expect(platform.fixes, 0);
  });

  test('approximate permission never starts GNSS acquisition', () async {
    final platform = _LocationPlatform()..precise = false;
    final service = DeviceLocationService(
      isSupportedOverride: true,
      platform: platform,
    );
    expect(await service.ensurePermission(), isFalse);
    expect(await service.getGpsInfo(), isNull);
    expect(platform.fixes, 0);
  });

  test('background acquisition never requests permission', () async {
    final platform = _LocationPlatform()
      ..permission = LocationPermission.denied;
    final service = DeviceLocationService(
      isSupportedOverride: true,
      platform: platform,
    );
    expect(await service.getGpsInfo(), isNull);
    expect(platform.permissionRequests, 0);
  });

  test(
    'zero coordinates are valid and missing altitude stays absent',
    () async {
      final platform = _LocationPlatform();
      final service = DeviceLocationService(
        isSupportedOverride: true,
        platform: platform,
      );
      final result = service.getGpsInfo();
      await pumpEventQueue();
      platform.pending!.complete(_position());
      final info = await result;
      expect(info!.latitude, 0);
      expect(info.longitude, 0);
      expect(info.hasAltitude(), isFalse);
    },
  );

  test('valid zero altitude is retained', () async {
    final platform = _LocationPlatform();
    final service = DeviceLocationService(
      isSupportedOverride: true,
      platform: platform,
    );
    final result = service.getGpsInfo();
    await pumpEventQueue();
    platform.pending!.complete(_position(hasAltitude: true));
    expect((await result)!.hasAltitude(), isTrue);
  });

  test('stale timeout fallback is rejected', () async {
    final platform = _LocationPlatform();
    final service = DeviceLocationService(
      isSupportedOverride: true,
      platform: platform,
    );
    final result = service.getGpsInfo();
    await pumpEventQueue();
    platform.pending!.complete(_position(age: 600000));
    expect(await result, isNull);
  });

  test(
    'devices share a fix and cancellation preserves another consumer',
    () async {
      final platform = _LocationPlatform();
      final first = DeviceLocationService(
        isSupportedOverride: true,
        platform: platform,
      );
      final second = DeviceLocationService(
        isSupportedOverride: true,
        platform: platform,
      );
      final a = first.getGpsInfo();
      final b = second.getGpsInfo();
      await pumpEventQueue();
      expect(platform.fixes, 1);
      await first.cancel();
      expect(platform.cancellations, 0);
      platform.pending!.complete(_position());
      expect(await a, isNull);
      expect(await b, isNotNull);
    },
  );

  test('last consumer cancellation stops the native request', () async {
    final platform = _LocationPlatform();
    final service = DeviceLocationService(
      isSupportedOverride: true,
      platform: platform,
    );
    final result = service.getGpsInfo();
    await pumpEventQueue();
    await service.cancel();
    expect(platform.cancellations, 1);
    expect(await result, isNull);
  });
}
