import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

/**
 * OronBox 鸿蒙存根插件。
 *
 * OronBox 本是一个桌面优先的 Flutter 应用，依赖大量 desktop/mobile 专用插件，
 * 而这些插件在鸿蒙 fork (flutter_ohos) 中没有原生实现，导致 GeneratedPluginRegistrant
 * 为空、Dart 侧调用这些插件时 channel 无 handler 而永久挂起（白屏）。
 *
 * 本文件在鸿蒙端实现两个最关键的启动链路插件的最小存根：
 *   1. path_provider    —— 返回应用沙箱目录路径
 *   2. shared_preferences —— 用 JSON 文件持久化到应用 filesDir
 *
 * 其余插件（window_manager / tray_manager / url_launcher 等）在真正用到时再逐个补。
 */

const TAG = 'OronBoxStubPlugins';

/** path_provider 的 channel 名（与 Dart 侧 path_provider_platform_interface 一致）。 */
const PATH_PROVIDER_CHANNEL = 'plugins.flutter.io/path_provider';
/** shared_preferences 的 channel 名（与 Dart 侧 method_channel_shared_preferences 一致）。 */
const SHARED_PREFS_CHANNEL = 'plugins.flutter.io/shared_preferences';
/** shared_preferences 持久化文件名。 */
const SHARED_PREFS_FILE = 'oronbox_shared_prefs.json';

export class OronBoxStubPlugins {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /** 注册所有存根 channel。 */
  register(flutterEngine: FlutterEngine): void {
    const messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    this.registerPathProvider(messenger);
    this.registerSharedPreferences(messenger);
  }

  // ---------------------------------------------------------------------------
  // path_provider
  // ---------------------------------------------------------------------------
  private registerPathProvider(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, PATH_PROVIDER_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        try {
          switch (call.method) {
            case 'getTemporaryDirectory':
              result.success(this.context.tempDir);
              break;
            case 'getApplicationSupportDirectory':
              result.success(this.context.filesDir);
              break;
            case 'getApplicationDocumentsDirectory':
              result.success(this.context.filesDir);
              break;
            case 'getApplicationCacheDirectory':
              result.success(this.context.cacheDir);
              break;
            default:
              result.notImplemented();
          }
        } catch (e) {
          result.error('path_provider_error', e instanceof Error ? e.message : String(e), null);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // shared_preferences
  // ---------------------------------------------------------------------------
  private prefsFilePath(): string {
    return this.context.filesDir + '/' + SHARED_PREFS_FILE;
  }

  private readPrefsMap(): Map<string, Object> {
    const map = new Map<string, Object>();
    const path = this.prefsFilePath();
    try {
      if (!fs.accessSync(path)) {
        return map;
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text = this.bufToString(buf);
      if (text.length === 0) {
        return map;
      }
      const obj = JSON.parse(text) as Record<string, Object>;
      for (const key of Object.keys(obj)) {
        map.set(key, obj[key]);
      }
    } catch (e) {
      console.error(TAG + ': readPrefsMap failed: ' + JSON.stringify(e));
    }
    return map;
  }

  private writePrefsMap(map: Map<string, Object>): void {
    const obj: Record<string, Object> = {};
    map.forEach((value, key) => {
      obj[key] = value;
    });
    const path = this.prefsFilePath();
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(obj));
      fs.closeSync(file);
    } catch (e) {
      console.error(TAG + ': writePrefsMap failed: ' + JSON.stringify(e));
    }
  }

  private bufToString(buf: ArrayBuffer): string {
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buf));
  }

  private registerSharedPreferences(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, SHARED_PREFS_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        try {
          const map = this.readPrefsMap();
          switch (call.method) {
            case 'getAll':
            case 'getAllWithParameters':
              const obj: Record<string, Object> = {};
              map.forEach((value, key) => { obj[key] = value; });
              result.success(obj);
              break;
            case 'setString':
            case 'setBool':
            case 'setInt':
            case 'setDouble':
            case 'setStringList': {
              const key: string = call.argument('key');
              const value: Object = call.argument('value');
              map.set(key, value);
              this.writePrefsMap(map);
              result.success(true);
              break;
            }
            case 'remove': {
              const key: string = call.argument('key');
              map.delete(key);
              this.writePrefsMap(map);
              result.success(true);
              break;
            }
            case 'clear':
            case 'clearWithParameters':
              map.clear();
              this.writePrefsMap(map);
              result.success(true);
              break;
            default:
              result.notImplemented();
          }
        } catch (e) {
          result.error('shared_preferences_error', e instanceof Error ? e.message : String(e), null);
        }
      }
    });
  }
}
