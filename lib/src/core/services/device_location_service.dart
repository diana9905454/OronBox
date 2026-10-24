import 'package:flutter/services.dart' show PlatformException;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:oronbox_location/oronbox_location.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_gnss.pb.dart'
    as pb_gnss;

/// Single-fix GNSS assistance. Sport sessions use PhoneLocationSessions.
class DeviceLocationService {
  DeviceLocationService({
    Logger? log,
    this.isSupportedOverride,
    OronboxLocation? platform,
  }) : _log = log ?? getLogger('DeviceLocationService'),
       _platform = platform ?? OronboxLocation.instance;

  static final _requests = <OronboxLocation, _LocationFixRequest>{};
  final Logger _log;
  final OronboxLocation _platform;
  final bool? isSupportedOverride;
  int _generation = 0;
  Future<pb_gnss.GpsInfo?>? _pending;
  _LocationFixRequest? _active;
  Object? _lease;

  bool get isSupported =>
      isSupportedOverride ??
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    try {
      if (!await _platform.isLocationServiceEnabled()) return false;
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied ||
          (permission == LocationPermission.whileInUse &&
              !await _platform.isPreciseLocationEnabled())) {
        permission = await _platform.requestPermission();
      }
      return _permissionGranted(permission) &&
          await _platform.isPreciseLocationEnabled();
    } catch (error) {
      _log.warning(
        'Location permission preparation failed: ${error.runtimeType}',
      );
      return false;
    }
  }

  Future<pb_gnss.GpsInfo?> getGpsInfo() {
    if (!isSupported) return Future.value(null);
    final pending = _pending;
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<pb_gnss.GpsInfo?> operation;
    operation = _acquire(generation).whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
    return _pending = operation;
  }

  Future<pb_gnss.GpsInfo?> _acquire(int generation) async {
    _LocationFixRequest? request;
    Object? lease;
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        throw PlatformException(code: 'SERVICE_DISABLED');
      }
      if (!_permissionGranted(await _platform.checkPermission())) {
        throw PlatformException(code: 'PERMISSION_DENIED');
      }
      if (!await _platform.isPreciseLocationEnabled()) {
        throw PlatformException(code: 'PRECISE_PERMISSION_REQUIRED');
      }
      if (generation != _generation) return null;
      request = _requests.putIfAbsent(_platform, () {
        late final _LocationFixRequest created;
        created = _LocationFixRequest(_platform, () {
          if (identical(_requests[_platform], created)) {
            _requests.remove(_platform);
          }
        });
        return created;
      });
      lease = Object();
      request.leases.add(lease);
      _active = request;
      _lease = lease;
      final position = await request.result;
      if (generation != _generation || !_valid(position)) return null;
      final info = pb_gnss.GpsInfo(
        timestamp: position.timestamp.millisecondsSinceEpoch ~/ 1000,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (position.hasAltitude && position.altitude.isFinite) {
        info.altitude = position.altitude;
      }
      return info;
    } catch (error) {
      if (generation == _generation) {
        _log.warning(
          'Phone location unavailable: ${error is PlatformException ? error.code : error.runtimeType}',
        );
      }
      return null;
    } finally {
      if (request != null && lease != null) request.leases.remove(lease);
      if (identical(_active, request) && identical(_lease, lease)) {
        _active = null;
        _lease = null;
      }
    }
  }

  /// Release only this device's interest in a shared native request.
  Future<void> cancel() async {
    _generation++;
    _pending = null;
    final request = _active;
    final lease = _lease;
    _active = null;
    _lease = null;
    if (request == null || lease == null) return;
    request.leases.remove(lease);
    if (request.leases.isEmpty && !request.completed) {
      if (identical(_requests[_platform], request)) _requests.remove(_platform);
      await _platform.cancelCurrentPosition();
    }
  }

  static bool _permissionGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  static bool _valid(Position position) {
    final age =
        position.ageMilliseconds ??
        DateTime.now().difference(position.timestamp).inMilliseconds;
    return age >= 0 &&
        age <= 10000 &&
        position.latitude.isFinite &&
        position.latitude.abs() <= 90 &&
        position.longitude.isFinite &&
        position.longitude.abs() <= 180 &&
        position.hasAccuracy &&
        position.accuracy.isFinite &&
        position.accuracy >= 0;
  }
}

class _LocationFixRequest {
  _LocationFixRequest(OronboxLocation platform, void Function() onComplete) {
    result =
        Future.sync(
          () =>
              platform.getCurrentPosition(timeout: const Duration(seconds: 30)),
        ).whenComplete(() {
          completed = true;
          onComplete();
        });
  }

  late final Future<Position> result;
  final leases = <Object>{};
  bool completed = false;
}
