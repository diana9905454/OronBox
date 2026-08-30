import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { completeTwoFactor, cancelTwoFactor, TwoFactorRouteParams } from '../plugins/MiAccountTwoFactorBridge';

/**
 * 小米账号二次验证（2FA）页面。
 *
 * 由 MiAccountTwoFactorBridge.resolve() 通过 router.pushUrl 打开，
 * 路由参数 { url } 指向小米 2FA 通知链接。页面用 ArkWeb <Web> 全屏加载，
 * 轮询 WebCookieManager 提取 cookie，命中 passToken/cUserId/userId 任一
 * 即回填给 Bridge 并返回上一页。
 */

const TAG = 'OronBoxTwoFactorPage';
const DOMAIN = 0x0000;

/** 轮询间隔（ms），对齐 Android 参考实现的 750ms。 */
const POLL_INTERVAL_MS = 750;
/** 5 分钟超时保护。 */
const TIMEOUT_MS = 5 * 60 * 1000;

/** 提取 cookie 的目标域名（对齐 Android 实现）。 */
const COOKIE_DOMAINS: Array<string> = [
  'https://account.xiaomi.com',
  'https://mi.com',
  'https://xiaomi.com',
];

@Entry
@Component
struct TwoFactorPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  private url: string = '';
  private pollTimer: number = -1;
  private timeoutTimer: number = -1;
  private completed: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as TwoFactorRouteParams;
    if (params != null && params.url != null) {
      this.url = params.url;
    }
    hilog.info(DOMAIN, TAG, 'aboutToAppear url=%{public}s', this.url);
    // 启动轮询与超时保护。
    this.pollTimer = setInterval(() => {
      this.pollCookie();
    }, POLL_INTERVAL_MS);
    this.timeoutTimer = setTimeout(() => {
      this.onTimeout();
    }, TIMEOUT_MS);
  }

  aboutToDisappear(): void {
    this.stopTimers();
    // 页面因非正常原因消失（未完成验证），视为取消。
    if (!this.completed) {
      cancelTwoFactor('Xiaomi 2FA page was closed before completion');
    }
  }

  private stopTimers(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    if (this.timeoutTimer !== -1) {
      clearTimeout(this.timeoutTimer);
      this.timeoutTimer = -1;
    }
  }

  private pollCookie(): void {
    if (this.completed) return;
    const header = this.cookieHeader();
    if (!this.hasSessionCookie(header)) return;
    this.complete(header);
  }

  /** 聚合多个域名 + 当前 url 的 cookie 为 `name=value; ...` 字符串（去重）。 */
  private cookieHeader(): string {
    const values = new Map<string, string>();
    const urls: Array<string> = [this.url, ...COOKIE_DOMAINS];
    for (const u of urls) {
      if (u == null || u.length === 0) continue;
      let raw = '';
      try {
        raw = webview.WebCookieManager.fetchCookieSync(u);
      } catch (e) {
        // 无 cookie 时会抛 17100002，忽略。
        continue;
      }
      if (raw == null || raw.length === 0) continue;
      const parts = raw.split(';');
      for (const p of parts) {
        const pair = p.trim();
        if (pair.length === 0) continue;
        const idx = pair.indexOf('=');
        if (idx <= 0) continue;
        const name = pair.substring(0, idx).trim();
        const value = pair.substring(idx + 1).trim();
        if (name.length > 0 && value.length > 0) {
          values.set(name, value);
        }
      }
    }
    let out = '';
    values.forEach((v, k) => {
      if (out.length > 0) out += '; ';
      out += k + '=' + v;
    });
    return out;
  }

  private hasSessionCookie(header: string): boolean {
    if (header == null || header.length === 0) return false;
    const names = new Set<string>();
    const parts = header.split(';');
    for (const p of parts) {
      const pair = p.trim();
      if (pair.length === 0) continue;
      const idx = pair.indexOf('=');
      if (idx <= 0) continue;
      names.add(pair.substring(0, idx).trim());
    }
    return names.has('passToken') || names.has('cUserId') || names.has('userId');
  }

  private complete(cookieHeader: string): void {
    if (this.completed) return;
    this.completed = true;
    this.stopTimers();
    hilog.info(DOMAIN, TAG, '2FA completed');
    completeTwoFactor(cookieHeader);
    router.back();
  }

  private onTimeout(): void {
    if (this.completed) return;
    this.completed = true;
    this.stopTimers();
    cancelTwoFactor('Xiaomi 2FA timed out');
    router.back();
  }

  private onCancelTap(): void {
    if (this.completed) return;
    this.completed = true;
    this.stopTimers();
    cancelTwoFactor('Xiaomi 2FA cancelled by user');
    router.back();
  }

  build() {
    Column() {
      // 顶部工具条：标题 + 关闭按钮。
      Row() {
        Text('小米账号二次验证')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
        Button('取消')
          .fontSize(15)
          .fontColor('#0A59F7')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.onCancelTap();
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F7F7F7')

      // WebView 主体。
      Web({ src: this.url, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .width('100%')
        .layoutWeight(1)
        .onPageEnd((event) => {
          if (event == null) return;
          const endedUrl = event.url;
          hilog.info(DOMAIN, TAG, 'onPageEnd %{public}s', endedUrl ?? '');
          // 页面加载完成立即检查一次，加快命中。
          this.pollCookie();
        })
    }
    .width('100%')
    .height('100%')
  }
}
