import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * OronBox 鸿蒙小米账号二次验证（2FA）桥接层。
 *
 * Dart 端 NativeMiAccountTwoFactorResolver（oronbox/mi_account_2fa channel）
 * 登录小米账号后若响应带 notificationUrl，会调 resolve 方法，期望返回形如
 * `passToken=xxx; userId=xxx; cUserId=xxx` 的 cookieHeader。
 *
 * 鸿蒙端用 ArkWeb 的 <Web> 组件全屏加载小米 2FA 页面，轮询 WebCookieManager
 * 提取 cookie，命中 passToken/cUserId/userId 任一即视为验证完成。
 *
 * 流程：resolve → 保存 pendingResult → router.pushUrl 跳 TwoFactorPage →
 *       page 轮询命中 → 全局单例 complete() 回填 result → router.back()。
 */

const TAG = 'OronBoxMiAccountTwoFactorBridge';
const DOMAIN = 0x0000;

const CHANNEL = 'oronbox/mi_account_2fa';

/** 传给 TwoFactorPage 的路由参数。 */
export interface TwoFactorRouteParams {
  url: string;
}

/** 全局单例：TwoFactorPage 完成后回填结果给 Bridge。 */
let activeInstance: MiAccountTwoFactorBridge | null = null;

/**
 * TwoFactorPage 侧调用：验证完成（有 cookie）时回填。
 * 必须在 ArkTS 顶层通过导出的函数访问，page 不直接持 Bridge 实例（避免跨 page 引用）。
 */
export function completeTwoFactor(cookieHeader: string): void {
  const inst = activeInstance;
  if (inst != null) {
    inst.onCompleted(cookieHeader);
  }
}

/** TwoFactorPage 侧调用：用户取消 / 关闭 / 超时。 */
export function cancelTwoFactor(reason: string): void {
  const inst = activeInstance;
  if (inst != null) {
    inst.onCancelled(reason);
  }
}

export class MiAccountTwoFactorBridge {
  private context: common.UIAbilityContext;
  private pendingResult: MethodResult | null = null;
  private settled: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handle(call, result);
      }
    });
  }

  private handle(call: MethodCall, result: MethodResult): void {
    try {
      if (call.method === 'resolve') {
        this.resolve(call, result);
      } else {
        result.notImplemented();
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('mi_2fa_error', msg, null);
    }
  }

  private resolve(call: MethodCall, result: MethodResult): void {
    const url: string = call.argument('url');
    if (url == null || url.length === 0) {
      result.error('INVALID_ARGUMENT', 'url is required', null);
      return;
    }

    // 若已有未完成的验证会话，先拒绝旧的。
    if (this.pendingResult != null) {
      this.finishError('SUPERSEDED', 'A previous 2FA session is still active');
    }

    this.pendingResult = result;
    this.settled = false;
    activeInstance = this;

    // 通过路由参数把 url 传给 TwoFactorPage。
    const params: TwoFactorRouteParams = { url: url };
    const options: router.RouterOptions = { url: 'pages/TwoFactorPage', params: params };
    router.pushUrl(options)
      .then(() => {
        hilog.info(DOMAIN, TAG, 'TwoFactorPage opened');
      })
      .catch((e: Error) => {
        hilog.error(DOMAIN, TAG, 'pushUrl failed: ' + JSON.stringify(e));
        this.finishError('NAVIGATION_FAILED', e instanceof Error ? e.message : String(e));
      });
  }

  /** TwoFactorPage 验证成功回填。 */
  onCompleted(cookieHeader: string): void {
    this.finishSuccess(cookieHeader);
  }

  /** TwoFactorPage 取消/超时回填。 */
  onCancelled(reason: string): void {
    this.finishError('CANCELLED', reason);
  }

  private finishSuccess(cookieHeader: string): void {
    if (this.settled) return;
    this.settled = true;
    const r = this.pendingResult;
    this.pendingResult = null;
    if (activeInstance === this) {
      activeInstance = null;
    }
    if (r != null) {
      r.success(cookieHeader);
    }
  }

  private finishError(code: string, message: string): void {
    if (this.settled) return;
    this.settled = true;
    const r = this.pendingResult;
    this.pendingResult = null;
    if (activeInstance === this) {
      activeInstance = null;
    }
    if (r != null) {
      r.error(code, message, null);
    }
  }
}
