# universal_ble — OpenHarmony 平台通道契约（必须逐条对齐）

> 来源：`Navideck/universal_ble`（OronBox 使用 `^2.1.0`）。
> 关键修正：它不是普通 `MethodChannel`，而是用 **Pigeon** 生成跨平台消息层。
> 通道名 = Pigeon `@HostApi(name: '...')` 的类名；必须用 `StandardMessageCodec`，不能手写 MethodChannel 字符串方法。

## 通道（HostApi = 原生端需实现；FlutterApi = Dart 端回调）

| 类名 | 类型 | 说明 |
|------|------|------|
| `UniversalBlePlatformChannel` | HostApi | 中心设备（Central），app 真正调用 |
| `UniversalBleCallbackChannel` | FlutterApi | 事件回调：扫描结果 / 连接状态 / 特征值变化 |
| `UniversalBlePeripheralChannel` | HostApi | 外设模式（app 不用，可留空实现） |
| `UniversalBleAndroidChannel` | HostApi | 仅 Android |

## UniversalBlePlatformChannel 方法签名（需在 C++ host 实现）

```dart
// 返回值/参数已简化，完整以 pigeon 定义文件为准
Future<BleAvailabilityState> getBluetoothAvailabilityState();
Future<bool> isBluetoothEnabled();
Future<void> startScan(ScanFilter filter, bool androidUseFineLocation);
Future<void> stopScan();
Future<void> connect(String deviceId);
Future<void> disconnect(String deviceId);
Future<ConnectionState> getConnectionState(String deviceId);
Future<List<Service>> discoverServices(String deviceId);
Future<Uint8List> readValue(String deviceId, String characteristicId, [String? descriptorId]);
Future<void> writeValue(String deviceId, String characteristicId, Uint8List value, WriteType writeType);
Future<void> setNotifiable(String deviceId, String characteristicId, BleInputProperty bleInputProperty);
Future<int> requestMtu(String deviceId, int mtu);
Future<void> pair(String deviceId);
Future<bool> isPaired(String deviceId);
Future<int> getRssi(String deviceId);
```

## UniversalBleCallbackChannel 回调（C++ 端需主动调用，把事件推回 Dart）

```dart
void onScanResult(ScanResult result);
void onConnectionChanged(String deviceId, ConnectionState connectionState);
void onValueChanged(String deviceId, String characteristicId, Uint8List value);
void onPairingStateChange(String deviceId, bool isPaired, String? error);
void onBluetoothAvailabilityChange(BleAvailabilityState state);
```

## 枚举 / 数据模型（节选）

- `BleAvailabilityState`：unknown / unavailable / turningOn / on / turningOff / off
- `ConnectionState`：unknown / connecting / connected / disconnecting / disconnected
- `WriteType`：withResponse / withoutResponse
- `BleInputProperty`：notification / indication
- `ScanResult`：`deviceId, name, rssi, manufacturerData, serviceData, ...`
- `Service` / `Characteristic`：`uuid, characteristics[], properties...`

## OpenHarmony 侧实现路径

1. **生成 C++ Pigeon 骨架**（在 fork 根目录）：
   ```bash
   flutter pub run pigeon \
     --input pigeon/universal_ble.dart \
     --cpp_header_out ohos/include \
     --cpp_source_out ohos/src
   ```
2. 继承生成的 `UniversalBlePlatformChannel`，在每个方法体里调用 `@ohos.bluetooth.ble`
   （`GattClientDevice`：`connect` / `discoverServices` / `readCharacteristicValue` /
   `writeCharacteristicValue` / `setCharacteristicChangeNotification` / `setDeviceMtuSize` 等）。
3. 用 `UniversalBleCallbackChannel` 把扫描/连接/特征值事件推回 Dart。
4. OronBox 的 `pubspec.yaml` 把 `universal_ble` 指向这个 fork（git 依赖）。

## ohos 权限（module.json5 需声明）

- `ohos.permission.ACCESS_BLUETOOTH`
- `ohos.permission.USE_BLUETOOTH`
- `ohos.permission.LOCATION`（扫描需要）
- `ohos.permission.APPROXIMATELY_LOCATION`（API 12+）

> 注意：OpenHarmony 的 BLE 后台连接策略、扫描节流、MTU 协商与 Android 有差异，必须真机调试。
