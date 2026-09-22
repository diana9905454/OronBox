import { FlutterEngine, MethodChannel, MethodCall, MethodResult, EventChannel, StreamHandler, EventSink, BinaryMessenger } from '@ohos/flutter_ohos';

/**
 * OronBox 鸿蒙 app_links 桥接层。
 *
 * OronBox 用 app_links 插件监听 deep link（米坛 OAuth 登录回调 oronbox://oauth/bandbbs），
 * 该插件在鸿蒙端无原生实现。本文件实现：
 *   - MethodChannel "com.llfbandit.app_links/messages"：getInitialLink / getLatestLink
 *   - EventChannel   "com.llfbandit.app_links/events"：运行时 deep link 事件流
 *
 * EntryAbility 在 onCreate/onNewWant 捕获 want.uri 后调用 onDeepLink() 注入。
 */

const TAG = 'OronBoxAppLinksBridge';

const APP_LINKS_METHOD_CHANNEL = 'com.llfbandit.app_links/messages';
const APP_LINKS_EVENT_CHANNEL = 'com.llfbandit.app_links/events';

export class OronBoxAppLinksBridge {
  private initialLink: string | null = null;
  private latestLink: string | null = null;
  private eventSink: EventSink | null = null;

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    this.registerMethodChannel(messenger);
    this.registerEventChannel(messenger);
  }

  /** EntryAbility 调用：注入一个 deep link（启动时或运行时）。 */
  onDeepLink(uri: string | null): void {
    if (uri == null || uri.length === 0) return;
    this.latestLink = uri;
    if (this.initialLink == null) {
      this.initialLink = uri;
    }
    // 推送给 Dart 端的事件流。
    const sink = this.eventSink;
    if (sink != null) {
      try {
        sink.success(uri);
      } catch (e) {
        console.error(TAG + ': event push failed: ' + JSON.stringify(e));
      }
    }
  }

  private registerMethodChannel(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, APP_LINKS_METHOD_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        try {
          switch (call.method) {
            case 'getInitialLink':
              result.success(this.initialLink);
              break;
            case 'getLatestLink':
              result.success(this.latestLink);
              break;
            default:
              result.notImplemented();
          }
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          result.error('app_links_error', msg, null);
        }
      }
    });
  }

  private registerEventChannel(messenger: BinaryMessenger): void {
    const channel = new EventChannel(messenger, APP_LINKS_EVENT_CHANNEL);
    const handler: StreamHandler = {
      onListen: (args: Object | null, events: EventSink): void => {
        this.eventSink = events;
        // 启动时若有初始 link，立即推送一次。
        if (this.initialLink != null) {
          try {
            events.success(this.initialLink);
          } catch (e) {
            console.error(TAG + ': initial link push failed: ' + JSON.stringify(e));
          }
        }
      },
      onCancel: (args: Object | null): void => {
        this.eventSink = null;
      }
    };
    channel.setStreamHandler(handler);
  }
}
