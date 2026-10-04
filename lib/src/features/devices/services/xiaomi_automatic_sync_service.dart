import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/services/status_surface_bridge.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_sync_preferences.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_weather_sync_service.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

/// Runs the complete device synchronization workflow under the manager's
/// single-flight lock.
///
/// The device sync itself records the successful completion timestamp. Health
/// and weather are optional follow-up requests and do not prevent the device
/// cooldown from being refreshed when they fail.
class XiaomiAutomaticSyncService {
  XiaomiAutomaticSyncService(this.manager);

  static final _log = getLogger('XiaomiAutomaticSyncService');

  final DeviceManager manager;

  Future<void> run({required bool automatic}) {
    final mode = automatic ? 'automatic' : 'manual';
    _log.info('Xiaomi $mode synchronization requested');
    return manager.runExclusiveSyncCycle(() async {
      _log.fine('Xiaomi $mode synchronization cycle started');
      try {
        await _run(automatic: automatic);
        _log.info('Xiaomi $mode synchronization cycle completed');
      } catch (error, stackTrace) {
        _log.warning(
          'Xiaomi $mode synchronization cycle failed',
          error,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  /// Runs a health-only manual sync through the same workflow lock used by
  /// automatic and device-page synchronization. A successful manual health
  /// sync also resets the per-device automatic-sync cooldown.
  Future<XiaomiHealthSyncResult> runHealthSync() async {
    _log.info('manual Xiaomi health synchronization requested');
    XiaomiHealthSyncResult? result;
    // If a full sync cycle is already active, wait for it and then acquire the
    // lock again. The active cycle may not have health auto-sync enabled, so a
    // manual health request must not silently turn into a no-op.
    while (result == null) {
      await manager.runExclusiveSyncCycle(() async {
        _log.fine('manual Xiaomi health synchronization lock acquired');
        result = await manager.syncXiaomiHealth();
        await manager.recordSuccessfulDeviceSync();
      });
    }
    _log.info(
      'manual Xiaomi health synchronization completed: '
      'daily=${result!.updatedDaily}, samples=${result!.updatedSamples}, '
      'sleep=${result!.updatedSleep}, workouts=${result!.updatedWorkouts}',
    );
    return result!;
  }

  Future<void> _run({required bool automatic}) async {
    final mode = automatic ? 'automatic' : 'manual';
    Object? deviceSyncError;
    StackTrace? deviceSyncStackTrace;

    // Concurrently pre-fetch weather data over HTTP while device & health
    // synchronize over Bluetooth, completely overlapping the network latency.
    Future<XiaomiWeatherData>? weatherFetchTask;
    final weatherEnabled = XiaomiSyncPreferences.weatherAutoSync;
    final city = XiaomiSyncPreferences.weatherLastCity?.trim();
    if (weatherEnabled && city != null && city.isNotEmpty) {
      final systemInfo = manager.systemInfo;
      _log.fine('starting concurrent weather fetch for city=$city');
      weatherFetchTask = XiaomiWeatherSyncService().fetch(
        city,
        model: systemInfo?.model,
        firmwareVersion: systemInfo?.firmwareVersion,
      );
    }

    try {
      await manager.syncDevice();
      _log.info('Xiaomi $mode device synchronization completed');
    } catch (error, stackTrace) {
      deviceSyncError = error;
      deviceSyncStackTrace = stackTrace;
      _log.warning(
        'Xiaomi $mode device synchronization failed',
        error,
        stackTrace,
      );
    }

    await _syncEnabledXiaomiData(weatherFetchTask: weatherFetchTask);

    if (deviceSyncError != null) {
      Error.throwWithStackTrace(deviceSyncError, deviceSyncStackTrace!);
    }
  }

  Future<void> _syncEnabledXiaomiData({
    Future<XiaomiWeatherData>? weatherFetchTask,
  }) async {
    final healthEnabled = XiaomiSyncPreferences.healthAutoSync;
    final weatherEnabled = XiaomiSyncPreferences.weatherAutoSync;
    _log.fine(
      'automatic Xiaomi data sync settings: '
      'health=$healthEnabled weather=$weatherEnabled',
    );
    if (healthEnabled) {
      _log.info('automatic Xiaomi health synchronization started');
      try {
        final result = await manager.syncXiaomiHealth();
        unawaited(
          updateHealthStatusSurface(healthStatusSurfaceData(result.data)),
        );
        _log.info(
          'automatic Xiaomi health synchronization completed: '
          'daily=${result.updatedDaily}, samples=${result.updatedSamples}, '
          'sleep=${result.updatedSleep}, workouts=${result.updatedWorkouts}',
        );
      } catch (error, stackTrace) {
        _log.warning(
          'automatic Xiaomi health synchronization failed',
          error,
          stackTrace,
        );
      }
    }

    final city = XiaomiSyncPreferences.weatherLastCity?.trim();
    if (!weatherEnabled) {
      _log.fine('automatic Xiaomi weather synchronization disabled');
      return;
    }
    if (city == null || city.isEmpty) {
      _log.fine('automatic Xiaomi weather synchronization skipped: no city');
      return;
    }
    _log.info('automatic Xiaomi weather synchronization started: city=$city');
    try {
      final weather = await (weatherFetchTask ??
          XiaomiWeatherSyncService().fetch(
            city,
            model: manager.systemInfo?.model,
            firmwareVersion: manager.systemInfo?.firmwareVersion,
          ));
      await manager.syncXiaomiWeather(weather);
      await XiaomiSyncPreferences.setWeatherLastCity(weather.cityName);
      await XiaomiSyncPreferences.setCachedWeather(weather, DateTime.now());
      _log.info(
        'automatic Xiaomi weather synchronization completed: '
        'city=${weather.cityName}, source=${weather.source.name}',
      );
    } catch (error, stackTrace) {
      _log.warning(
        'automatic Xiaomi weather synchronization failed',
        error,
        stackTrace,
      );
    }
  }
}

/// Keeps automatic synchronization independent from the devices tab.
///
/// The 15-minute timer is the wake/check cadence. The one-hour cooldown is
/// evaluated against the last successful sync for the currently connected
/// device, matching Mi Fitness' two-stage scheduling behavior.
class XiaomiAutomaticSyncScheduler extends ConsumerStatefulWidget {
  const XiaomiAutomaticSyncScheduler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<XiaomiAutomaticSyncScheduler> createState() =>
      _XiaomiAutomaticSyncSchedulerState();
}

class _XiaomiAutomaticSyncSchedulerState
    extends ConsumerState<XiaomiAutomaticSyncScheduler>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _cycleRunning = false;
  bool _checkQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    XiaomiAutomaticSyncService._log.info(
      'automatic Xiaomi synchronization scheduler started: '
      'interval=${XiaomiSyncPreferences.automaticSyncCheckInterval.inMinutes}m, '
      'cooldown=${XiaomiSyncPreferences.automaticSyncCooldown.inMinutes}m',
    );
    _timer = Timer.periodic(
      XiaomiSyncPreferences.automaticSyncCheckInterval,
      (_) => _queueCheck(),
    );
    scheduleMicrotask(_queueCheck);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    XiaomiAutomaticSyncService._log.info(
      'automatic Xiaomi synchronization scheduler stopped',
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _queueCheck();
  }

  void _queueCheck() {
    if (!mounted || _checkQueued) return;
    _checkQueued = true;
    scheduleMicrotask(() {
      _checkQueued = false;
      if (mounted) unawaited(_checkAndRun());
    });
  }

  Future<void> _checkAndRun() async {
    if (_cycleRunning) {
      XiaomiAutomaticSyncService._log.fine(
        'automatic Xiaomi synchronization check skipped: cycle running',
      );
      return;
    }

    final deviceState = ref.read(deviceManagerProvider);
    final device = deviceState.currentDevice;
    if (deviceState.protocolState != proto.ProtocolState.ready ||
        device == null ||
        device.disconnected) {
      XiaomiAutomaticSyncService._log.fine(
        'automatic Xiaomi synchronization check skipped: device not ready',
      );
      return;
    }

    final queue = ref.read(installQueueProvider);
    if (!queue.loaded || queue.hasActiveTasks) {
      XiaomiAutomaticSyncService._log.fine(
        'automatic Xiaomi synchronization check skipped: '
        'resource queue busy or not loaded',
      );
      return;
    }

    final lastSync = XiaomiSyncPreferences.lastSuccessfulDeviceSyncAt(
      device.addr,
    );
    final elapsed = lastSync == null
        ? XiaomiSyncPreferences.automaticSyncCooldown
        : DateTime.now().difference(lastSync);
    if (elapsed < XiaomiSyncPreferences.automaticSyncCooldown) {
      XiaomiAutomaticSyncService._log.fine(
        'automatic Xiaomi synchronization check skipped: '
        'cooldown remaining=${(XiaomiSyncPreferences.automaticSyncCooldown - elapsed).inMinutes}m',
      );
      return;
    }

    _cycleRunning = true;
    XiaomiAutomaticSyncService._log.info(
      'automatic Xiaomi synchronization cycle starting for ${device.addr}',
    );
    try {
      await XiaomiAutomaticSyncService(ref.read(deviceManagerProvider.notifier))
          .run(automatic: true);
    } catch (error, stackTrace) {
      XiaomiAutomaticSyncService._log.warning(
        'automatic Xiaomi synchronization cycle failed',
        error,
        stackTrace,
      );
    } finally {
      _cycleRunning = false;
      XiaomiAutomaticSyncService._log.fine(
        'automatic Xiaomi synchronization cycle lock released',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DeviceManagerState>(deviceManagerProvider, (previous, next) {
      if (next.protocolState == proto.ProtocolState.ready) _queueCheck();
    });
    ref.listen<InstallQueueState>(installQueueProvider, (previous, next) {
      if (next.loaded && !next.hasActiveTasks) _queueCheck();
    });
    return widget.child;
  }
}
