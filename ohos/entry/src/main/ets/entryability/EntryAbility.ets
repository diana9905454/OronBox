
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { OronBoxStubPlugins } from '../plugins/StubPlugins';
import { OhosBleBridge } from '../plugins/OhosBleBridge';
import { BackgroundTasksBridge } from '../plugins/BackgroundTasksBridge';
import { OronBoxUrlLauncherStub } from '../plugins/UrlLauncherStub';
import { OronBoxAppLinksBridge } from '../plugins/AppLinksBridge';
import { ClassicSppBridge } from '../plugins/ClassicSppBridge';
import { FilePickerBridge } from '../plugins/FilePickerBridge';
import { MiAccountTwoFactorBridge } from '../plugins/MiAccountTwoFactorBridge';
import { ImageEncodeBridge } from '../plugins/ImageEncodeBridge';
import { LogsBridge } from '../plugins/LogsBridge';
import { FileOpenBridge } from '../plugins/FileOpenBridge';
import { PublicBackupsBridge } from '../plugins/PublicBackupsBridge';
import { SecureStorageBridge } from '../plugins/SecureStorageBridge';
import { WearableLogBridge } from '../plugins/WearableLogBridge';
import { QrScanBridge } from '../plugins/QrScanBridge';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';

export default class EntryAbility extends FlutterAbility {
  private appLinksBridge: OronBoxAppLinksBridge | null = null;
  private fileOpenBridge: FileOpenBridge | null = null;
  private bleBridge: OhosBleBridge | null = null;
  private sppBridge: ClassicSppBridge | null = null;
  private backgroundTasks: BackgroundTasksBridge | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 注册 OronBox 缺失插件的鸿蒙存根（path_provider / shared_preferences）。
    // OronBox 是桌面优先应用，这些插件在鸿蒙端无原生实现，Dart 侧启动时
    // 会因 channel 无 handler 而挂起（白屏）。这里提供最小实现让启动链路走通。
    new OronBoxStubPlugins(this.context).register(flutterEngine)
    // 注册鸿蒙 BLE 桥接（universal_ble 无鸿蒙实现，改用 @ohos.bluetooth.ble）。
    this.bleBridge = new OhosBleBridge(this.context);
    this.bleBridge.register(flutterEngine)
    this.backgroundTasks = new BackgroundTasksBridge(this.context);
    this.backgroundTasks.register(flutterEngine)
    // 注册 url_launcher 存根（无鸿蒙实现，用 startAbility 启动系统默认应用）。
    new OronBoxUrlLauncherStub(this.context).register(flutterEngine)
    // 注册 app_links 桥接（无鸿蒙实现，捕获 deep link 回调）。
    if (this.appLinksBridge == null) this.appLinksBridge = new OronBoxAppLinksBridge();
    this.appLinksBridge.register(flutterEngine)
    // 注册 classic_spp 桥接（经典蓝牙 RFCOMM/SPP，小米手环连接）。
    this.sppBridge = new ClassicSppBridge(this.context);
    this.sppBridge.register(flutterEngine)
    // 注册 file_picker 桥接（选图/选文件/保存，鸿蒙用 photoAccessHelper/picker）。
    new FilePickerBridge(this.context).register(flutterEngine)
    // 注册小米账号 2FA 桥接（ArkWeb WebView 完成短信/邮箱二次验证）。
    new MiAccountTwoFactorBridge(this.context).register(flutterEngine)
    // 注册图片编码桥接（WebP 编码用鸿蒙原生 ImagePacker，替代 wasm3 跑 libwebp）。
    new ImageEncodeBridge(this.context).register(flutterEngine)
    // 注册日志分享桥接（oronbox/logs：沙箱日志文件经系统分享面板导出）。
    new LogsBridge(this.context).register(flutterEngine)
    // 注册文件打开桥接（oronbox/file_open：文件管理器「其他应用打开」
    // 传入的 rpk/obp 等文件，复制进沙箱后交给 Dart 安装流程）。
    if (this.fileOpenBridge == null) {
      this.fileOpenBridge = new FileOpenBridge(this.context);
    }
    this.fileOpenBridge.register(flutterEngine)
    // 注册公共备份目录桥接（oronbox/public_backups：备份写入公共下载目录
    // OronBox/Backups，用户可在文件管理器里直接看到）。
    new PublicBackupsBridge(this.context).register(flutterEngine)
    // 注册安全存储桥接（plugins.it_nomads.com/flutter_secure_storage：
    // flutter_secure_storage 无鸿蒙实现，这里用 Asset Store Kit 落盘，
    // 否则 PrivateAppState 初始化失败会连带打断备份导出等流程）。
    new SecureStorageBridge().register(flutterEngine)
    // 注册小米运动健康日志导入桥接（oronbox/wearable_log：选日志 zip 后
    // 交给 Dart 解析 MAC/authkey，鸿蒙没有 Android 的目录授权语义）。
    new WearableLogBridge(this.context).register(flutterEngine)
    // 注册扫一扫桥接（oronbox/qr_scan：flutter_zxing 依赖 camera 插件，
    // 鸿蒙侧改调系统 Scan Kit 的扫码界面，返回原始字符串）。
    new QrScanBridge(this.context).register(flutterEngine)
  }

  /** 冷启动 onCreate 与热启动 onNewWant 共用的 Want 分流。 */
  private handleWant(want: Want): void {
    const uri = want?.uri;
    if (uri == null || uri.length === 0) return;
    if (uri.startsWith('file://')) {
      // 文件管理器「其他应用打开」：file:// URI（临时授权）。
      // onCreate 时 configureFlutterEngine 可能尚未执行，先建好桥接对象，
      // register() 时会补挂 channel，沙箱复制不依赖 channel。
      if (this.fileOpenBridge == null) {
        this.fileOpenBridge = new FileOpenBridge(this.context);
      }
      this.fileOpenBridge.onFileOpen(uri);
    } else {
      // deep link（浏览器授权回调 oronbox://...）。
      if (this.appLinksBridge == null) this.appLinksBridge = new OronBoxAppLinksBridge();
      this.appLinksBridge.onDeepLink(uri);
    }
  }

  onDestroy(): void {
    this.bleBridge?.dispose();
    this.sppBridge?.dispose();
    this.backgroundTasks?.dispose();
    this.bleBridge = null;
    this.sppBridge = null;
    this.backgroundTasks = null;
    super.onDestroy();
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam)
    this.handleWant(want)
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParams)
    this.handleWant(want)
  }
}
