import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/core/models/xiaomi_health_models.dart';
import 'package:oronbox/src/device/core/device_state.dart';

enum DeviceConnectionPhase {
  preparing,
  connectingTransport,
  initializingProtocol,
  authenticating,
  fetchingDeviceStatus,
}

class DeviceManagerState {
  const DeviceManagerState({
    this.currentDevice,
    this.pairedDevices = const [],
    this.scannedDevices = const [],
    this.scanning = false,
    this.connecting = false,
    this.connectionTargetAddr,
    this.connectionTargetName,
    this.connectionPhase,
    this.connectStatus = 0,
    this.protocolState = ProtocolState.disconnected,
    this.battery,
    this.health,
    this.systemInfo,
    this.apps = const [],
    this.watchfaces = const [],
    this.xiaoAiActive = false,
    this.xiaoAiFrameCount = 0,
    this.xiaoAiCapabilities = const {},
    this.findingXiaomiWearable = false,
    this.uploadBytesPerSecond = 0,
    this.downloadBytesPerSecond = 0,
    this.error,
  });

  final MiWearState? currentDevice;
  final List<MiWearState> pairedDevices;
  final List<BTDeviceInfo> scannedDevices;
  final bool scanning;
  final bool connecting;
  final String? connectionTargetAddr;
  final String? connectionTargetName;
  final DeviceConnectionPhase? connectionPhase;
  final int connectStatus;
  final ProtocolState protocolState;
  final BatteryStatus? battery;
  final XiaomiHealthState? health;
  final SystemInfo? systemInfo;
  final List<AppInfo> apps;
  final List<WatchfaceInfo> watchfaces;
  final bool xiaoAiActive;
  final int xiaoAiFrameCount;
  final Map<String, Object?> xiaoAiCapabilities;
  final bool findingXiaomiWearable;
  final double uploadBytesPerSecond;
  final double downloadBytesPerSecond;
  final String? error;

  DeviceManagerState copyWith({
    MiWearState? currentDevice,
    List<MiWearState>? pairedDevices,
    List<BTDeviceInfo>? scannedDevices,
    bool? scanning,
    bool? connecting,
    String? connectionTargetAddr,
    String? connectionTargetName,
    DeviceConnectionPhase? connectionPhase,
    int? connectStatus,
    ProtocolState? protocolState,
    BatteryStatus? battery,
    XiaomiHealthState? health,
    SystemInfo? systemInfo,
    List<AppInfo>? apps,
    List<WatchfaceInfo>? watchfaces,
    bool? xiaoAiActive,
    int? xiaoAiFrameCount,
    Map<String, Object?>? xiaoAiCapabilities,
    bool? findingXiaomiWearable,
    double? uploadBytesPerSecond,
    double? downloadBytesPerSecond,
    String? error,
    bool clearCurrentDevice = false,
    bool clearBattery = false,
    bool clearHealth = false,
    bool clearSystemInfo = false,
    bool clearError = false,
    bool clearConnectionTarget = false,
    bool clearConnectionPhase = false,
  }) {
    return DeviceManagerState(
      currentDevice: clearCurrentDevice
          ? null
          : (currentDevice ?? this.currentDevice),
      pairedDevices: pairedDevices ?? this.pairedDevices,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      scanning: scanning ?? this.scanning,
      connecting: connecting ?? this.connecting,
      connectionTargetAddr: clearConnectionTarget
          ? null
          : (connectionTargetAddr ?? this.connectionTargetAddr),
      connectionTargetName: clearConnectionTarget
          ? null
          : (connectionTargetName ?? this.connectionTargetName),
      connectionPhase: clearConnectionPhase
          ? null
          : (connectionPhase ?? this.connectionPhase),
      connectStatus: connectStatus ?? this.connectStatus,
      protocolState: protocolState ?? this.protocolState,
      battery: clearBattery ? null : (battery ?? this.battery),
      health: clearHealth ? null : (health ?? this.health),
      systemInfo: clearSystemInfo ? null : (systemInfo ?? this.systemInfo),
      apps: apps ?? this.apps,
      watchfaces: watchfaces ?? this.watchfaces,
      xiaoAiActive: xiaoAiActive ?? this.xiaoAiActive,
      xiaoAiFrameCount: xiaoAiFrameCount ?? this.xiaoAiFrameCount,
      xiaoAiCapabilities: xiaoAiCapabilities ?? this.xiaoAiCapabilities,
      findingXiaomiWearable:
          findingXiaomiWearable ?? this.findingXiaomiWearable,
      uploadBytesPerSecond: uploadBytesPerSecond ?? this.uploadBytesPerSecond,
      downloadBytesPerSecond:
          downloadBytesPerSecond ?? this.downloadBytesPerSecond,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
