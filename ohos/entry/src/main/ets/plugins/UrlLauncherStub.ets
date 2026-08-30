import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';

/**
 * OronBox 鸿蒙 url_launcher 存根。
 *
 * OronBox 用 url_launcher 插件在外部打开链接（GitHub 链接、社区资源、登录回调等），
 * 该插件在鸿蒙端无原生实现。本存根通过 UIAbilityContext.startAbility() 启动系统
 * 默认浏览器处理 http/https URL，从而替代插件的真实行为。
 *
 * MethodChannel "plugins.flutter.io/url_launcher" 支持的方法：
 *   canLaunch {url}         → 检查能否处理（http/https/mailto 等返回 true）
 *   launch   {url, ...}     → 用 startAbility 启动系统默认应用打开 URL
 *   closeWebView            → 鸿蒙无 WebView 概念，静默返回成功
 */

const TAG = 'OronBoxUrlLauncherStub';
const URL_LAUNCHER_CHANNEL = 'plugins.flutter.io/url_launcher';

/** 简易 scheme 判断：常见的可启动外部应用处理的 scheme。 */
function isLaunchableScheme(url: string): boolean {
  if (url == null || url.length === 0) return false;
  const lower = url.toLowerCase();
  return lower.startsWith('http://') ||
    lower.startsWith('https://') ||
    lower.startsWith('mailto:') ||
    lower.startsWith('tel:') ||
    lower.startsWith('sms:') ||
    lower.startsWith('maps:') ||
    lower.startsWith('geo:');
}

export class OronBoxUrlLauncherStub {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    this.registerChannel(messenger);
  }

  private registerChannel(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, URL_LAUNCHER_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        try {
          switch (call.method) {
            case 'canLaunch':
              this.canLaunch(call, result);
              break;
            case 'launch':
              this.launch(call, result);
              break;
            case 'closeWebView':
              // 鸿蒙无内嵌 WebView 概念（与 url_launcher 的 webview 模式无关），
              // 直接返回成功。
              result.success(null);
              break;
            default:
              result.notImplemented();
          }
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          result.error('url_launcher_error', msg, null);
        }
      }
    });
  }

  private canLaunch(call: MethodCall, result: MethodResult): void {
    const url: string = call.argument('url');
    const can = isLaunchableScheme(url);
    result.success(can);
  }

  private launch(call: MethodCall, result: MethodResult): void {
    const url: string = call.argument('url');
    if (!isLaunchableScheme(url)) {
      result.success(false);
      return;
    }
    // 用 Want + action 让系统打开 URL。viewData + uri 配合可以触发系统默认浏览器/邮件/拨号。
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url,
      entities: ['entity.system.browsable'],
    };
    try {
      this.context.startAbility(want).then(() => {
        result.success(true);
      }).catch((e: Error) => {
        const msg = e instanceof Error ? e.message : String(e);
        console.error(TAG + ': startAbility failed: ' + msg);
        result.success(false);
      });
    } catch (e) {
      // 启动失败（缺权限、没找到应用等），返回 false 让 Dart 端走 fallback 路径。
      const msg = e instanceof Error ? e.message : String(e);
      console.error(TAG + ': startAbility failed: ' + msg);
      result.success(false);
    }
  }
}
