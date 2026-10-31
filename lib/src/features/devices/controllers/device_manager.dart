import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/core/models/sync_models.dart';
import 'package:oronbox/src/core/providers/bluetooth_platform_provider.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/connection_keep_alive.dart';
import 'package:oronbox/src/core/services/rfcomm_driver.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/services/status_surface_bridge.dart';
import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/ble_transport.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/runtime.dart';
import 'package:oronbox/src/device/core/spp_transport.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/device/xiaomi/systems/auth_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/info_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/install_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/lpa_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/network_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/wifi_config_handler.dart';
import 'package:oronbox/src/device/xiaomi/systems/mass_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/media_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/report_system.dart';
import 'package:oronbox/src/device/xiaomi/protocol/transport/mass_transfer.dart'
    show ReverseMassReceiveResult;
import 'package:oronbox/src/device/xiaomi/systems/resource_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/thirdparty_app_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/sync_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_device_component.dart';
import 'package:oronbox/src/device/xiaomi/xiaomi_device_factory.dart';
import 'package:oronbox/src/device/xiaomi/xiaomi_time.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_auth_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_apps_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_app_install_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_app_side_system.dart';
import 'package:oronbox/src/device/zeppos/install/zeppos_package_parser.dart';
import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_battery_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_device_info_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_find_device_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_map_upload_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_music_upload_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_screenshot_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_time_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_xiao_ai_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_voice_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_watchface_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_voice_memos_system.dart';
import 'package:oronbox/src/device/zeppos/zeppos_btbr_transport.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_catalog.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_factory.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/xiaomi_health_sync_service.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_sync_preferences.dart';
import 'package:oronbox/src/features/devices/domain/device_scan_results.dart';
import 'package:oronbox/src/features/devices/utils/device_address.dart';
import 'package:oronbox/src/device/core/device_state.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_watch_face.pb.dart'
    as pb_watchface;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_media.pb.dart'
    as pb_media;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_media.pbenum.dart'
    as pb_media_enum;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_system.pb.dart'
    as pb_system;
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';

import '../models/device_manager_state.dart';
import '../models/device_transfer_models.dart';

export '../models/device_manager_state.dart';
export '../models/device_transfer_models.dart';

class _DeviceLogTransferTimeout implements Exception {
  const _DeviceLogTransferTimeout({
    required this.idle,
    required this.elapsed,
    required this.progress,
  });

  final Duration idle;
  final Duration elapsed;
  final double progress;

  @override
  String toString() =>
      'Device log transfer stopped after ${idle.inSeconds}s without data '
      '(elapsed=${elapsed.inSeconds}s progress=${(progress * 100).round()}%)';
}

class _DeviceConnectCancelled implements Exception {
  const _DeviceConnectCancelled();
}

abstract class DeviceManager extends Notifier<DeviceManagerState> {
  static const errorBluetoothUnavailable = 'bluetooth_unavailable';
  static final _log = getLogger('DeviceManager');
  final _xiaoAiOpusFrames = StreamController<Uint8List>.broadcast();
  final _interconnectMessages =
      StreamController<InterconnectMessage>.broadcast();
  final _rawProtocolFrames = StreamController<Uint8List>.broadcast();
  final _rawProtocolOutgoingFrames = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get xiaoAiOpusFrames => _xiaoAiOpusFrames.stream;
  Stream<InterconnectMessage> get interconnectMessages =>
      _interconnectMessages.stream;
  Stream<DeviceEvent> get deviceEvents => const Stream.empty();
  Stream<Uint8List> get rawProtocolFrames => _rawProtocolFrames.stream;
  Stream<Uint8List> get rawProtocolOutgoingFrames =>
      _rawProtocolOutgoingFrames.stream;

  DeviceKind? get currentDeviceKind {
    final device = state.currentDevice;
    if (device == null) return null;
    return DeviceRegistry.resolveIdentity(
      name: device.name,
      codename: device.codename,
    ).kind;
  }

  SystemInfo? get systemInfo => state.systemInfo;

  /// The health protocol surface for the currently connected Xiaomi device.
  ///
  /// This is available in the daemon-side manager where the protocol systems
  /// live.  The GUI host consumes the same data through [DeviceManagerState]
  /// and the command bus.
  XiaomiHealthSystem? get xiaomiHealthSystem => null;

  @protected
  void emitXiaoAiOpusFrame(Uint8List frame) {
    _xiaoAiOpusFrames.add(frame);
  }

  @protected
  void emitInterconnectMessage(InterconnectMessage message) {
    _interconnectMessages.add(message);
  }

  Future<void>? _syncDeviceFuture;
  Future<void>? _syncCycleFuture;

  Future<void> runExclusiveDeviceSync(Future<void> Function() action) {
    final activeSync = _syncDeviceFuture;
    if (activeSync != null) return activeSync;

    final sync = action();
    _syncDeviceFuture = sync;
    sync.then<void>(
      (_) {
        if (identical(_syncDeviceFuture, sync)) _syncDeviceFuture = null;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_syncDeviceFuture, sync)) _syncDeviceFuture = null;
      },
    );
    return sync;
  }

  /// Serializes the complete automatic/manual synchronization workflow.
  ///
  /// [syncDevice] already prevents two device-level sync commands from
  /// overlapping.  This second lock also covers the optional Xiaomi health
  /// and weather requests that follow it, so a manual request cannot start a
  /// second workflow while an automatic one is still draining its data.
  Future<void> runExclusiveSyncCycle(Future<void> Function() action) {
    final activeCycle = _syncCycleFuture;
    if (activeCycle != null) {
      _log.fine('joining active device synchronization cycle');
      return activeCycle;
    }

    _log.fine('acquired device synchronization cycle lock');
    final cycle = action();
    _syncCycleFuture = cycle;
    cycle.then<void>(
      (_) {
        _log.fine('released device synchronization cycle lock');
        if (identical(_syncCycleFuture, cycle)) _syncCycleFuture = null;
      },
      onError: (Object error, StackTrace stackTrace) {
        _log.warning(
          'device synchronization cycle ended with an error',
          error,
          stackTrace,
        );
        if (identical(_syncCycleFuture, cycle)) _syncCycleFuture = null;
      },
    );
    return cycle;
  }

  /// Records the completion point used by the one-hour automatic-sync
  /// cooldown.  The timestamp is per device so switching devices does not
  /// suppress the first automatic sync for the newly selected device.
  Future<void> recordSuccessfulDeviceSync([String? deviceId]) async {
    if (!SharedPrefsService.instance.isInitialized) {
      _log.fine('device synchronization timestamp skipped: preferences unset');
      return;
    }
    final resolvedDeviceId = (deviceId ?? state.currentDevice?.addr)?.trim();
    if (resolvedDeviceId == null || resolvedDeviceId.isEmpty) {
      _log.fine('device synchronization timestamp skipped: no device');
      return;
    }
    await XiaomiSyncPreferences.setLastSuccessfulDeviceSyncAt(
      resolvedDeviceId,
      DateTime.now(),
    );
    _log.fine(
      'recorded successful device synchronization for $resolvedDeviceId',
    );
  }

  Future<void> startBluetoothScan({ConnectType connectType = ConnectType.ble});
  Future<void> stopBluetoothScan();
  Future<void> connect(
    String addr,
    String name,
    String authKey, {
    DeviceKind kind = DeviceKind.xiaomi,
    String connectType = 'ble',
  });
  Future<void> disconnect([String? address]);
  Future<void> cancelConnect();
  Future<void> removeDevice(String addr);
  bool get batteryRefreshPaused;
  Future<void> setBatteryRefreshPaused(bool paused);
  Future<void> refreshBattery();
  Future<void> syncTime();
  Future<void> syncDevice();
  Future<void> refreshDeviceData();
  Future<void> setFindingZeppOsDevice(bool finding);
  Future<void> setFindingXiaomiPhone(bool finding);
  Future<void> setFindingXiaomiWearable(bool finding);
  void setVoiceLabEnabled(bool enabled) {}
  Future<void> sendXiaoAiReply(String text, {required String recognizedText});
  Future<void> sendXiaoAiRecognitionPartial(String text);
  Future<void> sendXiaoAiRecognitionResult(
    String text, {
    required bool isFinal,
  });
  Future<void> setXiaoAiContinuousCapture(bool enabled);
  Future<void> setXiaoAiEndpoint(int endpoint);
  Future<Uint8List> requestZeppOsScreenshot();
  Future<List<ZeppOsVoiceMemo>> downloadZeppOsVoiceMemos({
    void Function(int completed, int total)? onProgress,
  });
  Future<void> cancelRecordingSync();
  Future<void> uploadZeppOsMap(
    Uint8List bytes, {
    required String fileName,
    void Function(double progress)? onProgress,
  });
  Future<void> uploadZeppOsMusic(
    Uint8List bytes, {
    required String fileName,
    required String title,
    required String artist,
    void Function(double progress)? onProgress,
  });
  Future<void> uploadXiaomiMusic(
    Uint8List bytes, {
    required String title,
    required String artist,
    String? album,
    int? durationSecs,
    void Function(double progress)? onProgress,
  });
  Future<DeviceMusicLibrary> loadXiaomiMusicLibrary();
  Future<void> createXiaomiMusicPlaylist(String name);
  Future<void> renameXiaomiMusicPlaylist(int id, String name);
  Future<void> removeXiaomiMusicPlaylist(int id);
  Future<void> removeXiaomiMusicSong(List<int> id);
  Future<void> setXiaomiMusicSongInPlaylist({
    required int playlistId,
    required List<int> songId,
    required bool included,
  });
  XiaomiHealthData? get cachedXiaomiHealthData;
  Future<XiaomiHealthData> loadXiaomiHealthData();
  Future<XiaomiHealthSyncResult> syncXiaomiHealth();
  Future<void> waitForHealthSync();
  Future<void> reloadSavedDevices();
  Future<void> sendXiaomiWifiConfig({
    required String deviceId,
    required String ssid,
    required int authMode,
    required int frequency,
    required String password,
    String identity = '',
  });
  Future<XiaomiHealthData> replayXiaomiHealthSnapshot(
    String deviceId,
    List<XiaomiActivityRawFile> files,
  );
  Future<pb_system.AppLayout> loadXiaomiAppLayout();
  Future<void> setXiaomiAppLayout(pb_system.AppLayout_Layout layout);
  Future<List<MediaFileDescriptor>> fetchXiaomiRecordingList();
  Future<List<DeviceRecording>> downloadSelectedXiaomiRecordings({
    required List<MediaFileDescriptor> files,
    void Function(int completed, int total, String fileName)? onProgress,
    void Function(DeviceRecordingPullProgress progress)? onDetailedProgress,
  });
  Future<List<DeviceRecording>> downloadXiaomiRecordings({
    void Function(int completed, int total, String fileName)? onProgress,
    void Function(DeviceRecordingPullProgress progress)? onDetailedProgress,
  });
  Future<DeviceLogPullResult> pullDeviceLogs({
    void Function(double progress, String fileName)? onProgress,
    void Function(DeviceLogPullProgress progress)? onDetailedProgress,
    void Function(String stage)? onStage,
  });
  Future<void> cancelDeviceLogPull();
  Future<List<int>> listZeppOsAppSides();
  Future<List<int>> observedZeppOsAppSideIds();
  Future<List<ZeppOsAppSideSessionInfo>> zeppOsAppSideSessions();
  Future<List<ZeppOsAppSideDebugEvent>> zeppOsAppSideEvents(int appId);
  Future<void> clearZeppOsAppSideEvents(int appId);
  Future<void> startZeppOsAppSide(int appId);
  Future<void> stopZeppOsAppSide(int appId);
  Future<void> injectZeppOsAppSideMessage(int appId, Uint8List payload);
  Future<void> sendZeppOsAppSideMessage(int appId, Uint8List payload);
  Future<void> attachZeppOsZml(int appId, ZeppOsZmlHookHandler hookHandler);
  Future<Object?> invokeZeppOsZml(
    int appId,
    String method,
    List<Object?> arguments,
  );
  Future<void> fetchSystemInfo();
  Future<void> fetchStorageInfo();
  Future<void> fetchApps();
  Future<List<AppInfo>> loadXiaomiAppOrder();
  Future<void> setXiaomiAppOrder(List<AppInfo> apps);
  Future<List<XiaomiAlarm>> loadXiaomiAlarms();
  Future<void> addXiaomiAlarm(XiaomiAlarm alarm);
  Future<void> updateXiaomiAlarm(XiaomiAlarm alarm);
  Future<void> removeXiaomiAlarm(int id);
  Future<void> setXiaomiAlarmEnabled(int id, bool enabled);
  Future<void> syncXiaomiWeather(XiaomiWeatherData weather);
  Future<void> fetchWatchfaces();
  Future<void> openApp(AppInfo app, {String page = ''});
  Future<void> sendRaw(Uint8List payload);
  Future<Uint8List> requestRaw(
    Uint8List payload, {
    Duration timeout = const Duration(seconds: 5),
  });
  Future<void> sendInterconnectMessage(String packageName, Uint8List payload);
  Future<void> uninstallApp(AppInfo app);
  Future<void> uninstallWatchface(WatchfaceInfo watchface);
  Future<void> setWatchface(WatchfaceInfo watchface);
  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
    void Function()? onAppSideMissing,
  });
  Future<void> installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  });
  Future<void> installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  });
  Future<void> importSharedDevice(MiWearState device);
  Future<void> downloadXiaomiEsimProfile(
    String activationCode, {
    String confirmationCode = '',
  });
  Future<int> importMiCloudDevices(List<MiCloudDevice> devices);
  Set<String> get connectedAddresses;
}

class LocalDeviceManager extends DeviceManager {
  static const errorBluetoothUnavailable =
      DeviceManager.errorBluetoothUnavailable;

  @override
  Stream<DeviceEvent> get deviceEvents => _runtime.eventStream;

  @override
  XiaomiHealthSystem? get xiaomiHealthSystem =>
      _currentEntity?.system<XiaomiHealthSystem>();

  @override
  XiaomiHealthData? get cachedXiaomiHealthData {
    final deviceId = _currentEntity?.id ?? state.currentDevice?.addr;
    if (deviceId == null || deviceId.isEmpty) return null;
    return HealthStore.getCached(deviceId);
  }

  @override
  Future<XiaomiHealthData> loadXiaomiHealthData() async {
    final deviceId = _currentEntity?.id ?? state.currentDevice?.addr;
    if (deviceId == null || deviceId.isEmpty) {
      return const XiaomiHealthData();
    }
    return HealthStore().read(deviceId);
  }

  @override
  Future<void> reloadSavedDevices() async {
    await PrivateAppState.instance.reload(key: PrivateAppState.pairedDevices);
    final saved = _loadStateSync().pairedDevices;
    final current = state.currentDevice;
    final restored = current == null
        ? null
        : saved.where((d) => d.addr == current.addr).firstOrNull;
    state = state.copyWith(
      pairedDevices: saved
          .map(
            (d) => d.addr == current?.addr
                ? d.copyWith(disconnected: current!.disconnected)
                : d,
          )
          .toList(),
      currentDevice:
          restored?.copyWith(disconnected: current!.disconnected) ?? current,
    );
  }

  @override
  Future<void> waitForHealthSync() async {
    await _xiaomiHealthSyncFuture?.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
  }

  @override
  Future<XiaomiHealthSyncResult> syncXiaomiHealth() {
    if (HealthStore.maintenanceRequested) {
      return Future.error(StateError('Health data maintenance is active'));
    }
    final active = _xiaomiHealthSyncFuture;
    if (active != null) {
      _log.fine('joining active Xiaomi health synchronization');
      return active;
    }

    final system = _requireXiaomiHealthSystem();
    final deviceId = _currentEntity!.id;
    _log.info('Xiaomi health synchronization requested for $deviceId');
    final sync = XiaomiHealthSyncService(
      system: system,
      deviceId: deviceId,
      deviceCode: state.currentDevice?.codename,
    ).sync();
    _xiaomiHealthSyncFuture = sync;
    sync.then<void>(
      (result) {
        _log.info(
          'Xiaomi health synchronization completed for $deviceId: '
          'daily=${result.updatedDaily}, samples=${result.updatedSamples}, '
          'sleep=${result.updatedSleep}, workouts=${result.updatedWorkouts}',
        );
        if (identical(_xiaomiHealthSyncFuture, sync)) {
          _xiaomiHealthSyncFuture = null;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _log.warning(
          'Xiaomi health synchronization failed for $deviceId',
          error,
          stackTrace,
        );
        if (identical(_xiaomiHealthSyncFuture, sync)) {
          _xiaomiHealthSyncFuture = null;
        }
      },
    );
    return sync;
  }

  @override
  Future<void> sendXiaomiWifiConfig({
    required String deviceId,
    required String ssid,
    required int authMode,
    required int frequency,
    required String password,
    String identity = '',
  }) async {
    final entity = _currentEntity;
    if (entity == null ||
        entity.id != deviceId ||
        state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<XiaomiWifiConfigHandler>();
    if (system == null) {
      throw UnsupportedError('Xiaomi Wi-Fi configuration is unavailable');
    }
    await system.sendWifiConfig(
      ssid: ssid,
      authMode: authMode,
      frequency: frequency,
      password: password,
      identity: identity,
    );
  }

  @override
  Future<XiaomiHealthData> replayXiaomiHealthSnapshot(
    String deviceId,
    List<XiaomiActivityRawFile> files,
  ) async {
    // Replay is a local parser/store operation; it must remain available when
    // the wearable is offline or another device is currently connected. Use
    // the live system when it belongs to this snapshot, otherwise create the
    // stateless parser without touching the transport.
    final liveSystem = _currentEntity?.id == deviceId
        ? _currentEntity?.system<XiaomiHealthSystem>()
        : null;
    final parser = liveSystem ?? XiaomiHealthSystem();
    try {
      return await XiaomiHealthSyncService(
        system: parser,
        deviceId: deviceId,
        deviceCode: _currentEntity?.id == deviceId
            ? state.currentDevice?.codename
            : null,
      ).replayFromRawFiles(files);
    } finally {
      if (liveSystem == null) await parser.dispose();
    }
  }

  @override
  Future<pb_system.AppLayout> loadXiaomiAppLayout() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<XiaomiInfoSystem>();
    if (system == null) {
      throw UnsupportedError('App layout is unavailable');
    }
    return system.fetchAppLayout();
  }

  @override
  Future<void> setXiaomiAppLayout(pb_system.AppLayout_Layout layout) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<XiaomiInfoSystem>();
    if (system == null) {
      throw UnsupportedError('App layout is unavailable');
    }
    await system.setAppLayout(layout);
  }

  XiaomiHealthSystem _requireXiaomiHealthSystem() {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    return entity.system<XiaomiHealthSystem>() ??
        (throw UnsupportedError('Health synchronization is unavailable'));
  }

  @override
  DeviceManagerState build() {
    final bluetooth = ref.read(bluetoothPlatformProvider);

    _bluetooth = bluetooth;
    _runtime = DeviceRuntime();
    _scanSubscription = _bluetooth.scanStream.listen(_onBluetoothEndpoint);
    _eventSubscription = _runtime.eventStream.listen(_onDeviceEvent);

    // Android keep-alive: hold a connectedDevice foreground service while a
    // device link is ready so the process (and BLE connection) survives the
    // app going to background. No-op on other platforms.
    listenSelf((previous, next) {
      final wasReady = previous?.protocolState == ProtocolState.ready;
      final isReady = next.protocolState == ProtocolState.ready;
      if (!isReady) {
        if (wasReady) unawaited(endConnectionKeepAlive());
        return;
      }
      final deviceName = next.currentDevice?.name ?? 'device';
      if (!wasReady) {
        unawaited(
          beginConnectionKeepAlive(deviceName, battery: next.battery?.capacity),
        );
        return;
      }
      final batteryChanged =
          previous?.battery?.capacity != next.battery?.capacity;
      final deviceChanged = previous?.currentDevice?.name != deviceName;
      if (batteryChanged || deviceChanged) {
        unawaited(
          updateConnectionKeepAlive(
            deviceName,
            battery: next.battery?.capacity,
          ),
        );
      }
    });
    listenSelf((previous, next) {
      final previousStorage = previous?.systemInfo?.storageInfo;
      final nextStorage = next.systemInfo?.storageInfo;
      final unchanged =
          previous != null &&
          previous.currentDevice == next.currentDevice &&
          previous.protocolState == next.protocolState &&
          previous.connecting == next.connecting &&
          previous.battery == next.battery &&
          previousStorage == nextStorage &&
          previous.apps.length == next.apps.length &&
          previous.watchfaces.length == next.watchfaces.length;
      if (!unchanged) {
        unawaited(updateDeviceStatusSurface(_deviceStatusSurfaceData(next)));
      }
    });

    ref.onDispose(() {
      _log.info('DeviceManager disposed');
      unawaited(_xiaoAiOpusFrames.close());
      unawaited(_interconnectMessages.close());
      unawaited(_rawProtocolFrames.close());
      unawaited(_rawProtocolOutgoingFrames.close());
      _scanTimer?.cancel();
      _batteryRefreshTimer?.cancel();
      _scanSubscription?.cancel();
      _bluetooth.stopScan();
      _eventSubscription?.cancel();
      _cleanupConnection();
      _runtime.dispose();
    });

    _log.info('DeviceManager created');
    final initialState = _loadStateSync();
    unawaited(
      updateDeviceStatusSurface(_deviceStatusSurfaceData(initialState)),
    );

    if (initialState.pairedDevices.isNotEmpty &&
        _shouldAutoReconnect() &&
        !kIsWeb) {
      final last = initialState.pairedDevices.first;
      final authKey = last.authkey;
      if (authKey != null && authKey.isNotEmpty) {
        _log.info(
          'auto reconnect enabled, attempting reconnect to ${last.addr}',
        );
        Future.microtask(() {
          connect(
            last.addr,
            last.name,
            authKey,
            connectType: last.connectType,
          ).catchError((Object e, StackTrace st) {
            _log.warning('auto reconnect to ${last.addr} failed', e, st);
            return;
          });
        });
      } else {
        _log.warning('auto reconnect skipped: no auth key for ${last.addr}');
      }
    }

    return initialState;
  }

  Map<String, Object?> _deviceStatusSurfaceData(DeviceManagerState value) {
    final device = value.currentDevice;
    final connected =
        value.protocolState == ProtocolState.ready &&
        device != null &&
        !device.disconnected;
    final connecting = value.connecting && device != null;
    final storage = value.systemInfo?.storageInfo;
    final appCount = value.apps
        .where((app) => !app.packageName.startsWith('com.xiaomi.miwear.'))
        .length;
    return {
      'hasDevice': device != null,
      'deviceName': device?.name ?? '',
      'connected': connected,
      'connecting': connecting,
      'battery': value.battery?.capacity ?? -1,
      'charging': value.battery?.chargeStatus == ChargeStatus.charging,
      'storageUsed': storage?.used ?? -1,
      'storageTotal': storage?.total ?? -1,
      'appCount': appCount,
      'watchfaceCount': value.watchfaces.length,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static final _log = getLogger('DeviceManager');
  static const _defaultConnectMaxAttempts = 2;
  static const _passiveReconnectMaxAttempts = 2;
  static const _macOsSppConnectMaxAttempts = 2;
  static const _defaultConnectRetryDelay = Duration(milliseconds: 300);
  static const _macOsSppConnectRetryDelay = Duration(seconds: 4);
  static const _sppFailedConnectSettleDelay = Duration(milliseconds: 500);
  static const _zeppOsBleServiceUuid = '00001530-0000-3512-2118-0009af100700';

  late BluetoothPlatform _bluetooth;
  late DeviceRuntime _runtime;
  StreamSubscription<BluetoothEndpoint>? _scanSubscription;
  StreamSubscription<DeviceEvent>? _eventSubscription;
  StreamSubscription<Uint8List>? _rawProtocolSubscription;
  StreamSubscription<Uint8List>? _rawProtocolOutgoingSubscription;
  Timer? _scanTimer;
  Timer? _batteryRefreshTimer;
  bool _batteryRefreshInProgress = false;
  bool _batteryRefreshPaused = false;
  Future<XiaomiHealthSyncResult>? _xiaomiHealthSyncFuture;
  int _activeTransfers = 0;
  Completer<void>? _recordingSyncCancellation;
  BluetoothConnection? _bluetoothConnection;
  DeviceEntity? _currentEntity;
  final _pooledConnections = <String, BluetoothConnection>{};
  final _pooledEntities = <String, DeviceEntity>{};
  final _scannedProfiles = <String, DeviceProfile>{};
  var _connectGeneration = 0;
  Future<void>? _activeConnectFuture;
  String? _activeConnectAddress;
  String? _activeConnectType;
  ConnectType? _pendingConnectType;
  var _passiveReconnectInProgress = false;

  static const String _keyPairedDevices = PrivateAppState.pairedDevices;
  static const String _keyAutoReconnect = 'auto_reconnect';
  static const String _keyAutoReconnectOnDisconnect =
      'auto_reconnect_on_disconnect';

  DeviceManagerState _loadStateSync() {
    final saved =
        PrivateAppState.instance.readStringList(_keyPairedDevices) ?? [];
    final paired = saved
        .map((e) {
          try {
            return _normalizeDeviceIdentity(
              MiWearState.fromJson(jsonDecode(e) as Map<String, dynamic>),
            ).copyWith(disconnected: true);
          } catch (e, st) {
            _log.warning('Invalid saved device record', null, st);
            return null;
          }
        })
        .whereType<MiWearState>()
        .toList();

    final initialCurrent = paired.isEmpty ? null : paired.first;
    return DeviceManagerState(
      pairedDevices: paired,
      // Keep the most recently used device selected for the device overview,
      // while its process-local connection state starts offline.
      currentDevice: initialCurrent,
      protocolState: ProtocolState.disconnected,
    );
  }

  bool _shouldAutoReconnect() {
    try {
      return SharedPrefsService.instance.getBool(_keyAutoReconnect) ?? false;
    } catch (e) {
      return false;
    }
  }

  bool _shouldAutoReconnectOnDisconnect() {
    try {
      return SharedPrefsService.instance.getBool(
            _keyAutoReconnectOnDisconnect,
          ) ??
          false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _savePairedDevices() async {
    final jsonList = state.pairedDevices
        // Connection state belongs to the current process. Persist paired
        // device identity and credentials, never a stale online marker.
        .map((d) => jsonEncode(d.copyWith(disconnected: true).toJson()))
        .toList();
    await PrivateAppState.instance.update({_keyPairedDevices: jsonList});
    _log.info('Saved ${jsonList.length} paired devices');
  }

  @override
  Future<void> startBluetoothScan({
    ConnectType connectType = ConnectType.ble,
  }) async {
    if (state.scanning) return;
    state = state.copyWith(
      scanning: true,
      scannedDevices: const [],
      clearError: true,
    );
    _scannedProfiles.clear();

    if (!kIsWeb) {
      final available = await _bluetooth.isAvailable();
      if (!available) {
        _log.warning('bluetooth not available');
        state = state.copyWith(
          scanning: false,
          error: errorBluetoothUnavailable,
        );
        return;
      }
    }

    try {
      await _bluetooth.requestPermissions();
      await _bluetooth.startScan(
        BluetoothScanOptions(
          connectTypes: _scanConnectTypes(connectType),
          timeout: const Duration(seconds: 15),
        ),
      );

      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(seconds: 15), () {
        stopBluetoothScan();
      });
    } catch (e, st) {
      _log.severe('start scan failed', e, st);
      state = state.copyWith(scanning: false, error: e.toString());
    }
  }

  Set<ConnectType> _scanConnectTypes(ConnectType connectType) {
    if (kIsWeb) return const {ConnectType.ble};
    if (connectType == ConnectType.ble) {
      return const {ConnectType.ble, ConnectType.spp};
    }
    return {connectType};
  }

  @override
  Future<void> stopBluetoothScan() async {
    _log.info('stopping scan');
    _scanTimer?.cancel();
    await _bluetooth.stopScan();
    state = state.copyWith(scanning: false);
  }

  void _onBluetoothEndpoint(BluetoothEndpoint endpoint) {
    final endpointName = endpoint.name.trim();
    if (endpointName.isEmpty || endpointName == 'Unknown device') return;

    final resolvedProfile = _resolveEndpointProfile(endpoint);
    // macOS CoreBluetooth exposes only a UUID for BLE peripherals. Xiaomi
    // VelaOS devices use the classic SPP transport, so a known Xiaomi BLE
    // result is not a usable connection target on this platform. Wait for
    // the native Classic inquiry to provide its real address instead of
    // presenting a card that can never be opened through SPP.
    if (defaultTargetPlatform == TargetPlatform.macOS &&
        endpoint.connectType == ConnectType.ble &&
        resolvedProfile.kind == DeviceKind.xiaomi &&
        resolvedProfile.preferredConnectType == ConnectType.spp &&
        resolvedProfile.id != DeviceRegistry.unknown.id) {
      _log.fine(
        'scan ignore macOS Xiaomi BLE UUID ${endpoint.address}; '
        'waiting for Classic SPP address',
      );
      return;
    }
    // A discovered endpoint must retain its real transport. Only expose a
    // ZeppOS Classic/RFCOMM endpoint when the device catalog says BTBR is
    // supported; phone-call-only Classic advertisements must not be treated
    // as a ZeppOS data transport.
    final zeppCatalogDevice = zeppOsDeviceForBluetoothName(endpointName);
    if (resolvedProfile.kind == DeviceKind.zepp &&
        endpoint.connectType != ConnectType.ble &&
        (zeppCatalogDevice == null ||
            zeppCatalogDevice.connectionCapability ==
                ZeppOsConnectionCapability.ble)) {
      _log.fine(
        'scan ignore ZeppOS ${endpoint.connectType.name} endpoint '
        '${endpoint.address}; device does not advertise BTBR support',
      );
      return;
    }
    _scannedProfiles[_endpointTransportKey(
          endpoint.address,
          endpoint.connectType,
        )] =
        resolvedProfile;
    final rawDisplayName = xiaomiDisplayNameForIdentity(name: endpointName);
    final displayName = _scanDisplayName(endpoint, rawDisplayName);
    _log.fine(
      'scan merge ${endpoint.address} "$displayName" '
      'via ${endpoint.connectType.name}',
    );
    final merged = mergeScannedDeviceEndpoint(
      state.scannedDevices,
      endpoint,
      displayName: displayName,
      profile: resolvedProfile,
    );
    if (identical(merged, state.scannedDevices)) return;
    state = state.copyWith(scannedDevices: _sortScannedDevices(merged));
  }

  List<BTDeviceInfo> _sortScannedDevices(List<BTDeviceInfo> devices) {
    final sorted = List<BTDeviceInfo>.from(devices);
    sorted.sort((left, right) {
      final leftKnown =
          DeviceRegistry.resolveIdentity(name: left.name).id !=
          DeviceRegistry.unknown.id;
      final rightKnown =
          DeviceRegistry.resolveIdentity(name: right.name).id !=
          DeviceRegistry.unknown.id;
      if (leftKnown != rightKnown) return leftKnown ? -1 : 1;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return sorted;
  }

  String _endpointTransportKey(String address, ConnectType connectType) =>
      '${connectType.name}:${formatDeviceAddress(address).toLowerCase()}';

  DeviceProfile _resolveEndpointProfile(BluetoothEndpoint endpoint) {
    final profile = DeviceRegistry.resolveIdentity(name: endpoint.name);
    if (profile.kind == DeviceKind.zepp) return profile;

    final hasZeppService = endpoint.serviceUuids.any(_isZeppOsServiceUuid);
    if (!hasZeppService) return profile;

    return DeviceRegistry.profiles.firstWhere(
      (candidate) => candidate.id == 'zeppos',
      orElse: () => profile,
    );
  }

  bool _isZeppOsServiceUuid(String uuid) {
    final compact = uuid.toLowerCase().replaceAll('-', '');
    final target = _zeppOsBleServiceUuid.replaceAll('-', '');
    return compact == target || compact == '1530' || compact == '00001530';
  }

  String _scanDisplayName(BluetoothEndpoint endpoint, String rawDisplayName) {
    final profile = _resolveEndpointProfile(endpoint);
    if (profile.kind != DeviceKind.zepp ||
        DeviceRegistry.resolveIdentity(name: endpoint.name).kind ==
            DeviceKind.zepp) {
      return rawDisplayName;
    }
    final name = rawDisplayName.trim().isEmpty ? 'Device' : rawDisplayName;
    return 'ZeppOS $name';
  }

  MiWearState _normalizeDeviceIdentity(MiWearState device) {
    final zeppDevice = zeppOsDeviceForBluetoothName(device.name);
    if (zeppDevice != null) {
      return device.copyWith(codename: 'zepp:${zeppDevice.id}');
    }
    final identity =
        xiaomiWearableIdentityForCodename(device.codename) ??
        normalizeXiaomiWearableIdentity(device.name);
    return device.copyWith(
      name: xiaomiDisplayNameForIdentity(
        name: device.name,
        codename: identity?.codename ?? device.codename,
      ),
      codename: identity?.codename ?? device.codename,
    );
  }

  Future<BluetoothConnection> _connectBluetoothWithRetry(
    String addr,
    String name,
    DeviceProfile profile,
    ConnectType connectType,
    int generation,
  ) async {
    Exception? lastError;
    final isMacOsSpp =
        defaultTargetPlatform == TargetPlatform.macOS &&
        connectType == ConnectType.spp;
    final isZeppOsSpp =
        profile.kind == DeviceKind.zepp && connectType == ConnectType.spp;
    final isLinuxBle =
        defaultTargetPlatform == TargetPlatform.linux &&
        connectType == ConnectType.ble;
    final maxAttempts = isZeppOsSpp
        ? 1
        : isLinuxBle
        ? 1
        : isMacOsSpp
        ? _macOsSppConnectMaxAttempts
        : _defaultConnectMaxAttempts;
    final retryDelay = isMacOsSpp
        ? _macOsSppConnectRetryDelay
        : _defaultConnectRetryDelay;
    SppBondRemovalFailed? bondRemovalError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      _throwIfConnectCancelled(generation);
      _log.info(
        '${connectType.name.toUpperCase()} connect attempt '
        '$attempt/$maxAttempts to $addr',
      );
      try {
        final connectFuture = _bluetooth.connect(
          addr,
          name,
          BluetoothConnectOptions(
            connectType: connectType,
            bleRequiredCharacteristics: profile.bleRequiredCharacteristics,
            bleDesiredMtu: profile.bleDesiredMtu,
            bleAttemptPair: profile.bleAttemptPair,
            sppServiceUuid: profile.classicServiceUuid,
            sppFallbackChannels: profile.classicFallbackChannels,
            sppRemoveBond: _removeBondBeforeSpp(),
          ),
        );
        // The native SPP chain caps every bond/socket stage itself, but a
        // wedged Bluetooth stack can still hold the method call open past
        // every poll deadline. Enforce one transport-wide deadline; the
        // TimeoutException branch below cancels the pending native connect.
        final connection = connectType == ConnectType.spp
            ? await connectFuture.timeout(const Duration(seconds: 90))
            : await connectFuture;
        _log.info(
          '${connectType.name.toUpperCase()} connected on attempt $attempt',
        );
        return connection;
      } on TimeoutException catch (e) {
        lastError = e;
        _log.warning(
          '${connectType.name.toUpperCase()} connect attempt $attempt timed out',
        );
        if (connectType == ConnectType.spp) {
          // Release the native worker: the cancel increments the generation
          // so the superseded attempt exits at its next checkpoint and closes
          // any socket still blocked in BluetoothSocket.connect().
          try {
            await _bluetooth.cancelPendingSppConnection().timeout(
              const Duration(seconds: 2),
            );
          } catch (cancelError, cancelStack) {
            _log.warning(
              'cancelling timed-out SPP connect failed',
              cancelError,
              cancelStack,
            );
          }
        }
        await _resetBluetoothAfterFailedConnect(addr, connectType);
      } catch (e) {
        if (e is SppBondRemovalFailed) bondRemovalError = e;
        lastError = e is Exception ? e : Exception(e.toString());
        _log.warning(
          '${connectType.name.toUpperCase()} connect attempt $attempt failed: $e',
        );
        if (connectType == ConnectType.spp) {
          try {
            await _bluetooth.cancelPendingSppConnection().timeout(
              const Duration(seconds: 2),
            );
          } catch (_) {}
        }
        await _resetBluetoothAfterFailedConnect(addr, connectType);
      }

      if (attempt < maxAttempts) {
        await Future.delayed(retryDelay);
        _throwIfConnectCancelled(generation);
      }
    }

    throw bondRemovalError ??
        lastError ??
        Exception(
          '${connectType.name} connect failed after $maxAttempts attempts',
        );
  }

  bool _removeBondBeforeSpp() {
    if (kIsWeb) return false;
    return SharedPrefsService.instance.getBool(removeBondBeforeSppSettingKey) ??
        true;
  }

  void _throwIfConnectCancelled(int generation) {
    if (generation != _connectGeneration) {
      throw const _DeviceConnectCancelled();
    }
  }

  Future<void> _resetBluetoothAfterFailedConnect(
    String address,
    ConnectType connectType,
  ) async {
    try {
      await _bluetooth.disconnect(address).timeout(const Duration(seconds: 2));
    } catch (e) {
      _log.fine(
        '${connectType.name.toUpperCase()} disconnect after failed connect ignored: $e',
      );
    }

    if (connectType == ConnectType.spp) {
      await Future.delayed(_sppFailedConnectSettleDelay);
    }
  }

  @override
  Future<void> connect(
    String addr,
    String name,
    String authKey, {
    DeviceKind kind = DeviceKind.xiaomi,
    String connectType = 'ble',
  }) {
    final connectionAddress = formatDeviceAddress(addr).toLowerCase();
    final connectionType = connectType.toLowerCase();
    final active = _activeConnectFuture;
    if (active != null &&
        _activeConnectAddress == connectionAddress &&
        _activeConnectType == connectionType) {
      if (state.protocolState == ProtocolState.error) {
        _log.fine(
          'aborting stale $connectionType connection attempt to $connectionAddress',
        );
        _connectGeneration++;
        _clearActiveConnect(active);
        if (connectionType == ConnectType.spp.name) {
          unawaited(_bluetooth.cancelPendingSppConnection());
        }
      } else {
        _log.fine(
          'joining active $connectionType connection to $connectionAddress',
        );
        return active;
      }
    }

    final connection = _connect(
      addr,
      name,
      authKey,
      kind: kind,
      connectType: connectType,
    );
    _activeConnectFuture = connection;
    _activeConnectAddress = connectionAddress;
    _activeConnectType = connectionType;
    connection.then<void>(
      (_) => _clearActiveConnect(connection),
      onError: (Object error, StackTrace stackTrace) {
        _clearActiveConnect(connection);
      },
    );
    return connection;
  }

  void _clearActiveConnect(Future<void> connection) {
    if (!identical(_activeConnectFuture, connection)) return;
    _activeConnectFuture = null;
    _activeConnectAddress = null;
    _activeConnectType = null;
  }

  Future<void> _connect(
    String addr,
    String name,
    String authKey, {
    required DeviceKind kind,
    required String connectType,
  }) async {
    final generation = ++_connectGeneration;
    final existingDevice = state.pairedDevices
        .where((d) => d.addr == addr)
        .firstOrNull;
    final identity =
        xiaomiWearableIdentityForCodename(existingDevice?.codename) ??
        normalizeXiaomiWearableIdentity(name);
    var effectiveCodename = identity?.codename ?? existingDevice?.codename;
    final zeppCatalogDevice = zeppOsDeviceForBluetoothName(name);
    if (zeppCatalogDevice != null) {
      effectiveCodename = 'zepp:${zeppCatalogDevice.id}';
    }
    final displayName = xiaomiDisplayNameForIdentity(
      name: name,
      codename: effectiveCodename,
    );
    final profile =
        _scannedProfiles[_endpointTransportKey(
          addr,
          connectType.toLowerCase() == ConnectType.spp.name
              ? ConnectType.spp
              : ConnectType.ble,
        )] ??
        DeviceRegistry.resolveIdentity(
          name: displayName,
          codename: effectiveCodename,
        );
    final profileSource = identity != null
        ? 'codename:${identity.codename}'
        : 'name';
    var effectiveKind = kind == DeviceKind.xiaomi ? profile.kind : kind;
    final normalizedConnectType = connectType.toLowerCase();
    final effectiveConnectType =
        effectiveKind == DeviceKind.zepp && normalizedConnectType.isNotEmpty
        ? normalizedConnectType
        : normalizedConnectType.isEmpty ||
              (profile.id != DeviceRegistry.unknown.id &&
                  profile.preferredConnectType.name.isNotEmpty &&
                  profile.preferredConnectType.name != normalizedConnectType)
        ? profile.preferredConnectType.name
        : normalizedConnectType;
    _log.info(
      'connect request $addr rawName="$name" displayName="$displayName" '
      'codename="$effectiveCodename" via=$effectiveConnectType '
      'profile=${profile.id} source=$profileSource '
      'authkeyPresent=${authKey.trim().isNotEmpty}',
    );
    _log.info('connecting to $displayName @ $addr via $effectiveConnectType');
    final transportType = effectiveConnectType == ConnectType.spp.name
        ? ConnectType.spp
        : ConnectType.ble;
    _pendingConnectType = transportType;
    state = state.copyWith(
      connecting: true,
      connectionTargetAddr: addr,
      connectionTargetName: displayName,
      connectionPhase: DeviceConnectionPhase.preparing,
      connectStatus: 1,
      protocolState: ProtocolState.connecting,
      clearBattery: true,
      clearHealth: true,
      clearSystemInfo: true,
      apps: const [],
      watchfaces: const [],
      xiaoAiActive: false,
      xiaoAiFrameCount: 0,
      xiaoAiCapabilities: const {},
      clearError: true,
    );
    try {
      await stopBluetoothScan();
      _throwIfConnectCancelled(generation);
      await _cleanupConnection(keepAlive: true, nextConnectType: transportType);
      _throwIfConnectCancelled(generation);
      if (transportType == ConnectType.spp) {
        await _disconnectOtherPooledSpp(addr);
        _throwIfConnectCancelled(generation);
        // When the pairing-reset option is enabled, never restore a pooled
        // classic-Bluetooth session. Close it first so the native transport
        // can remove the old bond and establish a fresh RFCOMM connection.
        if (_removeBondBeforeSpp() &&
            (_pooledConnections.containsKey(addr) ||
                _pooledEntities.containsKey(addr))) {
          await _disconnectPooledDevice(addr);
          _throwIfConnectCancelled(generation);
        }
      }
      state = state.copyWith(
        connectionPhase: DeviceConnectionPhase.connectingTransport,
      );
      var existingConnection = _pooledConnections[addr];
      var existingEntity = _pooledEntities[addr];
      final pooledTransportMatches =
          existingConnection?.connectType == transportType;
      if ((existingConnection != null || existingEntity != null) &&
          !pooledTransportMatches) {
        _log.info(
          'discarding pooled ${existingConnection?.connectType.name ?? "unknown"} '
          'session for $addr before ${transportType.name} connect',
        );
        await _disconnectPooledDevice(addr);
        _throwIfConnectCancelled(generation);
        existingConnection = null;
        existingEntity = null;
      }
      if (existingConnection != null &&
          existingEntity != null &&
          pooledTransportMatches) {
        if (existingEntity.isDisposed) {
          _log.info('discarding disposed pooled session for $addr');
          await _disconnectPooledDevice(addr);
          _throwIfConnectCancelled(generation);
          existingConnection = null;
          existingEntity = null;
        } else {
          _log.info('restoring pooled session for $addr');
          _pooledConnections.remove(addr);
          _pooledEntities.remove(addr);
          _bluetoothConnection = existingConnection;
          _currentEntity = existingEntity;
          await _rawProtocolSubscription?.cancel();
          await _rawProtocolOutgoingSubscription?.cancel();
          _rawProtocolSubscription = existingEntity.rawIncomingData.listen(
            _rawProtocolFrames.add,
          );
          _rawProtocolOutgoingSubscription = existingEntity.rawOutgoingData
              .listen(_rawProtocolOutgoingFrames.add);
          final connected = MiWearState(
            name: displayName,
            addr: addr,
            connectType: effectiveConnectType,
            authkey: authKey,
            codename: effectiveCodename,
            disconnected: false,
          );
          final existingIndex = state.pairedDevices.indexWhere(
            (device) => device.addr == addr,
          );
          final updatedPaired = List<MiWearState>.from(state.pairedDevices);
          if (existingIndex >= 0) updatedPaired.removeAt(existingIndex);
          updatedPaired.insert(0, connected);
          state = state.copyWith(
            currentDevice: connected,
            pairedDevices: updatedPaired,
            protocolState: ProtocolState.ready,
            connecting: false,
            connectStatus: 2,
            clearBattery: true,
            clearHealth: true,
            clearSystemInfo: true,
            apps: const [],
            watchfaces: const [],
            xiaoAiActive: false,
            xiaoAiFrameCount: 0,
            xiaoAiCapabilities: const {},
            clearConnectionPhase: true,
            clearError: true,
          );
          await _savePairedDevices();
          _startBatteryRefreshLoop();
          unawaited(_loadInitialDeviceData(existingEntity));
          _pendingConnectType = null;
          return;
        }
      }
      if (existingConnection != null) {
        _log.info('reusing pooled connection for $addr (no entity)');
        _bluetoothConnection = existingConnection;
        _pooledConnections.remove(addr);
      } else {
        final connection = await _connectBluetoothWithRetry(
          addr,
          displayName,
          profile,
          transportType,
          generation,
        );
        try {
          _throwIfConnectCancelled(generation);
        } on _DeviceConnectCancelled {
          // The native connection may finish after a newer connect request has
          // invalidated this generation. Dispose this local result before it
          // can be lost without ever becoming the active connection.
          await connection.dispose();
          rethrow;
        }
        _bluetoothConnection = connection;
      }
      _throwIfConnectCancelled(generation);
      state = state.copyWith(
        connectionPhase: DeviceConnectionPhase.initializingProtocol,
        protocolState: ProtocolState.connected,
      );

      if (transportType == ConnectType.ble &&
          _supportsZeppOsGatt(_bluetoothConnection!)) {
        effectiveKind = DeviceKind.zepp;
        _log.info(
          'identified $addr as ZeppOS from discovered GATT characteristics',
        );
      }

      final Transport transport;
      if (transportType == ConnectType.spp) {
        if (effectiveKind == DeviceKind.zepp) {
          final btbrTransport = ZeppOsBtbrTransport(_bluetoothConnection!);
          await btbrTransport.start();
          _throwIfConnectCancelled(generation);
          transport = btbrTransport;
        } else {
          final sppTransport = SppTransport.xiaomiBluetooth(
            _bluetoothConnection!,
          );
          await sppTransport.start();
          _throwIfConnectCancelled(generation);
          transport = sppTransport;
        }
      } else {
        final bleTransport = effectiveKind == DeviceKind.zepp
            ? BleTransport.zeppBluetooth(_bluetoothConnection!)
            : BleTransport.xiaomiBluetooth(_bluetoothConnection!);
        await bleTransport.start();
        _throwIfConnectCancelled(generation);
        transport = bleTransport;
      }

      final entity = _runtime.spawnDevice(
        id: addr,
        kind:
            effectiveKind == DeviceKind.xiaomi &&
                transportType == ConnectType.spp &&
                identity?.protocol == XiaomiWearableProtocol.sppV1
            ? 'xiaomi-spp-v1'
            : deviceKindString(effectiveKind),
        transport: transport,
        factory: effectiveKind == DeviceKind.zepp
            ? ZeppOsDeviceFactory()
            : XiaomiDeviceFactory(),
      );
      _currentEntity = entity;
      await _rawProtocolSubscription?.cancel();
      await _rawProtocolOutgoingSubscription?.cancel();
      _rawProtocolSubscription = entity.rawIncomingData.listen(
        _rawProtocolFrames.add,
      );
      _rawProtocolOutgoingSubscription = entity.rawOutgoingData.listen(
        _rawProtocolOutgoingFrames.add,
      );

      if (effectiveKind == DeviceKind.zepp) {
        state = state.copyWith(
          connectionPhase: DeviceConnectionPhase.authenticating,
          protocolState: ProtocolState.authenticating,
        );
        final authSystem = entity.system<ZeppOsAuthSystem>()!;
        _log.info('starting ZeppOS authentication');
        await authSystem.authenticate(authKey);
        _throwIfConnectCancelled(generation);
        _log.info('ZeppOS authentication succeeded');
      } else {
        final component = entity.get<XiaomiDeviceComponent>()!;
        await component
            .startSession(
              spp: effectiveConnectType.toLowerCase() == ConnectType.spp.name,
            )
            .timeout(const Duration(seconds: 10));
        _throwIfConnectCancelled(generation);

        state = state.copyWith(
          connectionPhase: DeviceConnectionPhase.authenticating,
          protocolState: ProtocolState.authenticating,
        );
        final authSystem = entity.system<XiaomiAuthSystem>()!;
        _log.info('starting authentication');
        await authSystem
            .authenticate(authKey)
            .timeout(const Duration(seconds: 10));
        _throwIfConnectCancelled(generation);
        _log.info('authentication succeeded');
        await entity.system<XiaomiNetworkSystem>()!.start();
        _throwIfConnectCancelled(generation);
      }

      final connected = MiWearState(
        name: displayName,
        addr: addr,
        connectType: effectiveConnectType,
        authkey: authKey,
        codename: effectiveCodename,
        disconnected: false,
      );
      final existingIndex = state.pairedDevices.indexWhere(
        (d) => d.addr == addr,
      );
      final updatedPaired = List<MiWearState>.from(state.pairedDevices);
      if (existingIndex >= 0) {
        updatedPaired.removeAt(existingIndex);
      }
      updatedPaired.insert(0, connected);

      state = state.copyWith(
        currentDevice: connected,
        pairedDevices: updatedPaired,
        protocolState: ProtocolState.ready,
        connecting: false,
        connectStatus: 2,
        clearBattery: true,
        clearHealth: true,
        clearSystemInfo: true,
        apps: const [],
        watchfaces: const [],
        xiaoAiActive: false,
        xiaoAiFrameCount: 0,
        xiaoAiCapabilities: const {},
        uploadBytesPerSecond: 0,
        downloadBytesPerSecond: 0,
        clearConnectionPhase: true,
      );
      await _savePairedDevices();
      _startBatteryRefreshLoop();
      unawaited(_loadInitialDeviceData(entity));
      _pendingConnectType = null;
    } on _DeviceConnectCancelled {
      _log.info('connect to $addr cancelled');
      await _finishCancelledConnect(addr, generation);
    } catch (e, st) {
      if (generation != _connectGeneration) {
        _log.info('connect to $addr cancelled after error: $e');
        await _finishCancelledConnect(addr, generation);
        return;
      }
      _log.severe('connect to $addr failed', e, st);
      state = state.copyWith(
        connecting: false,
        connectStatus: 3,
        protocolState: ProtocolState.error,
        error: _passiveReconnectInProgress ? null : e.toString(),
        clearError: _passiveReconnectInProgress,
        clearConnectionPhase: true,
      );
      await _cleanupConnection();
      _pendingConnectType = null;
    }
  }

  bool _supportsZeppOsGatt(BluetoothConnection connection) {
    const service = '00001530-0000-3512-2118-0009af100700';
    return connection.supportsCharacteristic(
          BleRequiredCharacteristic(
            serviceUuid: service,
            characteristicUuid: '00000016-0000-3512-2118-0009af100700',
          ),
        ) &&
        connection.supportsCharacteristic(
          BleRequiredCharacteristic(
            serviceUuid: service,
            characteristicUuid: '00000017-0000-3512-2118-0009af100700',
          ),
        );
  }

  Future<void> _loadInitialDeviceData(DeviceEntity entity) async {
    if (_currentEntity != entity) return;
    try {
      await syncDevice();
    } catch (e, st) {
      _log.warning('initial device synchronization failed', e, st);
    }
  }

  void _startBatteryRefreshLoop() {
    if (_batteryRefreshPaused) return;
    _batteryRefreshTimer?.cancel();
    _batteryRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshBatteryInBackground()),
    );
  }

  @override
  bool get batteryRefreshPaused => _batteryRefreshPaused;

  @override
  Future<void> setBatteryRefreshPaused(bool paused) async {
    _batteryRefreshPaused = paused;
    if (paused) {
      _batteryRefreshTimer?.cancel();
      _batteryRefreshTimer = null;
      return;
    }
    if (_currentEntity != null && state.protocolState == ProtocolState.ready) {
      _startBatteryRefreshLoop();
      await _refreshBatteryInBackground();
    }
  }

  Future<void> _refreshBatteryInBackground() async {
    if (_batteryRefreshPaused ||
        _batteryRefreshInProgress ||
        _activeTransfers > 0 ||
        _currentEntity == null ||
        state.protocolState != ProtocolState.ready) {
      return;
    }
    _batteryRefreshInProgress = true;
    try {
      await refreshBattery();
    } catch (e, st) {
      if (_currentEntity != null &&
          state.protocolState == ProtocolState.ready) {
        _log.warning('periodic battery refresh failed', e, st);
      }
    } finally {
      _batteryRefreshInProgress = false;
    }
  }

  Future<SystemInfo> _fetchDeviceInfoWithEuiccFallback(
    XiaomiInfoSystem infoSystem,
  ) async {
    var info = await infoSystem.fetchDeviceInfo();
    final previousInfo = state.systemInfo;
    final storageInfo = previousInfo?.storageInfo;
    if (info.imei.trim().isEmpty &&
        previousInfo?.imei.trim().isNotEmpty == true) {
      info = info.copyWith(imei: previousInfo!.imei);
    }
    if (storageInfo != null) {
      info = info.copyWith(storageInfo: storageInfo);
    }
    if (!_shouldFetchEuiccImei(state.currentDevice, info)) {
      return info;
    }

    try {
      final imei = await infoSystem.fetchEuiccImei();
      if (imei == null) {
        _log.info(
          'eUICC IMEI unavailable for ${state.currentDevice?.addr ?? info.model}',
        );
        return info;
      }
      final updatedInfo = info.copyWith(
        imei: imei,
        storageInfo: state.systemInfo?.storageInfo ?? info.storageInfo,
      );
      _log.info(
        'device info ${state.currentDevice?.addr ?? info.model}: '
        'eUICC IMEI loaded',
      );
      return updatedInfo;
    } catch (e, st) {
      _log.warning('eUICC info fetch failed', e, st);
      return info;
    }
  }

  bool _shouldFetchEuiccImei(MiWearState? device, SystemInfo info) {
    if (info.imei.trim().isNotEmpty) return false;

    final identity =
        xiaomiWearableIdentityForCodename(device?.codename) ??
        normalizeXiaomiWearableIdentity(info.model) ??
        normalizeXiaomiWearableIdentity(device?.name ?? '');
    final tokens = [
      device?.name,
      device?.codename,
      info.model,
      identity?.codename,
      identity?.displayName,
    ].whereType<String>().map((value) => value.toLowerCase()).join(' ');

    return tokens.contains('esim') ||
        tokens.contains('lte') ||
        tokens.contains('o65m');
  }

  void _onDeviceEvent(DeviceEvent event) {
    if (event.deviceId != state.currentDevice?.addr) {
      if (event is TransportDisconnected &&
          (_pooledConnections.containsKey(event.deviceId) ||
              _pooledEntities.containsKey(event.deviceId))) {
        unawaited(_handlePooledTransportDisconnect(event.deviceId));
      }
      return;
    }

    switch (event) {
      case DeviceAuthenticated _:
        _log.info('event: authenticated');
        state = state.copyWith(protocolState: ProtocolState.ready);
      case AuthFailed(:final error):
        _log.warning('event: auth failed: $error');
        state = state.copyWith(
          protocolState: ProtocolState.error,
          error: error,
        );
      case TransportDisconnected _:
        _log.warning('event: transport disconnected');
        unawaited(_onDisconnected());
      case LinkTrafficUpdated(:final traffic):
        state = state.copyWith(
          uploadBytesPerSecond: traffic.uploadBytesPerSecond,
          downloadBytesPerSecond: traffic.downloadBytesPerSecond,
        );
      case BatteryUpdated(:final battery):
        final previousChargeInfo = state.battery?.chargeInfo;
        final isCharging = switch (battery.chargeStatus) {
          ChargeStatus.charging => true,
          ChargeStatus.notCharging || ChargeStatus.full => false,
          ChargeStatus.unknown => null,
        };
        final chargingStatus = switch (battery.chargeStatus) {
          ChargeStatus.charging => 1,
          ChargeStatus.notCharging => 2,
          ChargeStatus.full => 3,
          ChargeStatus.unknown => null,
        };
        state = state.copyWith(
          battery: battery.chargeInfo == null && previousChargeInfo != null
              ? battery.copyWith(chargeInfo: previousChargeInfo)
              : battery,
          health: isCharging == null
              ? null
              : state.health?.copyWith(
                  isCharging: isCharging,
                  chargingStatus: chargingStatus,
                ),
        );
      case XiaomiHealthStateUpdated(:final health):
        state = state.copyWith(health: health);
      case XiaomiFindPhoneRequested(:final finding):
        _log.info(
          'event: wearable phone finder ${finding ? 'started' : 'stopped'}',
        );
      case XiaomiFindWearableRequested(:final finding):
        _log.info('event: wearable finder ${finding ? 'started' : 'stopped'}');
        state = state.copyWith(findingXiaomiWearable: finding);
      case XiaomiScreenshotReceived(:final bytes):
        _log.info('event: Xiaomi screenshot received (${bytes.length} bytes)');
      case XiaomiAudioRecordReceived(:final id, :final bytes):
        _log.info(
          'event: Xiaomi audio record received ($id, ${bytes.length} bytes)',
        );
      case DeviceInfoUpdated(:final info):
        _log.info(
          'device info ${event.deviceId}: model=${info.model}, '
          'fw=${info.firmwareVersion}',
        );
        final previousInfo = state.systemInfo;
        final mergedInfo =
            info.imei.trim().isEmpty &&
                previousInfo?.imei.trim().isNotEmpty == true
            ? info.copyWith(imei: previousInfo!.imei)
            : info;
        state = state.copyWith(
          systemInfo: mergedInfo.copyWith(
            storageInfo: previousInfo?.storageInfo,
          ),
        );
        final current = state.currentDevice;
        final identity = normalizeXiaomiWearableIdentity(info.model);
        if (current != null && identity != null) {
          final normalized = current.copyWith(
            name: identity.displayName,
            codename: identity.codename,
          );
          final updatedPaired = state.pairedDevices.map((device) {
            return device.addr == current.addr ? normalized : device;
          }).toList();
          state = state.copyWith(
            currentDevice: normalized,
            pairedDevices: updatedPaired,
          );
          _log.info(
            'normalized ${current.addr}: ${info.model} -> '
            '${identity.codename} (${identity.displayName})',
          );
          unawaited(_savePairedDevices());
        }
      case AppListUpdated(:final apps):
        _log.info('event: app list ${apps.length}');
        state = state.copyWith(apps: apps);
      case StorageInfoUpdated(:final info):
        _log.info(
          'storage info ${event.deviceId}: used=${info.used}, total=${info.total}',
        );
        final currentInfo = state.systemInfo;
        state = state.copyWith(
          systemInfo:
              currentInfo?.copyWith(storageInfo: info) ??
              SystemInfo(
                serialNumber: '',
                firmwareVersion: '',
                imei: '',
                model: '',
                storageInfo: info,
              ),
        );
      case WatchfaceListUpdated(:final watchfaces):
        _log.info('event: watchface list ${watchfaces.length}');
        state = state.copyWith(watchfaces: watchfaces);
      case XiaoAiSessionStarted(:final capabilities):
        state = state.copyWith(
          xiaoAiActive: true,
          xiaoAiFrameCount: 0,
          xiaoAiCapabilities: Map<String, Object?>.unmodifiable(capabilities),
        );
      case XiaoAiSessionEnded _:
        state = state.copyWith(xiaoAiActive: false);
      case XiaoAiOpusFrameReceived(:final frame):
        state = state.copyWith(xiaoAiFrameCount: state.xiaoAiFrameCount + 1);
        emitXiaoAiOpusFrame(Uint8List.fromList(frame));
      case InterconnectMessage _:
        emitInterconnectMessage(event);
      case InstallProgress _:
        // Progress is consumed via callback in install UI.
        break;
      case InstallCompleted _:
        _log.info('event: install completed');
      case InstallFailed(:final error):
        _log.warning('event: install failed: $error');
        state = state.copyWith(error: error);
      case DeviceError(:final error):
        _log.warning('event: device error: $error');
        state = state.copyWith(error: error);
      default:
        break;
    }
  }

  Future<void> _onDisconnected() async {
    if (state.connecting) {
      _log.fine('ignoring disconnect state transition during connect attempt');
      return;
    }
    final current = state.currentDevice;
    if (current == null) {
      state = state.copyWith(
        connecting: false,
        connectStatus: 0,
        protocolState: ProtocolState.disconnected,
        clearBattery: true,
        clearHealth: true,
        clearSystemInfo: true,
        findingXiaomiWearable: false,
        clearError: true,
      );
      await _cleanupConnection();
      return;
    }
    final shouldReconnect =
        state.protocolState == ProtocolState.ready &&
        !current.disconnected &&
        !_passiveReconnectInProgress &&
        _shouldAutoReconnectOnDisconnect() &&
        current.authkey?.isNotEmpty == true;
    final disconnected = current.copyWith(disconnected: true);
    final alreadyPersistedOffline =
        current.disconnected &&
        state.pairedDevices
            .where((device) => device.addr == current.addr)
            .every((device) => device.disconnected);
    final updatedPaired = state.pairedDevices.map((d) {
      return d.addr == current.addr ? disconnected : d;
    }).toList();
    state = state.copyWith(
      currentDevice: disconnected,
      pairedDevices: updatedPaired,
      connecting: false,
      connectStatus: 0,
      protocolState: ProtocolState.disconnected,
      clearBattery: true,
      clearHealth: true,
      clearSystemInfo: true,
      findingXiaomiWearable: false,
      clearError: true,
    );
    if (!alreadyPersistedOffline) _savePairedDevices();
    await _cleanupConnection();
    if (shouldReconnect) {
      unawaited(_attemptPassiveReconnect(disconnected));
    }
  }

  Future<void> _attemptPassiveReconnect(MiWearState device) async {
    if (_passiveReconnectInProgress) return;
    final authKey = device.authkey;
    if (authKey == null || authKey.isEmpty) return;

    _passiveReconnectInProgress = true;
    try {
      for (
        var attempt = 1;
        attempt <= _passiveReconnectMaxAttempts;
        attempt++
      ) {
        if (state.protocolState == ProtocolState.ready &&
            state.currentDevice?.addr == device.addr &&
            state.currentDevice?.disconnected == false) {
          return;
        }
        _log.warning(
          'passive reconnect attempt $attempt/$_passiveReconnectMaxAttempts '
          'to ${device.addr}',
        );
        _runtime.emit(
          PassiveReconnectStatus(
            deviceId: device.addr,
            phase: PassiveReconnectPhase.attempt,
            attempt: attempt,
          ),
        );
        try {
          await connect(
            device.addr,
            device.name,
            authKey,
            connectType: device.connectType,
          );
        } catch (error, stackTrace) {
          _log.warning(
            'passive reconnect attempt $attempt failed for ${device.addr}',
            error,
            stackTrace,
          );
        }
        if (state.protocolState == ProtocolState.ready &&
            state.currentDevice?.addr == device.addr &&
            state.currentDevice?.disconnected == false) {
          _log.info('passive reconnect succeeded for ${device.addr}');
          _runtime.emit(
            PassiveReconnectStatus(
              deviceId: device.addr,
              phase: PassiveReconnectPhase.success,
              attempt: attempt,
            ),
          );
          return;
        }
      }
      _log.warning(
        'passive reconnect failed after $_passiveReconnectMaxAttempts attempts '
        'for ${device.addr}',
      );
      _runtime.emit(
        PassiveReconnectStatus(
          deviceId: device.addr,
          phase: PassiveReconnectPhase.failed,
          attempt: _passiveReconnectMaxAttempts,
        ),
      );
    } finally {
      _passiveReconnectInProgress = false;
    }
  }

  @override
  Set<String> get connectedAddresses {
    final addresses = <String>{};
    final current = state.currentDevice;
    if (current != null &&
        !current.disconnected &&
        state.protocolState == ProtocolState.ready) {
      addresses.add(current.addr);
    }
    addresses.addAll(_pooledConnections.keys);
    addresses.addAll(_pooledEntities.keys);
    return addresses;
  }

  @override
  Future<void> disconnect([String? address]) async {
    _activeConnectFuture = null;
    _activeConnectAddress = null;
    _activeConnectType = null;
    _connectGeneration += 1;
    _pendingConnectType = null;
    final current = state.currentDevice;
    final targetAddress = address ?? current?.addr;
    final targetIsPooled =
        targetAddress != null &&
        (_pooledConnections.containsKey(targetAddress) ||
            _pooledEntities.containsKey(targetAddress));
    if (targetAddress != null &&
        (current?.addr != targetAddress ||
            (targetIsPooled && _currentEntity?.id != targetAddress))) {
      await _disconnectPooledDevice(targetAddress);
      final updatedPaired = state.pairedDevices.map((device) {
        return device.addr == targetAddress
            ? device.copyWith(disconnected: true)
            : device;
      }).toList();
      state = state.copyWith(pairedDevices: updatedPaired);
      await _savePairedDevices();
      return;
    }
    if (current == null) {
      await _cleanupConnection();
      state = state.copyWith(
        connecting: false,
        connectStatus: 0,
        protocolState: ProtocolState.disconnected,
        clearBattery: true,
        clearHealth: true,
        clearSystemInfo: true,
        clearError: true,
        clearConnectionTarget: true,
        clearConnectionPhase: true,
      );
      return;
    }
    final disconnected = current.copyWith(disconnected: true);
    final updatedPaired = state.pairedDevices.map((d) {
      return d.addr == current.addr ? disconnected : d;
    }).toList();
    state = state.copyWith(
      currentDevice: disconnected,
      pairedDevices: updatedPaired,
      connecting: false,
      connectStatus: 0,
      protocolState: ProtocolState.disconnected,
      clearBattery: true,
      clearHealth: true,
      clearSystemInfo: true,
      findingXiaomiWearable: false,
      clearError: true,
      clearConnectionTarget: true,
      clearConnectionPhase: true,
    );
    await _cleanupConnection();
    await _savePairedDevices();
  }

  @override
  Future<void> cancelConnect() async {
    if (!state.connecting) return;
    _activeConnectFuture = null;
    _activeConnectAddress = null;
    _activeConnectType = null;
    _connectGeneration += 1;
    final pendingConnectType = _pendingConnectType;
    _pendingConnectType = null;
    if (pendingConnectType == ConnectType.spp) {
      try {
        await _bluetooth.cancelPendingSppConnection().timeout(
          const Duration(seconds: 1),
        );
      } catch (e, st) {
        _log.warning('cancelling pending SPP connection failed', e, st);
      }
    }
    state = state.copyWith(
      connecting: false,
      connectStatus: 0,
      clearConnectionTarget: true,
      clearConnectionPhase: true,
      clearError: true,
    );
  }

  Future<void> _finishCancelledConnect(
    String targetAddress,
    int generation,
  ) async {
    if (generation != _connectGeneration) {
      _log.fine(
        'ignoring cancelled connect state reset for $targetAddress: '
        'generation $generation superseded by $_connectGeneration',
      );
      return;
    }
    _pendingConnectType = null;
    await _cleanupConnection();
    final entity = _currentEntity;
    if (entity != null && entity.id != targetAddress) {
      state = state.copyWith(
        connecting: false,
        connectStatus: 2,
        protocolState: ProtocolState.ready,
        clearConnectionTarget: true,
        clearConnectionPhase: true,
        clearError: true,
      );
      return;
    }
    final current = state.currentDevice;
    final currentIsPooled =
        current != null &&
        (_pooledConnections.containsKey(current.addr) ||
            _pooledEntities.containsKey(current.addr));
    state = state.copyWith(
      clearCurrentDevice: currentIsPooled,
      connecting: false,
      connectStatus: 0,
      protocolState: ProtocolState.disconnected,
      clearBattery: true,
      clearHealth: true,
      clearSystemInfo: true,
      findingXiaomiWearable: false,
      clearConnectionTarget: true,
      clearConnectionPhase: true,
      clearError: true,
    );
  }

  Future<void> _cleanupConnection({
    bool keepAlive = false,
    ConnectType? nextConnectType,
  }) async {
    _batteryRefreshTimer?.cancel();
    _batteryRefreshTimer = null;
    final connection = _bluetoothConnection;
    final entity = _currentEntity;
    _bluetoothConnection = null;
    _currentEntity = null;
    await _rawProtocolSubscription?.cancel();
    _rawProtocolSubscription = null;
    await _rawProtocolOutgoingSubscription?.cancel();
    _rawProtocolOutgoingSubscription = null;
    String? disconnectedAddress;

    if (entity != null) {
      final replacingSppWithSpp =
          connection?.connectType == ConnectType.spp &&
          nextConnectType == ConnectType.spp;
      final canPool =
          keepAlive &&
          connection != null &&
          !replacingSppWithSpp &&
          (state.protocolState == ProtocolState.ready ||
              (state.connecting && state.currentDevice?.addr == entity.id)) &&
          !entity.isDisposed;
      if (canPool) {
        _pooledConnections[entity.id] = connection;
        _pooledEntities[entity.id] = entity;
        _log.info(
          'saved ${connection.connectType.name.toUpperCase()} session '
          'for ${entity.id} to pool',
        );
      } else {
        _pooledConnections.remove(entity.id);
        _pooledEntities.remove(entity.id);
        disconnectedAddress = entity.id;
        _log.info('cleaning up connection to ${entity.id}');
        await _runtime.removeDevice(entity.id);
        await _bluetooth.disconnect(entity.id).catchError((
          Object e,
          StackTrace st,
        ) {
          _log.warning('Bluetooth connection dispose failed', e, st);
        });
      }
    }
    if (connection != null && entity == null) {
      final address = state.connectionTargetAddr;
      if (address != null && address.isNotEmpty) {
        disconnectedAddress = address;
        await _bluetooth.disconnect(address).catchError((
          Object e,
          StackTrace st,
        ) {
          _log.warning('Bluetooth connection dispose failed', e, st);
        });
      } else {
        await connection.dispose().catchError((Object e, StackTrace st) {
          _log.warning('Bluetooth connection dispose failed', e, st);
        });
      }
    }
    if (disconnectedAddress != null) {
      await _markDeviceDisconnected(disconnectedAddress);
    }
  }

  Future<void> _markDeviceDisconnected(String address) async {
    var changed = false;
    final paired = state.pairedDevices.map((device) {
      if (device.addr != address || device.disconnected) return device;
      changed = true;
      return device.copyWith(disconnected: true);
    }).toList();
    final current = state.currentDevice;
    final disconnectedCurrent = current?.addr == address
        ? current!.copyWith(disconnected: true)
        : current;
    if (disconnectedCurrent != current) changed = true;
    if (!changed) return;
    state = state.copyWith(
      pairedDevices: paired,
      currentDevice: disconnectedCurrent,
    );
    await _savePairedDevices();
  }

  Future<void> _disconnectOtherPooledSpp(String keepAddress) async {
    final addresses = _pooledConnections.entries
        .where(
          (entry) =>
              entry.key != keepAddress &&
              entry.value.connectType == ConnectType.spp,
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final address in addresses) {
      await _disconnectPooledDevice(address);
      await _markDeviceDisconnected(address);
    }
  }

  Future<void> _disconnectPooledDevice(String address) async {
    final connection = _pooledConnections.remove(address);
    final entity = _pooledEntities.remove(address);
    if (entity != null) {
      _log.info('cleaning up pooled connection to $address');
      await _runtime.removeDevice(entity.id);
    }
    if (connection != null) {
      await _bluetooth.disconnect(address).catchError((
        Object e,
        StackTrace st,
      ) {
        _log.warning('Pooled Bluetooth connection dispose failed', e, st);
      });
    }
  }

  Future<void> _handlePooledTransportDisconnect(String address) async {
    _log.warning('pooled transport disconnected: $address');
    await _disconnectPooledDevice(address);
    final updatedPaired = state.pairedDevices.map((device) {
      return device.addr == address
          ? device.copyWith(disconnected: true)
          : device;
    }).toList();
    state = state.copyWith(pairedDevices: updatedPaired);
    await _savePairedDevices();
  }

  @override
  Future<void> removeDevice(String addr) async {
    final updatedPaired = state.pairedDevices
        .where((d) => d.addr != addr)
        .toList();
    final removedCurrent = state.currentDevice?.addr == addr;
    if (removedCurrent) {
      await _cleanupConnection();
    } else {
      await _disconnectPooledDevice(addr);
    }
    state = state.copyWith(
      pairedDevices: updatedPaired,
      currentDevice: removedCurrent ? null : state.currentDevice,
      connecting: removedCurrent ? false : state.connecting,
      connectStatus: removedCurrent ? 0 : state.connectStatus,
      protocolState: removedCurrent
          ? ProtocolState.disconnected
          : state.protocolState,
      clearBattery: removedCurrent,
      clearHealth: removedCurrent,
      clearSystemInfo: removedCurrent,
      clearError: true,
    );
    await _savePairedDevices();
  }

  @override
  Future<void> refreshBattery() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppBatterySystem = entity.system<ZeppOsBatterySystem>();
    if (zeppBatterySystem != null) {
      final servicesSystem = entity.system<ZeppOsServicesSystem>();
      if (servicesSystem == null) return;
      final services = await servicesSystem.fetchSupportedServices();
      if (!services.containsKey(ZeppOsBatterySystem.endpoint)) {
        _log.info('ZeppOS device does not advertise battery endpoint 0x0029');
        return;
      }
      zeppBatterySystem.encrypted =
          services[ZeppOsBatterySystem.endpoint] ?? true;
      final battery = await zeppBatterySystem.fetchBatteryInfo();
      if (_currentEntity != entity) return;
      state = state.copyWith(battery: battery);
      return;
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    final battery = await infoSystem.fetchBatteryInfo();
    if (_currentEntity != entity) return;
    state = state.copyWith(battery: battery);
  }

  @override
  Future<void> syncTime() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppOsSystem = entity.system<ZeppOsTimeSystem>();
    if (zeppOsSystem != null) {
      await zeppOsSystem.syncTime();
      return;
    }
    final system = entity.system<XiaomiSyncSystem>();
    if (system == null) {
      throw UnsupportedError('Time synchronization is not available');
    }
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    // Xiaomi's own TimeSyncer sends `TimeZone.getDefault().getID()`, an IANA
    // identifier. Firmwares that cannot resolve the identifier (for example
    // when only an ambiguous abbreviation such as "CST" is sent) fall back to
    // UTC, which is why the wearable displayed UTC. Dart only exposes the
    // abbreviation, so resolve the IANA identifier through the platform.
    final timeZoneId = await _xiaomiTimeZoneId(now, offset);
    await system.syncTime(
      TimeSyncProps(
        date: SyncDate(year: now.year, month: now.month, day: now.day),
        time: SyncTime(
          hour: now.hour,
          minute: now.minute,
          second: now.second,
          millisecond: now.millisecond,
        ),
        timezone: SyncTimeZone(
          // DateTime's offset already includes any active daylight saving.
          offset: offset.inMinutes ~/ 15,
          dstOffset: 0,
          id: timeZoneId,
        ),
        is12HourFormat: !PlatformDispatcher.instance.alwaysUse24HourFormat,
      ),
    );
  }

  Future<String> _xiaomiTimeZoneId(DateTime now, Duration offset) async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final id = info.identifier.trim();
      if (id.isNotEmpty) return id;
    } catch (error, stackTrace) {
      _log.fine(
        'platform timezone identifier unavailable; using offset fallback',
        error,
        stackTrace,
      );
    }
    return xiaomiTimeZoneId(now.timeZoneName, offset);
  }

  @override
  Future<void> syncDevice() {
    final deviceId = _currentEntity?.id ?? state.currentDevice?.addr;
    return runExclusiveDeviceSync(() async {
      _log.info('device synchronization started for ${deviceId ?? '-'}');
      try {
        await _syncDeviceInternal();
        await recordSuccessfulDeviceSync(deviceId);
        _log.info('device synchronization completed for ${deviceId ?? '-'}');
      } catch (error, stackTrace) {
        _log.warning(
          'device synchronization failed for ${deviceId ?? '-'}',
          error,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  Future<void> _syncDeviceInternal() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }

    Object? firstError;
    StackTrace? firstStackTrace;
    final operations = <(String, Future<void> Function())>[
      if (entity.system<XiaomiSyncSystem>() != null ||
          entity.system<ZeppOsTimeSystem>() != null)
        ('time', syncTime),
      ('device data', refreshDeviceData),
      ('watchfaces', fetchWatchfaces),
      ('apps', fetchApps),
    ];
    for (final operation in operations) {
      if (_currentEntity != entity) return;
      try {
        _log.fine('device synchronization operation started: ${operation.$1}');
        await operation.$2();
        _log.fine(
          'device synchronization operation completed: ${operation.$1}',
        );
      } on UnsupportedError catch (error) {
        _log.fine('device synchronization ${operation.$1} unavailable: $error');
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
        _log.warning(
          'device synchronization ${operation.$1} failed',
          error,
          stackTrace,
        );
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  @override
  Future<void> refreshDeviceData() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    await refreshBattery();
    await fetchSystemInfo();
    if (entity.system<ZeppOsBatterySystem>() != null) return;
    await fetchStorageInfo();
  }

  @override
  Future<void> setFindingZeppOsDevice(bool finding) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsFindDeviceSystem>();
    if (system == null) {
      throw UnsupportedError('Find device is only available for ZeppOS');
    }
    await system.setFinding(finding);
  }

  @override
  Future<void> setFindingXiaomiPhone(bool finding) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<XiaomiSyncSystem>();
    if (system == null) {
      throw UnsupportedError(
        'Phone finder is only available for Xiaomi VelaOS',
      );
    }
    await system.setFindingPhone(finding);
  }

  @override
  Future<void> setFindingXiaomiWearable(bool finding) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<XiaomiSyncSystem>();
    if (system == null) {
      throw UnsupportedError(
        'Wearable finder is only available for Xiaomi VelaOS',
      );
    }
    await system.setFindingWearable(finding);
    state = state.copyWith(findingXiaomiWearable: finding);
  }

  @override
  void setVoiceLabEnabled(bool enabled) {
    _currentEntity?.system<XiaomiVoiceSystem>()?.setEnabled(enabled);
  }

  @override
  Future<void> sendXiaoAiRecognitionPartial(String text) async {
    await sendXiaoAiRecognitionResult(text, isFinal: false);
  }

  @override
  Future<void> sendXiaoAiRecognitionResult(
    String text, {
    required bool isFinal,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) return;
    final xiaomi = entity.system<XiaomiVoiceSystem>();
    if (xiaomi != null) {
      await xiaomi.sendRecognitionResult(text, isFinal: isFinal);
    } else {
      await entity.system<ZeppOsXiaoAiSystem>()?.sendRecognitionResult(
        text,
        isFinal: isFinal,
      );
    }
  }

  @override
  Future<void> sendXiaoAiReply(
    String text, {
    required String recognizedText,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final xiaomi = entity.system<XiaomiVoiceSystem>();
    if (xiaomi != null) {
      await xiaomi.sendTextReply(text, recognizedText: recognizedText);
      return;
    }
    final system = entity.system<ZeppOsXiaoAiSystem>();
    if (system == null) throw UnsupportedError('Voice assistant unavailable');
    await system.sendTextReply(text, recognizedText: recognizedText);
  }

  @override
  Future<void> setXiaoAiContinuousCapture(bool enabled) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsXiaoAiSystem>();
    if (system == null) {
      throw UnsupportedError('XiaoAI is only available for ZeppOS');
    }
    system.setContinuousCapture(enabled);
  }

  @override
  Future<void> setXiaoAiEndpoint(int endpoint) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    if (entity.system<XiaomiVoiceSystem>() != null && endpoint == 0x0010) {
      return;
    }
    final system = entity.system<ZeppOsXiaoAiSystem>();
    if (system == null) {
      throw UnsupportedError('Assistant unavailable');
    }
    system.selectEndpoint(endpoint);
  }

  ZeppOsAppSideSystem _appSideSystem() {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsAppSideSystem>();
    if (system == null) {
      throw UnsupportedError('Zepp OS app-side is unavailable');
    }
    return system;
  }

  @override
  Future<List<int>> listZeppOsAppSides() => _appSideSystem().cachedAppIds();

  @override
  Future<List<int>> observedZeppOsAppSideIds() =>
      _appSideSystem().observedAppIds();

  @override
  Future<List<ZeppOsAppSideSessionInfo>> zeppOsAppSideSessions() async =>
      _appSideSystem().sessions;

  @override
  Future<List<ZeppOsAppSideDebugEvent>> zeppOsAppSideEvents(int appId) async =>
      _appSideSystem().eventsFor(appId);

  @override
  Future<void> clearZeppOsAppSideEvents(int appId) async =>
      _appSideSystem().clearEvents(appId);

  @override
  Future<void> startZeppOsAppSide(int appId) => _appSideSystem().start(appId);

  @override
  Future<void> stopZeppOsAppSide(int appId) => _appSideSystem().stop(appId);

  @override
  Future<void> injectZeppOsAppSideMessage(int appId, Uint8List payload) =>
      _appSideSystem().injectMessage(appId, payload);

  @override
  Future<void> sendZeppOsAppSideMessage(int appId, Uint8List payload) =>
      _appSideSystem().sendMessageToWatch(appId, payload);

  @override
  Future<void> attachZeppOsZml(int appId, ZeppOsZmlHookHandler hookHandler) =>
      _appSideSystem().attachZml(appId, hookHandler);

  @override
  Future<Object?> invokeZeppOsZml(
    int appId,
    String method,
    List<Object?> arguments,
  ) => _appSideSystem().invokeZml(appId, method, arguments);

  @override
  Future<Uint8List> requestZeppOsScreenshot() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _activeTransfers += 1;
    try {
      final system = entity.system<ZeppOsScreenshotSystem>();
      if (system == null) {
        throw UnsupportedError('Screenshot service unavailable');
      }
      return await system.requestScreenshot();
    } finally {
      _activeTransfers -= 1;
    }
  }

  @override
  Future<List<ZeppOsVoiceMemo>> downloadZeppOsVoiceMemos({
    void Function(int completed, int total)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsVoiceMemosSystem>();
    if (system == null) {
      throw UnsupportedError('Voice memo service unavailable');
    }
    _activeTransfers += 1;
    try {
      return await system.downloadAll(onProgress: onProgress);
    } finally {
      _activeTransfers -= 1;
    }
  }

  @override
  Future<void> cancelRecordingSync() async {
    final cancellation = _recordingSyncCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    final entity = _currentEntity;
    entity?.system<ZeppOsVoiceMemosSystem>()?.cancelDownload();
    final mass = entity?.system<XiaomiMassSystem>();
    for (final channel in const [
      L2Channel.massVoice,
      L2Channel.mass,
      L2Channel.fileSensor,
      L2Channel.fileFitness,
    ]) {
      mass?.cancelReverseMassReceive(channel);
    }
  }

  @override
  Future<void> uploadZeppOsMap(
    Uint8List bytes, {
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final connectType = _bluetoothConnection?.connectType;
    if (connectType != ConnectType.ble && connectType != ConnectType.spp) {
      throw UnsupportedError(
        'Offline maps require a BLE or BT Classic connection',
      );
    }
    if (connectType == ConnectType.ble && bytes.length > 2 * 1024 * 1024) {
      throw UnsupportedError(
        'BLE LE map transfers currently only support archives up to 2 MB; '
        'switch to BT Classic before transferring',
      );
    }
    final system = entity.system<ZeppOsMapUploadSystem>();
    if (system == null) {
      throw UnsupportedError('Map transfer service is unavailable');
    }
    _activeTransfers += 1;
    try {
      await system.upload(bytes, fileName: fileName, onProgress: onProgress);
    } finally {
      _activeTransfers -= 1;
    }
  }

  @override
  Future<void> uploadZeppOsMusic(
    Uint8List bytes, {
    required String fileName,
    required String title,
    required String artist,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final connectType = _bluetoothConnection?.connectType;
    if (connectType != ConnectType.ble && connectType != ConnectType.spp) {
      throw UnsupportedError(
        'Music upload requires a BLE or BT Classic connection',
      );
    }
    final system = entity.system<ZeppOsMusicUploadSystem>();
    if (system == null) {
      throw UnsupportedError('Music transfer service is unavailable');
    }
    _activeTransfers++;
    try {
      await system.upload(
        bytes: bytes,
        filename: fileName,
        title: title,
        artist: artist,
        onProgress: onProgress,
      );
    } finally {
      _activeTransfers--;
    }
  }

  @override
  Future<void> uploadXiaomiMusic(
    Uint8List bytes, {
    required String title,
    required String artist,
    String? album,
    int? durationSecs,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final connectType = _bluetoothConnection?.connectType;
    if (connectType != ConnectType.ble && connectType != ConnectType.spp) {
      throw UnsupportedError('Music upload requires a BLE or SPP connection');
    }
    final system = entity.system<XiaomiMediaSystem>();
    if (system == null) {
      throw UnsupportedError('Music transfer service is unavailable');
    }
    final id = crypto.md5.convert(bytes).bytes;
    _activeTransfers += 1;
    try {
      await system.uploadSongWithProgress(
        pb_media.Song(
          id: id,
          name: title,
          size: bytes.length,
          duration: durationSecs ?? 0,
          album: album ?? '',
          artist: artist,
        ),
        bytes,
        onProgress: (value) {
          if (value.bytesTotal > 0) {
            onProgress?.call(value.bytesSent / value.bytesTotal);
          }
        },
      );
    } finally {
      _activeTransfers -= 1;
    }
  }

  XiaomiMediaSystem _requireXiaomiMediaSystem() {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    return entity.system<XiaomiMediaSystem>() ??
        (throw UnsupportedError('Music management service is unavailable'));
  }

  @override
  Future<DeviceMusicLibrary> loadXiaomiMusicLibrary() async {
    final system = _requireXiaomiMediaSystem();
    final pb_media.SongSummary summary;
    try {
      summary = await system.requestSongSummary();
    } on TimeoutException {
      throw UnsupportedError('music_unsupported');
    }
    final songs = <DeviceMusicSong>[];
    var index = 0;
    for (var page = 0; page < 100 && songs.length < summary.songCount; page++) {
      final response = await system.requestSongPage(index);
      songs.addAll(
        response.list.map(
          (song) => DeviceMusicSong(
            id: song.id.toList(growable: false),
            name: song.name,
            size: song.size,
            duration: song.duration,
            album: song.album,
            artist: song.artist,
          ),
        ),
      );
      if (response.list.isEmpty || response.nextIndex <= index) break;
      index = response.nextIndex;
    }
    final playlists = summary.list
        .map(
          (item) => DeviceMusicPlaylist(
            id: item.id,
            name: item.name,
            songCount: item.songCount,
          ),
        )
        .toList(growable: false);
    final memberships = <String, List<int>>{};
    for (final playlist in playlists) {
      final response = await system.requestSonglistOperation(
        pb_media.Songlist_Request(
          cmd: pb_media_enum.Songlist_Request_Cmd.QUERY_SONG,
          id: playlist.id,
        ),
        pb_media_enum.Media_MediaID.QUERY_SONG_FOR_SONGLIST,
      );
      if (response.code != pb_media_enum.Songlist_Response_Code.NO_ERROR) {
        continue;
      }
      for (final song in songs) {
        if (_containsBytes(response.songIds, song.id)) {
          memberships.putIfAbsent(song.id.join(','), () => []).add(playlist.id);
        }
      }
    }
    return DeviceMusicLibrary(
      songs: songs
          .map(
            (song) => DeviceMusicSong(
              id: song.id,
              name: song.name,
              size: song.size,
              duration: song.duration,
              album: song.album,
              artist: song.artist,
              playlistIds: memberships[song.id.join(',')] ?? const [],
            ),
          )
          .toList(growable: false),
      playlists: playlists,
      playlistLimit: summary.songlistLimit,
    );
  }

  Future<void> _xiaomiPlaylistOperation({
    required pb_media_enum.Media_MediaID mediaId,
    required pb_media_enum.Songlist_Request_Cmd command,
    int id = 0,
    String name = '',
  }) async {
    final response = await _requireXiaomiMediaSystem().requestSonglistOperation(
      pb_media.Songlist_Request(cmd: command, id: id, name: name),
      mediaId,
    );
    if (response.code != pb_media_enum.Songlist_Response_Code.NO_ERROR) {
      throw ProtocolException(
        'Playlist operation failed: ${response.code.name}',
      );
    }
  }

  @override
  Future<void> createXiaomiMusicPlaylist(String name) async {
    final summary = await _requireXiaomiMediaSystem().requestSongSummary();
    final usedIds = summary.list.map((playlist) => playlist.id).toSet();
    var id = 1;
    while (usedIds.contains(id)) {
      id++;
    }
    await _xiaomiPlaylistOperation(
      mediaId: pb_media_enum.Media_MediaID.ADD_SONGLIST,
      command: pb_media_enum.Songlist_Request_Cmd.ADD,
      id: id,
      name: name,
    );
  }

  @override
  Future<void> renameXiaomiMusicPlaylist(int id, String name) =>
      _xiaomiPlaylistOperation(
        mediaId: pb_media_enum.Media_MediaID.RENAME_SONGLIST,
        command: pb_media_enum.Songlist_Request_Cmd.RENAME,
        id: id,
        name: name,
      );

  @override
  Future<void> removeXiaomiMusicPlaylist(int id) => _xiaomiPlaylistOperation(
    mediaId: pb_media_enum.Media_MediaID.REMOVE_SONGLIST,
    command: pb_media_enum.Songlist_Request_Cmd.REMOVE,
    id: id,
  );

  @override
  Future<void> removeXiaomiMusicSong(List<int> id) async {
    final response = await _requireXiaomiMediaSystem().requestRemoveSong(
      Uint8List.fromList(id),
    );
    if (!response.success) {
      throw ProtocolException('The device could not delete the song');
    }
  }

  @override
  Future<void> setXiaomiMusicSongInPlaylist({
    required int playlistId,
    required List<int> songId,
    required bool included,
  }) async {
    final response = await _requireXiaomiMediaSystem().requestSonglistOperation(
      pb_media.Songlist_Request(
        cmd: included
            ? pb_media_enum.Songlist_Request_Cmd.ADD_SONG
            : pb_media_enum.Songlist_Request_Cmd.REMOVE_SONG,
        id: playlistId,
        songIds: songId,
      ),
      included
          ? pb_media_enum.Media_MediaID.ADD_SONG_TO_SONGLIST
          : pb_media_enum.Media_MediaID.REMOVE_SONG_FROM_SONGLIST,
    );
    if (response.code != pb_media_enum.Songlist_Response_Code.NO_ERROR) {
      throw ProtocolException(
        'Failed to update playlist: ${response.code.name}',
      );
    }
  }

  bool _containsBytes(List<int> haystack, List<int> needle) {
    if (needle.isEmpty || haystack.length < needle.length) return false;
    for (var start = 0; start <= haystack.length - needle.length; start++) {
      var matches = true;
      for (var offset = 0; offset < needle.length; offset++) {
        if (haystack[start + offset] != needle[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  @override
  Future<List<MediaFileDescriptor>> fetchXiaomiRecordingList() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final media = entity.system<XiaomiMediaSystem>();
    if (media == null) {
      throw UnsupportedError('Device recording service is unavailable');
    }
    List<MediaFileDescriptor> files;
    try {
      files = await media.requestMediaFileList();
    } on TimeoutException {
      // The device did not respond to the media file list request within timeout.
      // Indicates the device firmware does not support media recording sync.
      throw UnsupportedError('recording_unsupported');
    } catch (_) {
      files = await media.requestMediaFileListCompat();
    }
    return files
        .where(
          (file) =>
              file.identifier != null &&
              (file.mediaType == pb_media_enum.MediaFile_Type.OPUS ||
                  file.mediaType == pb_media_enum.MediaFile_Type.PCM ||
                  file.mediaType == pb_media_enum.MediaFile_Type.SBC ||
                  file.mediaType == pb_media_enum.MediaFile_Type.MSBC ||
                  file.name.toLowerCase().endsWith('.opus') ||
                  file.name.toLowerCase().endsWith('.pcm') ||
                  file.name.toLowerCase().endsWith('.sbc') ||
                  file.name.toLowerCase().endsWith('.msbc') ||
                  file.name.toLowerCase().endsWith('.ogg')),
        )
        .toList(growable: false);
  }

  @override
  Future<List<DeviceRecording>> downloadSelectedXiaomiRecordings({
    required List<MediaFileDescriptor> files,
    void Function(int completed, int total, String fileName)? onProgress,
    void Function(DeviceRecordingPullProgress progress)? onDetailedProgress,
  }) async {
    if (_recordingSyncCancellation != null) {
      throw StateError('Recording synchronization is already running');
    }
    final cancellation = Completer<void>();
    _recordingSyncCancellation = cancellation;
    Future<T> cancellable<T>(Future<T> operation) => Future.any([
      operation,
      cancellation.future.then<T>(
        (_) => throw const ProtocolException(
          'Recording synchronization was cancelled',
        ),
      ),
    ]);
    try {
      final entity = _currentEntity;
      if (entity == null || state.protocolState != ProtocolState.ready) {
        throw ProtocolException('Device not ready');
      }
      final media = entity.system<XiaomiMediaSystem>();
      if (media == null) {
        throw UnsupportedError('Device recording service is unavailable');
      }
      final recordings = files
          .where((f) => f.identifier != null)
          .toList(growable: false);
      final results = <DeviceRecording>[];
      for (var index = 0; index < recordings.length; index++) {
        final descriptor = recordings[index];
        final identifier = descriptor.identifier!;
        onProgress?.call(index, recordings.length, descriptor.name);
        final data = await cancellable(
          media.pullAudioRecord(
            identifier,
            onProgress: (progress, currentPart, totalParts) {
              final overall = recordings.isEmpty
                  ? 1.0
                  : ((index + progress) / recordings.length)
                        .clamp(0, 1)
                        .toDouble();
              final size = descriptor.size;
              onDetailedProgress?.call(
                DeviceRecordingPullProgress(
                  progress: overall,
                  currentIndex: index + 1,
                  totalFiles: recordings.length,
                  fileName: descriptor.name,
                  currentPart: currentPart,
                  totalParts: totalParts,
                  bytesDone: size == null ? null : (size * progress).round(),
                  bytesTotal: size,
                ),
              );
            },
          ),
        );
        results.add(
          DeviceRecording(
            fileName: descriptor.name,
            data: data,
            durationSeconds: descriptor.durationSecs,
            createdAt: descriptor.createdAtMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(descriptor.createdAtMs!),
          ),
        );
        onProgress?.call(index + 1, recordings.length, descriptor.name);
      }
      return results;
    } finally {
      if (identical(_recordingSyncCancellation, cancellation)) {
        _recordingSyncCancellation = null;
      }
    }
  }

  @override
  Future<List<DeviceRecording>> downloadXiaomiRecordings({
    void Function(int completed, int total, String fileName)? onProgress,
    void Function(DeviceRecordingPullProgress progress)? onDetailedProgress,
  }) async {
    final files = await fetchXiaomiRecordingList();
    return downloadSelectedXiaomiRecordings(
      files: files,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  @override
  Future<DeviceLogPullResult> pullDeviceLogs({
    void Function(double progress, String fileName)? onProgress,
    void Function(DeviceLogPullProgress progress)? onDetailedProgress,
    void Function(String stage)? onStage,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final report = entity.system<XiaomiReportSystem>();
    final mass = entity.system<XiaomiMassSystem>();
    if (report == null || mass == null) {
      throw UnsupportedError(
        'Device log export is only available for Xiaomi wearables',
      );
    }
    const channel = L2Channel.mass;
    var activitySeen = false;
    var currentProgress = 0.0;
    var lastActivity = DateTime.now();
    final activity = Completer<void>();
    final receive = mass.beginReverseMassReceive(
      channel,
      progressCb: (value) {
        activitySeen = true;
        currentProgress = value.progress.clamp(0, 1).toDouble();
        lastActivity = DateTime.now();
        if (!activity.isCompleted) activity.complete();
        onProgress?.call(currentProgress, value.fileName);
        onDetailedProgress?.call(
          DeviceLogPullProgress(
            progress: currentProgress,
            fileName: value.fileName,
            channel: value.channel,
            currentPart: value.currentPartNum,
            totalParts: value.totalParts,
          ),
        );
      },
    );
    try {
      onStage?.call('waiting_response');
      final reportFuture = report.requestDeviceLogExport(
        // AstroBox-NG treats this as the report-response phase only.  It is
        // never allowed to cancel an already active MASS transfer.
        timeout: const Duration(seconds: 30),
      );
      final startEvent = await Future.any<Object>([
        reportFuture,
        activity.future.then<Object>((_) => true),
      ]);
      if (startEvent is! pb_system.ReportData_Result) {
        // Some firmware starts the MASS stream before sending the report
        // response.  Once bytes are observed, the stream is the authoritative
        // acknowledgement and waiting for a second response only creates a
        // false timeout.
        report.cancelDeviceLogExport();
        onStage?.call('waiting_transfer');
        if (!activitySeen) {
          await activity.future.timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw const ProtocolException(
                'Device acknowledged log export but did not start streaming within 60s',
              );
            },
          );
        }
        onStage?.call('transferring');
        final result = await _awaitDeviceLogTransfer(
          receive,
          lastActivity: () => lastActivity,
          progress: () => currentProgress,
        );
        return DeviceLogPullResult(
          fileName: result.fileName,
          data: result.data,
        );
      }
      final start = startEvent;
      if (start.status != pb_system.ReportData_Status.SUCCESS) {
        if (start.status == pb_system.ReportData_Status.URL_DIRECT) {
          throw UnsupportedError(
            'This device requested direct log download, which is not supported',
          );
        }
        throw ProtocolException(
          'Device log export failed: ${start.status.name}',
        );
      }
      onStage?.call('waiting_transfer');
      if (!activitySeen) {
        await activity.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw const ProtocolException(
              'Device acknowledged log export but did not start streaming within 60s',
            );
          },
        );
      }
      onStage?.call('transferring');
      final result = await _awaitDeviceLogTransfer(
        receive,
        lastActivity: () => lastActivity,
        progress: () => currentProgress,
      );
      return DeviceLogPullResult(fileName: result.fileName, data: result.data);
    } finally {
      report.cancelDeviceLogExport();
      mass.cancelReverseMassReceive(channel);
    }
  }

  Future<ReverseMassReceiveResult> _awaitDeviceLogTransfer(
    Future<ReverseMassReceiveResult> receive, {
    required DateTime Function() lastActivity,
    required double Function() progress,
  }) async {
    final startedAt = DateTime.now();
    final timeout = Completer<ReverseMassReceiveResult>();
    final watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (timeout.isCompleted) return;
      final now = DateTime.now();
      final idle = now.difference(lastActivity());
      final elapsed = now.difference(startedAt);
      if (idle >= const Duration(seconds: 30) ||
          elapsed >= const Duration(minutes: 10)) {
        timeout.completeError(
          _DeviceLogTransferTimeout(
            idle: idle,
            elapsed: elapsed,
            progress: progress(),
          ),
        );
      }
    });
    try {
      return await Future.any<ReverseMassReceiveResult>([
        receive,
        timeout.future,
      ]);
    } finally {
      watchdog.cancel();
    }
  }

  @override
  Future<void> cancelDeviceLogPull() async {
    final entity = _currentEntity;
    entity?.system<XiaomiReportSystem>()?.cancelDeviceLogExport();
    final mass = entity?.system<XiaomiMassSystem>();
    for (final channel in const [
      L2Channel.mass,
      L2Channel.fileSensor,
      L2Channel.fileFitness,
    ]) {
      mass?.cancelReverseMassReceive(channel);
      mass?.clearReverseMassWait(channel);
    }
  }

  @override
  Future<void> fetchSystemInfo() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppInfoSystem = entity.system<ZeppOsDeviceInfoSystem>();
    if (zeppInfoSystem != null) {
      final servicesSystem = entity.system<ZeppOsServicesSystem>();
      if (servicesSystem == null) {
        throw StateError('Zepp OS services discovery is unavailable');
      }
      final services = await servicesSystem.fetchSupportedServices();
      if (!services.containsKey(ZeppOsDeviceInfoSystem.endpoint)) {
        throw UnsupportedError(
          'This Zepp OS device does not advertise Device Info',
        );
      }
      zeppInfoSystem.encrypted =
          services[ZeppOsDeviceInfoSystem.endpoint] ?? false;
      final info = await zeppInfoSystem.fetchDeviceInfo();
      if (_currentEntity != entity) return;
      state = state.copyWith(systemInfo: info);
      return;
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      throw UnsupportedError('Device information is unavailable');
    }
    final info = await _fetchDeviceInfoWithEuiccFallback(infoSystem);
    if (_currentEntity != entity) return;
    state = state.copyWith(systemInfo: info);
  }

  @override
  Future<void> fetchStorageInfo() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      return;
    }
    final info = await infoSystem.fetchStorageInfo();
    final currentInfo = state.systemInfo;
    state = state.copyWith(
      systemInfo:
          currentInfo?.copyWith(storageInfo: info) ??
          SystemInfo(
            serialNumber: '',
            firmwareVersion: '',
            imei: '',
            model: '',
            storageInfo: info,
          ),
    );
  }

  @override
  Future<void> fetchApps() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppAppsSystem = entity.system<ZeppOsAppsSystem>();
    if (zeppAppsSystem != null) {
      await _refreshZeppOsApps(entity, zeppAppsSystem);
      return;
    }
    final resourceSystem = entity.system<XiaomiResourceSystem>();
    if (resourceSystem == null) {
      throw StateError(
        'Zepp OS app management was added after this device session started. '
        'Reconnect the device once to load it.',
      );
    }
    final items = await resourceSystem.fetchInstalledQuickApps();
    final apps = items
        .map(
          (item) => AppInfo(
            packageName: item.packageName,
            fingerprint: item.fingerprint,
            versionCode: item.versionCode,
            canRemove: item.canRemove,
            appName: item.appName,
          ),
        )
        .toList();
    _log.info('event: quick app list ${apps.length}');
    state = state.copyWith(apps: apps);
  }

  @override
  Future<List<AppInfo>> loadXiaomiAppOrder() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      throw UnsupportedError('Xiaomi app ordering is unavailable');
    }
    return infoSystem.fetchInstalledApps();
  }

  @override
  Future<void> setXiaomiAppOrder(List<AppInfo> apps) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      throw UnsupportedError('Xiaomi app ordering is unavailable');
    }
    await infoSystem.setOrderedApps(apps);
  }

  @override
  Future<List<XiaomiAlarm>> loadXiaomiAlarms() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      throw UnsupportedError('Xiaomi alarms are unavailable');
    }
    return infoSystem.fetchAlarms();
  }

  @override
  Future<void> addXiaomiAlarm(XiaomiAlarm alarm) async {
    await _requireXiaomiInfoSystem().addAlarm(alarm);
  }

  @override
  Future<void> updateXiaomiAlarm(XiaomiAlarm alarm) async {
    await _requireXiaomiInfoSystem().updateAlarm(alarm);
  }

  @override
  Future<void> removeXiaomiAlarm(int id) async {
    await _requireXiaomiInfoSystem().removeAlarm(id);
  }

  @override
  Future<void> setXiaomiAlarmEnabled(int id, bool enabled) async {
    await _requireXiaomiInfoSystem().setAlarmEnabled(id, enabled);
  }

  @override
  Future<void> syncXiaomiWeather(XiaomiWeatherData weather) async {
    _log.info(
      'Xiaomi weather synchronization requested for ${_currentEntity?.id}: '
      'city=${weather.cityName}, source=${weather.source.name}',
    );
    await _requireXiaomiInfoSystem().sendWeather(weather);
    _log.info(
      'Xiaomi weather synchronization completed for ${_currentEntity?.id}: '
      'city=${weather.cityName}',
    );
  }

  XiaomiInfoSystem _requireXiaomiInfoSystem() {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    return entity.system<XiaomiInfoSystem>() ??
        (throw UnsupportedError(
          'Xiaomi device feature service is unavailable',
        ));
  }

  @override
  Future<void> fetchWatchfaces() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppWatchfaceSystem = entity.system<ZeppOsWatchfaceSystem>();
    if (zeppWatchfaceSystem != null) {
      await _refreshZeppOsWatchfaces(entity, zeppWatchfaceSystem);
      return;
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      throw UnsupportedError('This device does not support watchface listing');
    }
    final watchfaces = await infoSystem.fetchInstalledWatchfaces();
    state = state.copyWith(watchfaces: watchfaces);
  }

  @override
  Future<void> openApp(AppInfo app, {String page = ''}) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppAppsSystem = entity.system<ZeppOsAppsSystem>();
    if (zeppAppsSystem != null) {
      await _configureZeppOsAppsSystem(entity, zeppAppsSystem);
      _log.info('opening ZeppOS app ${app.packageName}');
      await zeppAppsSystem.launchApp(app.packageName);
      return;
    }
    _log.info('opening app ${app.packageName} page="$page"');
    final thirdpartySystem = entity.system<XiaomiThirdpartyAppSystem>();
    if (thirdpartySystem == null) {
      throw StateError(
        'Zepp OS app management was added after this device session started. '
        'Reconnect the device once to load it.',
      );
    }
    await thirdpartySystem.launchApp(_thirdpartyAppInfo(app), page);
  }

  @override
  Future<void> sendInterconnectMessage(
    String packageName,
    Uint8List payload,
  ) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    var app = state.apps.cast<AppInfo?>().firstWhere(
      (candidate) => candidate?.packageName == packageName,
      orElse: () => null,
    );
    if (app == null) {
      await fetchApps();
      app = state.apps.cast<AppInfo?>().firstWhere(
        (candidate) => candidate?.packageName == packageName,
        orElse: () => null,
      );
    }
    if (app == null) {
      throw StateError('Quick app is not installed: $packageName');
    }
    final system = entity.system<XiaomiThirdpartyAppSystem>();
    if (system == null) {
      throw UnsupportedError(
        'Interconnect messaging is only available for Xiaomi wearables',
      );
    }
    _log.info(
      'sending interconnect message to $packageName (${payload.length} bytes)',
    );
    await system.sendPhoneMessage(
      packageName,
      payload,
      app: _thirdpartyAppInfo(app),
    );
    _log.info('interconnect message queued for $packageName');
  }

  @override
  Future<void> sendRaw(Uint8List payload) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    await entity.transport.send(payload);
  }

  @override
  Future<Uint8List> requestRaw(
    Uint8List payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final buffer = BytesBuilder();
    final completer = Completer<Uint8List>();
    Timer? quiet;
    final overall = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(buffer.takeBytes());
    });
    final subscription = rawProtocolFrames.listen((frame) {
      buffer.add(frame);
      quiet?.cancel();
      quiet = Timer(const Duration(milliseconds: 300), () {
        if (!completer.isCompleted) completer.complete(buffer.takeBytes());
      });
    });
    try {
      await entity.transport.send(payload);
      return await completer.future;
    } finally {
      quiet?.cancel();
      overall.cancel();
      await subscription.cancel();
    }
  }

  @override
  Future<void> uninstallApp(AppInfo app) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppAppsSystem = entity.system<ZeppOsAppsSystem>();
    if (zeppAppsSystem != null) {
      await _configureZeppOsAppsSystem(entity, zeppAppsSystem);
      _log.info('uninstalling ZeppOS app ${app.packageName}');
      await zeppAppsSystem.uninstallApp(app.packageName);
      state = state.copyWith(
        apps: state.apps
            .where((candidate) => candidate.packageName != app.packageName)
            .toList(),
      );
      return;
    }
    _log.info('uninstalling app ${app.packageName}');
    final thirdpartySystem = entity.system<XiaomiThirdpartyAppSystem>();
    if (thirdpartySystem == null) {
      throw StateError(
        'Zepp OS app management was added after this device session started. '
        'Reconnect the device once to load it.',
      );
    }
    await thirdpartySystem.uninstallApp(_thirdpartyAppInfo(app));
    state = state.copyWith(
      apps: state.apps.where((a) => a.packageName != app.packageName).toList(),
    );
  }

  ThirdpartyAppInfo _thirdpartyAppInfo(AppInfo app) {
    return ThirdpartyAppInfo(
      packageName: app.packageName,
      fingerprint: Uint8List.fromList(app.fingerprint),
    );
  }

  Future<void> _configureZeppOsAppsSystem(
    DeviceEntity entity,
    ZeppOsAppsSystem appsSystem,
  ) async {
    final servicesSystem = entity.system<ZeppOsServicesSystem>();
    if (servicesSystem == null) {
      throw StateError(
        'Zepp OS services discovery is unavailable in this device session. '
        'Reconnect the device once to reload its protocol systems.',
      );
    }
    final services = await servicesSystem.fetchSupportedServices();
    if (!services.containsKey(ZeppOsAppsSystem.endpoint)) {
      throw UnsupportedError(
        'This Zepp OS device does not support app management',
      );
    }
    // Gadgetbridge's ZeppOsAppsService explicitly returns false from
    // isEncrypted(). Endpoint 0x00a0 must stay clear-text even if a device's
    // advertised services flags are ambiguous.
    appsSystem.encrypted = false;
    if (services.containsKey(ZeppOsAppsSystem.launchEndpoint)) {
      appsSystem.launchEncrypted =
          services[ZeppOsAppsSystem.launchEndpoint] ?? true;
    }
  }

  Future<void> _refreshZeppOsApps(
    DeviceEntity entity,
    ZeppOsAppsSystem appsSystem,
  ) async {
    await _configureZeppOsAppsSystem(entity, appsSystem);
    final allApps = await appsSystem.fetchApps();
    final watchfaceIds = state.watchfaces.map((item) => item.id).toSet();
    final versions = {
      for (final app in allApps) app.packageName: app.versionCode,
    };
    final apps = allApps
        .where((app) => !watchfaceIds.contains(app.packageName))
        .toList(growable: false);
    final watchfaces = state.watchfaces
        .map(
          (watchface) => watchface.copyWith(
            versionCode: versions[watchface.id] ?? watchface.versionCode,
          ),
        )
        .toList(growable: false);
    _log.info(
      'ZeppOS package catalog: ${apps.length} apps, '
      '${watchfaces.length} watchfaces',
    );
    state = state.copyWith(apps: apps, watchfaces: watchfaces);
  }

  Future<void> _refreshZeppOsWatchfaces(
    DeviceEntity entity,
    ZeppOsWatchfaceSystem watchfaceSystem,
  ) async {
    await _configureZeppOsWatchfaceSystem(entity, watchfaceSystem);
    final watchfaces = await watchfaceSystem.fetchWatchfaces();
    final versions = {
      for (final app in state.apps) app.packageName: app.versionCode,
    };
    state = state.copyWith(
      watchfaces: watchfaces
          .map(
            (watchface) => watchface.copyWith(
              versionCode: versions[watchface.id] ?? watchface.versionCode,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _configureZeppOsWatchfaceSystem(
    DeviceEntity entity,
    ZeppOsWatchfaceSystem watchfaceSystem,
  ) async {
    final servicesSystem = entity.system<ZeppOsServicesSystem>();
    if (servicesSystem == null) {
      throw StateError('Zepp OS services discovery is unavailable');
    }
    final services = await servicesSystem.fetchSupportedServices();
    if (!services.containsKey(ZeppOsWatchfaceSystem.endpoint)) {
      throw UnsupportedError(
        'This Zepp OS device does not support watchface management',
      );
    }
    watchfaceSystem.encrypted =
        services[ZeppOsWatchfaceSystem.endpoint] ?? true;
  }

  @override
  Future<void> uninstallWatchface(WatchfaceInfo watchface) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppAppsSystem = entity.system<ZeppOsAppsSystem>();
    if (zeppAppsSystem != null) {
      await _configureZeppOsAppsSystem(entity, zeppAppsSystem);
      _log.info('uninstalling ZeppOS watchface ${watchface.id}');
      await zeppAppsSystem.uninstallApp(watchface.id);
      state = state.copyWith(
        watchfaces: state.watchfaces
            .where((item) => item.id != watchface.id)
            .toList(),
      );
      return;
    }
    _log.info('uninstalling watchface ${watchface.id}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.WATCH_FACE,
      id: pb_watchface.WatchFace_WatchFaceID.REMOVE_WATCH_FACE.value,
      watchFace: pb_watchface.WatchFace(id: watchface.id),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      watchfaces: state.watchfaces.where((w) => w.id != watchface.id).toList(),
    );
  }

  @override
  Future<void> setWatchface(WatchfaceInfo watchface) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppWatchfaceSystem = entity.system<ZeppOsWatchfaceSystem>();
    if (zeppWatchfaceSystem != null) {
      await _configureZeppOsWatchfaceSystem(entity, zeppWatchfaceSystem);
      _log.info('setting ZeppOS watchface ${watchface.id}');
      await zeppWatchfaceSystem.setWatchface(watchface.id);
      state = state.copyWith(
        watchfaces: state.watchfaces
            .map((item) => item.copyWith(isCurrent: item.id == watchface.id))
            .toList(),
      );
      return;
    }
    _log.info('setting watchface ${watchface.id}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.WATCH_FACE,
      id: pb_watchface.WatchFace_WatchFaceID.SET_WATCH_FACE.value,
      watchFace: pb_watchface.WatchFace(id: watchface.id),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      watchfaces: state.watchfaces.map((w) {
        return w.id == watchface.id
            ? w.copyWith(isCurrent: true)
            : w.copyWith(isCurrent: false);
      }).toList(),
    );
  }

  Future<T> _withTransfer<T>(Future<T> Function() operation) async {
    _activeTransfers += 1;
    try {
      return await operation();
    } finally {
      _activeTransfers -= 1;
    }
  }

  @override
  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
    void Function()? onAppSideMissing,
  }) => _withTransfer(
    () => _installApp(
      packageBytes,
      packageName: packageName,
      onProgress: onProgress,
      onAppSideMissing: onAppSideMissing,
    ),
  );

  Future<void> _installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
    void Function()? onAppSideMissing,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    if (entity.system<ZeppOsAppsSystem>() != null) {
      final installer = entity.system<ZeppOsAppInstallSystem>();
      if (installer == null) {
        throw StateError('Zepp OS installer was not loaded for this session');
      }
      final info = entity.system<ZeppOsDeviceInfoSystem>();
      final source = info?.deviceSource;
      final package = const ZeppOsPackageParser().parse(
        packageBytes,
        deviceSources: source == null ? const {} : {source},
      );
      if (package.type != ZeppOsPackageType.app) {
        throw FormatException(
          'Selected package is ${package.type.name}, not a Zepp OS app',
        );
      }
      _log.info(
        'installing Zepp OS app ${package.name ?? packageName} '
        '(${package.bytes.length} bytes)',
      );
      await installer.install(package, onProgress: onProgress);
      final appId = package.appId;
      if (appId != null) {
        final storage = ZeppOsAppSideStorage();
        final appSideJs = package.appSideJs;
        if (appSideJs != null) {
          await storage.save(appId, appSideJs);
          _log.info(
            'cached Zepp OS app-side.js for '
            '0x${appId.toRadixString(16).padLeft(8, '0')}',
          );
        }
        if (appSideJs == null) onAppSideMissing?.call();
        final settingJs = package.settingJs;
        if (settingJs != null) {
          await storage.saveSetting(
            appId,
            settingJs,
            assets: package.settingAssets,
            appName: package.name,
          );
          _log.info(
            'cached Zepp OS setting.js for '
            '0x${appId.toRadixString(16).padLeft(8, '0')}',
          );
        }
        if (appSideJs == null && settingJs == null) {
          _log.info(
            'installed Zepp OS app 0x${appId.toRadixString(16).padLeft(8, '0')} '
            'without app-side or settings',
          );
        }
      }
      // D5/D6 are the completion acknowledgement. Do not hold the completed
      // queue item open while the watch indexes the newly installed app.
      return;
    }
    _log.info('installing app $packageName (${packageBytes.length} bytes)');
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    await installSystem.installApp(
      packageBytes,
      packageName: packageName,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  }) => _withTransfer(
    () => _installWatchface(
      watchfaceBytes,
      watchfaceId: watchfaceId,
      onProgress: onProgress,
    ),
  );

  Future<void> _installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    if (entity.system<ZeppOsAppsSystem>() != null) {
      final installer = entity.system<ZeppOsAppInstallSystem>();
      if (installer == null) {
        throw StateError('Zepp OS installer was not loaded for this session');
      }
      final source = entity.system<ZeppOsDeviceInfoSystem>()?.deviceSource;
      final package = const ZeppOsPackageParser().parse(
        watchfaceBytes,
        deviceSources: source == null ? const {} : {source},
      );
      if (package.type != ZeppOsPackageType.watchface) {
        throw FormatException(
          'Selected package is ${package.type.name}, not a Zepp OS watchface',
        );
      }
      _log.info(
        'installing Zepp OS watchface ${package.name ?? watchfaceId} '
        '(${package.bytes.length} bytes)',
      );
      await installer.install(package, onProgress: onProgress);
      return;
    }
    _log.info(
      'installing watchface $watchfaceId (${watchfaceBytes.length} bytes)',
    );
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    await installSystem.installWatchface(
      watchfaceBytes,
      watchfaceId: watchfaceId,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  }) => _withTransfer(
    () => _installFirmware(firmwareBytes, onProgress: onProgress),
  );

  Future<void> _installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    if (entity.system<ZeppOsAppsSystem>() != null) {
      final installer = entity.system<ZeppOsAppInstallSystem>();
      if (installer == null) {
        throw StateError('Zepp OS installer was not loaded for this session');
      }
      final source = entity.system<ZeppOsDeviceInfoSystem>()?.deviceSource;
      final package = const ZeppOsPackageParser().parse(
        firmwareBytes,
        deviceSources: source == null ? const {} : {source},
      );
      if (package.type != ZeppOsPackageType.firmware) {
        throw FormatException(
          'Selected package is ${package.type.name}, not Zepp OS firmware',
        );
      }
      _log.info('installing Zepp OS firmware (${package.bytes.length} bytes)');
      await installer.install(package, onProgress: onProgress);
      return;
    }
    _log.info('installing firmware (${firmwareBytes.length} bytes)');
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    await installSystem.installFirmware(firmwareBytes, onProgress: onProgress);
  }

  @override
  Future<void> importSharedDevice(MiWearState device) async {
    final normalized = _normalizeDeviceIdentity(device).copyWith(
      connectType: device.connectType.toLowerCase().isEmpty
          ? ConnectType.spp.name
          : device.connectType.toLowerCase(),
      disconnected: true,
    );
    final updatedPaired = List<MiWearState>.from(state.pairedDevices);
    final existingIndex = updatedPaired.indexWhere(
      (d) => deviceAddressEquals(d.addr, normalized.addr),
    );
    final current = state.currentDevice;
    final isCurrent =
        current != null && deviceAddressEquals(current.addr, normalized.addr);
    final existing = isCurrent
        ? current
        : (existingIndex >= 0 ? updatedPaired[existingIndex] : null);
    final imported = normalized.copyWith(
      addr: existing?.addr ?? normalized.addr,
      connectType: existing?.connectType ?? normalized.connectType,
      codename: normalized.codename ?? existing?.codename,
      authkey: normalized.authkey?.trim().isNotEmpty == true
          ? normalized.authkey!.trim()
          : existing?.authkey,
      disconnected: isCurrent && state.protocolState == ProtocolState.ready
          ? false
          : (existing?.disconnected ?? true),
    );
    if (existingIndex >= 0) {
      updatedPaired[existingIndex] = imported;
      for (var index = updatedPaired.length - 1; index >= 0; index--) {
        if (index != existingIndex &&
            deviceAddressEquals(updatedPaired[index].addr, imported.addr)) {
          updatedPaired.removeAt(index);
        }
      }
    } else {
      updatedPaired.add(imported);
    }
    state = state.copyWith(
      currentDevice: current == null || isCurrent ? imported : current,
      pairedDevices: updatedPaired,
      clearError: true,
    );
    await _savePairedDevices();
  }

  @override
  Future<void> downloadXiaomiEsimProfile(
    String activationCode, {
    String confirmationCode = '',
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<XiaomiLpaSystem>();
    if (system == null) {
      throw UnsupportedError('eSIM LPA is unavailable for this device');
    }
    await system.downloadProfile(
      activationCode,
      confirmationCode: confirmationCode,
    );
  }

  @override
  Future<int> importMiCloudDevices(List<MiCloudDevice> devices) async {
    final importable = [
      for (final device in devices)
        if (resolveMiCloudDeviceAddress(
              device,
              state.pairedDevices.map((item) => item.addr),
            )
            case final address?)
          MiCloudDevice(
            name: device.name,
            model: device.model,
            mac: address,
            authKey: device.authKey,
            firmwareVersion: device.firmwareVersion,
            serialNumber: device.serialNumber,
          ),
    ];
    _log.info(
      'importing ${importable.length}/${devices.length} Mi Cloud devices',
    );
    if (importable.isEmpty) return 0;

    final updatedPaired = List<MiWearState>.from(state.pairedDevices);
    for (final device in importable) {
      final identity = normalizeXiaomiWearableIdentity(device.model);
      final importedRaw = _normalizeDeviceIdentity(
        MiWearState(
          name: device.name.trim().isNotEmpty
              ? device.name.trim()
              : (identity?.displayName ?? device.model),
          addr: device.mac.trim(),
          connectType: ConnectType.spp.name,
          authkey: device.authKey.trim(),
          codename: identity?.codename,
          disconnected: true,
        ),
      );
      final existingIndex = updatedPaired.indexWhere(
        (d) => deviceAddressEquals(d.addr, importedRaw.addr),
      );
      final current = state.currentDevice;
      final isCurrent =
          current != null &&
          deviceAddressEquals(current.addr, importedRaw.addr);
      final existing = isCurrent
          ? current
          : (existingIndex >= 0 ? updatedPaired[existingIndex] : null);
      final isCurrentReady =
          isCurrent && state.protocolState == ProtocolState.ready;
      final imported = importedRaw.copyWith(
        addr: existing?.addr ?? importedRaw.addr,
        connectType: existing?.connectType ?? importedRaw.connectType,
        codename: importedRaw.codename ?? existing?.codename,
        disconnected: isCurrentReady ? false : (existing?.disconnected ?? true),
      );
      if (existingIndex >= 0) {
        updatedPaired[existingIndex] = imported;
        for (var index = updatedPaired.length - 1; index >= 0; index--) {
          if (index != existingIndex &&
              deviceAddressEquals(updatedPaired[index].addr, imported.addr)) {
            updatedPaired.removeAt(index);
          }
        }
      } else {
        updatedPaired.add(imported);
      }
    }

    final current = state.currentDevice;
    state = state.copyWith(
      currentDevice: current == null
          ? updatedPaired.firstWhere(
              (d) => deviceAddressEquals(d.addr, importable.first.mac.trim()),
            )
          : updatedPaired.firstWhere(
              (d) => deviceAddressEquals(d.addr, current.addr),
              orElse: () => current,
            ),
      pairedDevices: updatedPaired,
      clearError: true,
    );
    await _savePairedDevices();
    return importable.length;
  }
}

final deviceManagerProvider =
    NotifierProvider<DeviceManager, DeviceManagerState>(LocalDeviceManager.new);
