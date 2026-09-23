
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { OronBoxStubPlugins } from '../plugins/StubPlugins';
import { OhosBleBridge } from '../plugins/OhosBleBridge';
import { OronBoxUrlLauncherStub } from '../plugins/UrlLauncherStub';
import { OronBoxAppLinksBridge } from '../plugins/AppLinksBridge';
import { ClassicSppBridge } from '../plugins/ClassicSppBridge';
import { FilePickerBridge } from '../plugins/FilePickerBridge';
import { MiAccountTwoFactorBridge } from '../plugins/MiAccountTwoFactorBridge';
import { ImageEncodeBridge } from '../plugins/ImageEncodeBridge';
import { LogsBridge } from '../plugins/LogsBridge';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';

export default class EntryAbility extends FlutterAbility {
  private appLinksBridge: OronBoxAppLinksBridge | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 注册 OronBox 缺失插件的鸿蒙存根（path_provider / shared_preferences）。
    // OronBox 是桌面优先应用，这些插件在鸿蒙端无原生实现，Dart 侧启动时
    // 会因 channel 无 handler 而挂起（白屏）。这里提供最小实现让启动链路走通。
    new OronBoxStubPlugins(this.context).register(flutterEngine)
    // 注册鸿蒙 BLE 桥接（universal_ble 无鸿蒙实现，改用 @ohos.bluetooth.ble）。
    new OhosBleBridge(this.context).register(flutterEngine)
    // 注册 url_launcher 存根（无鸿蒙实现，用 startAbility 启动系统默认应用）。
    new OronBoxUrlLauncherStub(this.context).register(flutterEngine)
    // 注册 app_links 桥接（无鸿蒙实现，捕获 deep link 回调）。
    const appLinks = new OronBoxAppLinksBridge();
    this.appLinksBridge = appLinks;
    appLinks.register(flutterEngine)
    // 注册 classic_spp 桥接（经典蓝牙 RFCOMM/SPP，小米手环连接）。
    new ClassicSppBridge(this.context).register(flutterEngine)
    // 注册 file_picker 桥接（选图/选文件/保存，鸿蒙用 photoAccessHelper/picker）。
    new FilePickerBridge(this.context).register(flutterEngine)
    // 注册小米账号 2FA 桥接（ArkWeb WebView 完成短信/邮箱二次验证）。
    new MiAccountTwoFactorBridge(this.context).register(flutterEngine)
    // 注册图片编码桥接（WebP 编码用鸿蒙原生 ImagePacker，替代 wasm3 跑 libwebp）。
    new ImageEncodeBridge(this.context).register(flutterEngine)
    // 注册日志分享桥接（oronbox/logs：沙箱日志文件经系统分享面板导出）。
    new LogsBridge(this.context).register(flutterEngine)
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam)
    // 捕获启动时携带的 deep link（如 oronbox://oauth/bandbbs?code=...）。
    const uri = want?.uri;
    if (uri != null && uri.length > 0) {
      this.appLinksBridge?.onDeepLink(uri);
    }
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParams)
    // 捕获运行时 deep link（浏览器授权后回调）。
    const uri = want?.uri;
    if (uri != null && uri.length > 0) {
      this.appLinksBridge?.onDeepLink(uri);
    }
  }
}
