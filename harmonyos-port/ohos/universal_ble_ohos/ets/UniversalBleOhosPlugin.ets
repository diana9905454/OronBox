// UniversalBleOhosPlugin.ets — NAPI 加载器
// 真正的 BLE 逻辑在 C++ Pigeon host（universal_ble_ohos_host.cpp）里。
// 这里只负责把 .so 加载进来并触发注册。
import { hilog } from '@kit.PerformanceAnalysisKit';
import native from 'libuniversal_ble_ohos.so'; // 由 CMake 产物提供

export class UniversalBleOhosPlugin {
  private static registered = false;

  static register(): void {
    if (UniversalBleOhosPlugin.registered) {
      return;
    }
    try {
      // 调用 C++ 侧导出的注册函数（函数名需与 cpp 中 napi_module / 注册宏一致）
      const ok = (native as unknown as { registerUniversalBleHost?: () => boolean }).registerUniversalBleHost?.();
      UniversalBleOhosPlugin.registered = ok !== false;
      hilog.info(0x0000, 'OronBox', 'UniversalBleOhosPlugin registered=%{public}s', String(UniversalBleOhosPlugin.registered));
    } catch (e) {
      hilog.error(0x0000, 'OronBox', 'UniversalBleOhosPlugin register failed: %{public}s', JSON.stringify(e));
    }
  }
}

export const universalBleOhosPlugin = new UniversalBleOhosPlugin();
