import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import wantConstant from '@ohos.app.ability.wantConstant';
import fileUri from '@ohos.file.fileuri';
import fs from '@ohos.file.fs';

/**
 * OronBox 鸿蒙日志分享桥接（对应 Dart 侧 MethodChannel "oronbox/logs"）。
 *
 * Android 端该 channel 靠自建 DocumentsProvider + ACTION_SEND 分享日志文件，
 * 鸿蒙没有 DocumentsProvider 等价物（系统文件管理器访问不到应用沙箱目录），
 * 因此这里改用「沙箱文件 URI 授权 + 系统分享面板」：
 *   1. fileUri.getUriFromPath 把 filesDir/logs/<name> 转成可授权的 file:// URI；
 *   2. Want(action = ohos.want.action.sendData) + FLAG_AUTH_READ_URI_PERMISSION
 *      把读权限临时授予被拉起的应用，从而弹出系统分享面板。
 *
 * 支持的方法：
 *   share {name} → 分享指定日志文件（.log / .zip / .tar.gz），成功 true 失败 false
 *   open         → 鸿蒙沙箱下无法“打开日志文件夹”，固定返回 false
 *
 * Dart 侧日志目录 = getApplicationSupportDirectory()/logs，而鸿蒙 path_provider
 * 存根把 getApplicationSupportDirectory 映射到 context.filesDir，故此处拼接
 * `${filesDir}/logs/${name}` 即可命中。
 */

const TAG = 'OronBoxLogsBridge';
const LOGS_CHANNEL = 'oronbox/logs';
/** 日志子目录名，与 Dart 侧 initializeFileLogSink 保持一致。 */
const LOG_DIR = 'logs';
/** 系统分享面板 action。 */
const ACTION_SEND_DATA = 'ohos.want.action.sendData';
/** 回退 action：拉起“用其他应用打开”。 */
const ACTION_SEND_TO_DATA = 'ohos.want.action.sendToData';

export class LogsBridge {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, LOGS_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        try {
          switch (call.method) {
            case 'share':
              this.share(call, result);
              break;
            case 'open':
              // 鸿蒙沙箱模型：应用私有目录不对系统文件管理器开放，
              // “打开日志文件夹”在系统层面无对应能力，交由 Dart 侧决定 UI 呈现。
              result.success(false);
              break;
            default:
              result.notImplemented();
          }
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          console.error(TAG + ': ' + msg);
          result.error('logs_error', msg, null);
        }
      }
    });
  }

  /** 允许分享的文件名（与 Dart 侧 _isManagedLogFile 对齐，同时挡掉路径穿越）。 */
  private static isManagedName(name: string): boolean {
    if (name.length === 0) return false;
    if (name.indexOf('/') >= 0 || name.indexOf('\\') >= 0 || name.indexOf('..') >= 0) {
      return false;
    }
    return name.endsWith('.log') || name.endsWith('.zip') || name.endsWith('.tar.gz');
  }

  private share(call: MethodCall, result: MethodResult): void {
    const name: string = call.argument('name');
    if (name == null || !LogsBridge.isManagedName(name)) {
      result.error('LOG_NOT_FOUND', name, null);
      return;
    }
    const path = this.context.filesDir + '/' + LOG_DIR + '/' + name;
    let exists = false;
    try {
      exists = fs.accessSync(path);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(TAG + ': access failed for ' + path + ': ' + msg);
    }
    if (!exists) {
      result.error('LOG_NOT_FOUND', name, null);
      return;
    }

    let uri = '';
    try {
      uri = fileUri.getUriFromPath(path);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(TAG + ': getUriFromPath failed: ' + msg);
      result.success(false);
      return;
    }

    const isZip = name.endsWith('.zip');
    const mimeType = isZip ? 'application/zip' : 'text/plain';
    const want: Want = {
      action: ACTION_SEND_DATA,
      uri: uri,
      type: mimeType,
      flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
    };
    this.startShare(want, uri, mimeType, result);
  }

  /** 先试系统分享面板；设备无处理者时回退到“用其他应用打开”。 */
  private startShare(
    want: Want,
    uri: string,
    mimeType: string,
    result: MethodResult
  ): void {
    this.context.startAbility(want).then(() => {
      result.success(true);
    }).catch((e: Error) => {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn(TAG + ': sendData unavailable (' + msg + '), falling back to sendToData');
      const fallback: Want = {
        action: ACTION_SEND_TO_DATA,
        uri: uri,
        type: mimeType,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
      };
      this.context.startAbility(fallback).then(() => {
        result.success(true);
      }).catch((err: Error) => {
        const fallbackMsg = err instanceof Error ? err.message : String(err);
        console.error(TAG + ': share failed: ' + fallbackMsg);
        result.success(false);
      });
    });
  }
}
