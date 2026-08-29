// XiaomiLogin.ets — 小米账号 2FA 登录（ArkWeb）
// 小米 OAuth/2FA 需要 WebView。鸿蒙用 ArkWeb 内核（webview_flutter 的 ohos 适配版）。
// 注意 cookie 持久化行为差异：登录态需自行用 @ohos.web.webview 的 CookieManager 管理。
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'OronBox:XiaomiLogin';
const MI_AUTH_URL = 'https://account.xiaomi.com/oauth2/authorize?...'; // 按小米开放平台参数补齐

export class XiaomiLogin {
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    // 允许 JavaScript 与文件访问（按安全策略收紧）
    webview.WebviewController.setWebDebuggingAccess(true);
  }

  build(): void {
    // 实际组件请在页面中使用 <Web> 标签，这里仅给出控制器与回调逻辑
    this.controller.loadUrl(MI_AUTH_URL);
  }

  // 监听登录完成后回调 URL，提取 token
  onPageFinished(url: string): void {
    hilog.info(0x0000, TAG, 'page finished: %{public}s', url);
    if (url.includes('oronbox://auth-callback')) {
      const token = this.extractToken(url);
      hilog.info(0x0000, TAG, 'token captured');
      // TODO: 把 token 通过 MethodChannel / 全局状态交给 Dart 层
      void token;
    }
  }

  private extractToken(url: string): string {
    const m = url.match(/[?&]token=([^&]+)/);
    return m ? m[1] : '';
  }

  // 持久化 cookie（ArkWeb 与 flutter webview 的 cookie 可能不同源，需手动桥接）
  persistCookies(): void {
    try {
      const cm = webview.CookieManager.getInstance();
      cm.getCookieSync(MI_AUTH_URL, (cookie: string) => {
        hilog.info(0x0000, TAG, 'cookie: %{public}s', cookie);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, 'getCookie failed: %{public}s', JSON.stringify(e as BusinessError));
    }
  }
}
