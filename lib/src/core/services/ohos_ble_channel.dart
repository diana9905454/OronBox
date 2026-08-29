import 'dart:async';

import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';

/// 鸿蒙 BLE 的 UniversalBlePlatform 实现。
///
/// OronBox 依赖 universal_ble 插件做蓝牙，但该插件没有鸿蒙原生实现。
/// 本类继承 UniversalBlePlatform，通过 MethodChannel "oronbox/ble" 和
/// EventChannel "oronbox/ble_events" 与鸿蒙端 OhosBleBridge 通信，
/// 复用 UniversalBlePlatform 内置的 stream 管理（updateScanResult /
/// updateConnection / updateCharacteristicValue），使 ble_gatt_driver.dart
/// 等上层代码零改动即可在鸿蒙上工作。
class OhosUniversalBlePlatform extends UniversalBlePlatform {
  OhosUniversalBlePlatform._();

  static final OhosUniversalBlePlatform _instance =
      OhosUniversalBlePlatform._();
  static OhosUniversalBlePlatform get instance => _instance;

  static const MethodChannel _methodChannel = MethodChannel('oronbox/ble');
  static const EventChannel _eventChannel = EventChannel('oronbox/ble_events');

  // 保持订阅引用，防止被 GC 回收导致事件流中断。
  // ignore: unused_field
  StreamSubscription? _eventSubscription;
  bool _listening = false;

  /// 启动事件监听（首次使用时调用）。
  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        // ignore: avoid_print
        print('[OhosBlePlatform] event stream error: $e');
      },
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    switch (type) {
      case 'scanResult':
        final deviceId = event['deviceId'] as String? ?? '';
        final name = event['name'] as String? ?? '';
        final rssi = event['rssi'] as int?;
        if (deviceId.isEmpty) return;
        updateScanResult(
          BleDevice(
            deviceId: deviceId,
            name: name,
            rssi: rssi,
          ),
        );
        break;
      case 'connectionState':
        final deviceId = event['deviceId'] as String? ?? '';
        final connected = event['connected'] as bool? ?? false;
        if (deviceId.isEmpty) return;
        updateConnection(deviceId, connected);
        break;
      case 'characteristicChanged':
        final deviceId = event['deviceId'] as String? ?? '';
        final charUuid = event['charUuid'] as String? ?? '';
        final value = event['value'] as Uint8List?;
        if (deviceId.isEmpty || charUuid.isEmpty || value == null) return;
        updateCharacteristicValue(deviceId, charUuid, value, null);
        break;
      case 'mtuChanged':
        // MTU 变化暂不对外暴露，requestMtu 的返回值已够用。
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // UniversalBlePlatform 抽象方法实现
  // ---------------------------------------------------------------------------

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    final ok = await _methodChannel.invokeMethod<bool>('isAvailable');
    return (ok ?? false)
        ? AvailabilityState.poweredOn
        : AvailabilityState.poweredOff;
  }

  @override
  Future<bool> enableBluetooth() async {
    throw UnsupportedError('Not supported on ohos');
  }

  @override
  Future<bool> disableBluetooth() async {
    throw UnsupportedError('Not supported on ohos');
  }

  @override
  Future<void> requestPermissions({bool withAndroidFineLocation = false}) async {
    await _methodChannel.invokeMethod<bool>('requestPermissions');
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    _ensureListening();
    await _methodChannel.invokeMethod<bool>('startScan', {
      'services': scanFilter?.withServices ?? const [],
    });
  }

  @override
  Future<void> stopScan() async {
    await _methodChannel.invokeMethod<bool>('stopScan');
  }

  @override
  Future<bool> isScanning() async {
    // 鸿蒙端未单独跟踪扫描状态，简化处理。
    return false;
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
  }) async {
    _ensureListening();
    await _methodChannel.invokeMethod<bool>('connect', {'deviceId': deviceId});
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _methodChannel.invokeMethod<bool>('disconnect', {
      'deviceId': deviceId,
    });
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async {
    final raw = await _methodChannel.invokeMethod<List<dynamic>>(
      'discoverServices',
      {'deviceId': deviceId},
    );
    final services = <BleService>[];
    if (raw == null) return services;
    for (final svc in raw) {
      if (svc is! Map) continue;
      final serviceUuid = svc['uuid'] as String? ?? '';
      final characteristics = <BleCharacteristic>[];
      final chars = svc['characteristics'] as List<dynamic>? ?? [];
      for (final ch in chars) {
        if (ch is! Map) continue;
        final charUuid = ch['uuid'] as String? ?? '';
        final propStrs = ch['properties'] as List<dynamic>? ?? [];
        final properties = <CharacteristicProperty>[];
        for (final p in propStrs) {
          final mapped = _mapProperty(p as String?);
          if (mapped != null) properties.add(mapped);
        }
        characteristics.add(
          BleCharacteristic.withMetaData(
            deviceId: deviceId,
            serviceId: serviceUuid,
            uuid: charUuid,
            properties: properties,
            descriptors: const [],
          ),
        );
      }
      services.add(BleService(serviceUuid, characteristics));
    }
    return services;
  }

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {
    _ensureListening();
    final enable = bleInputProperty != BleInputProperty.disabled;
    await _methodChannel.invokeMethod<bool>('setNotify', {
      'deviceId': deviceId,
      'serviceUuid': service,
      'charUuid': characteristic,
      'enable': enable,
    });
  }

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) async {
    final value = await _methodChannel.invokeMethod<Uint8List>('read', {
      'deviceId': deviceId,
      'serviceUuid': service,
      'charUuid': characteristic,
    });
    return value ?? Uint8List(0);
  }

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    final withResponse = bleOutputProperty == BleOutputProperty.withResponse;
    await _methodChannel.invokeMethod<bool>('write', {
      'deviceId': deviceId,
      'serviceUuid': service,
      'charUuid': characteristic,
      'value': value,
      'writeType': withResponse ? 1 : 2,
    });
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    final result = await _methodChannel.invokeMethod<int>('requestMtu', {
      'deviceId': deviceId,
      'mtu': expectedMtu,
    });
    return result ?? expectedMtu;
  }

  @override
  Future<int> readRssi(String deviceId) async {
    final result = await _methodChannel.invokeMethod<int>('getRssi', {
      'deviceId': deviceId,
    });
    return result ?? 0;
  }

  @override
  Future<bool> isPaired(String deviceId) async {
    // 鸿蒙端未实现配对状态查询，返回 false（pair 会静默忽略）。
    return false;
  }

  @override
  Future<bool> pair(String deviceId) async {
    // 鸿蒙 BLE 连接本身不强制要求系统配对，返回 true 表示"无需配对"。
    return true;
  }

  @override
  Future<void> unpair(String deviceId) async {
    // 鸿蒙端未实现解除配对，静默忽略。
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    // 鸿蒙端连接状态通过 connectionState 事件推送，此处返回已连接需额外状态查询。
    // 简化：返回 disconnected（上层主要依赖 connectionStream）。
    return BleConnectionState.disconnected;
  }

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async {
    // 鸿蒙端未实现已配对设备查询，返回空列表。
    return const [];
  }

  CharacteristicProperty? _mapProperty(String? prop) {
    switch (prop) {
      case 'read':
        return CharacteristicProperty.read;
      case 'write':
        return CharacteristicProperty.write;
      case 'writeWithoutResponse':
        return CharacteristicProperty.writeWithoutResponse;
      case 'notify':
        return CharacteristicProperty.notify;
      case 'indicate':
        return CharacteristicProperty.indicate;
      case 'broadcast':
        return CharacteristicProperty.broadcast;
      default:
        return null;
    }
  }
}
