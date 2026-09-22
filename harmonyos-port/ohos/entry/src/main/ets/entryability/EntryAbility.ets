// EntryAbility.ets — 应用入口，注册 universal_ble 的 NAPI 插件
// 参考实现：实际方法名/参数以你本地 CPF-Flutter 生成的 flutter_ohos 工程为准。
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { universalBleOhosPlugin } from '../../../universal_ble_ohos/ets/UniversalBleOhosPlugin';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'OronBox', '%{public}s', 'Ability onCreate');
    // 注册 BLE 平台通道（NAPI 加载 C++ Pigeon host）
    universalBleOhosPlugin.register();
  }

  onDestroy(): void {
    hilog.info(0x0000, 'OronBox', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'OronBox', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'OronBox', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'OronBox', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'OronBox', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'OronBox', '%{public}s', 'Ability onBackground');
  }
}
