// universal_ble_ohos_host.cpp — Pigeon C++ host 骨架
//
// 正确流程（在 fork 的 universal_ble 根目录执行，生成基础类）：
//   flutter pub run pigeon \
//     --input pigeon/universal_ble.dart \
//     --cpp_header_out ohos/include \
//     --cpp_source_out ohos/src
//
// 然后继承生成的 UniversalBlePlatformChannel，在每个方法体里调用
// @ohos.bluetooth.ble（GattClientDevice 等）。下面仅列出方法签名与 TODO，
// 未编译，@ohos.bluetooth.ble 具体函数名请按你的 SDK 版本核对。
//
// 编译：用 OHOS NDK（--target=aarch64-linux-ohos）通过 CMake 产出
//       libuniversal_ble_ohos.so，供上方 .ets 加载。

#include "universal_ble.g.h"          // pigeon 生成的头（执行 pigeon 后存在）
#include <cstdint>
#include <vector>
#include <string>
#include "napi/native_api.h"

// 占位：真实实现需 #include <ble/...> 对应 OpenHarmony BLE C API 或走 @ohos.bluetooth.ble 的 NAPI 封装
namespace universal_ble {

// 继承 pigeon 生成的 UniversalBlePlatformChannel
class UniversalBleOhosHost : public UniversalBlePlatformChannel {
 public:
  // ---- 以下每个方法都需实现，调用 @ohos.bluetooth.ble 对应能力 ----

  // 蓝牙可用状态
  BleAvailabilityState GetBluetoothAvailabilityState() override {
    // TODO: 调 bluetooth 状态监听，返回 on/off/turningOn...
    return BleAvailabilityState::kOff;
  }

  bool IsBluetoothEnabled() override {
    // TODO: 返回上一项是否为 on
    return false;
  }

  void StartScan(const ScanFilter& filter, bool android_use_fine_location) override {
    // TODO: ble.startBLEScan(...) 注册扫描回调，结果经 OnScanResult 推回 Dart
    (void)filter; (void)android_use_fine_location;
  }

  void StopScan() override {
    // TODO: ble.stopBLEScan(...)
  }

  void Connect(const std::string& device_id) override {
    // TODO: GattClientDevice(device_id).connect(...)
  }

  void Disconnect(const std::string& device_id) override {
    // TODO: device.disconnect()
  }

  ConnectionState GetConnectionState(const std::string& device_id) override {
    // TODO: 查询并返回连接状态
    (void)device_id;
    return ConnectionState::kDisconnected;
  }

  std::vector<Service> DiscoverServices(const std::string& device_id) override {
    // TODO: device.getServices() / getCharacteristics()
    (void)device_id;
    return {};
  }

  std::vector<uint8_t> ReadValue(const std::string& device_id,
                                 const std::string& characteristic_id,
                                 const std::optional<std::string>& descriptor_id) override {
    // TODO: device.readCharacteristicValue(...)
    (void)device_id; (void)characteristic_id; (void)descriptor_id;
    return {};
  }

  void WriteValue(const std::string& device_id,
                  const std::string& characteristic_id,
                  const std::vector<uint8_t>& value,
                  WriteType write_type) override {
    // TODO: device.writeCharacteristicValue(..., write_type == withResponse)
    (void)device_id; (void)characteristic_id; (void)value; (void)write_type;
  }

  void SetNotifiable(const std::string& device_id,
                     const std::string& characteristic_id,
                     BleInputProperty property) override {
    // TODO: device.setCharacteristicChangeNotification(...) 订阅 notify/indicate
    (void)device_id; (void)characteristic_id; (void)property;
  }

  int64_t RequestMtu(const std::string& device_id, int64_t mtu) override {
    // TODO: device.setDeviceMtuSize(mtu)
    (void)device_id; (void)mtu;
    return 23;
  }

  void Pair(const std::string& device_id) override {
    // TODO: device.pair()
    (void)device_id;
  }

  bool IsPaired(const std::string& device_id) override {
    // TODO: 查询配对状态
    (void)device_id;
    return false;
  }

  int64_t GetRssi(const std::string& device_id) override {
    // TODO: device.getRssi()
    (void)device_id;
    return 0;
  }

  // ---- 事件回调：C++ 侧主动调用，把事件推回 Dart ----
  void PushScanResult(const ScanResult& r) { GetCallback()->OnScanResult(r); }
  void PushConnectionChanged(const std::string& device_id, ConnectionState s) {
    GetCallback()->OnConnectionChanged(device_id, s);
  }
  void PushValueChanged(const std::string& device_id, const std::string& characteristic_id,
                        const std::vector<uint8_t>& value) {
    GetCallback()->OnValueChanged(device_id, characteristic_id, value);
  }
};

}  // namespace universal_ble

// NAPI 注册入口（供 .ets 的 registerUniversalBleHost 调用）
extern "C" bool registerUniversalBleHost() {
  // 把 UniversalBleOhosHost 实例设置给 pigeon 生成的通道
  // UniversalBlePlatformChannel::SetUp(/*binaryMessenger*/, std::make_unique<UniversalBleOhosHost>());
  return true;
}
