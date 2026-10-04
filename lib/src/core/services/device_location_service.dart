import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_gnss.pb.dart'
    as pb_gnss;

/// Provides the phone's current GPS position as a [pb_gnss.GpsInfo] for
/// injection into [XiaomiGnssSystem].
///
/// GNSS phone-assisted location is designed strictly for mobile devices
/// (Android & iOS) where the phone is physically carried during outdoor workouts
/// (running, walking, cycling) to provide satellite lock assistance or phone
/// GPS piggybacking for bands without built-in GPS.
///
/// On desktop platforms (macOS, Windows, Linux) and Web:
///   - Users do not run with laptops or desktop machines.
///   - Desktop Wi-Fi/IP location is coarse and lacks real-time GPS accuracy.
///   - Requesting location on desktop triggers intrusive system permission
///     prompts or fails due to missing daemons (e.g. Geoclue on Linux).
/// Therefore, this service is automatically a silent no-op on non-mobile platforms.
class DeviceLocationService {
  DeviceLocationService({Logger? log, this.isSupportedOverride})
    : _log = log ?? getLogger('DeviceLocationService');

  final Logger _log;
  final bool? isSupportedOverride;

  /// Whether GNSS assistance is supported on the current platform.
  bool get isSupported =>
      isSupportedOverride ??
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// Acquires the phone's current position and converts it to [pb_gnss.GpsInfo].
  ///
  /// Returns `null` if:
  ///   - Current platform is not mobile (desktop / web).
  ///   - Location services are disabled on the device.
  ///   - The user has denied or permanently denied the location permission.
  ///   - Any exception is raised by the platform during acquisition.
  Future<pb_gnss.GpsInfo?> getGpsInfo() async {
    if (!isSupported) {
      _log.fine(
        'DeviceLocationService: GNSS assistance skipped on non-mobile platform',
      );
      return null;
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _log.info('DeviceLocationService: location services disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _log.info('DeviceLocationService: requesting location permission');
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log.warning(
          'DeviceLocationService: location permission denied ($permission)',
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _log.info(
        'DeviceLocationService: got position '
        'lat=${position.latitude} lon=${position.longitude} '
        'alt=${position.altitude}',
      );

      return pb_gnss.GpsInfo(
        timestamp:
            (position.timestamp.millisecondsSinceEpoch / 1000).round(),
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
      );
    } catch (error, stackTrace) {
      _log.warning(
        'DeviceLocationService: failed to get GPS position',
        error,
        stackTrace,
      );
      return null;
    }
  }
}
