# OronBox 鸿蒙版 — 交接文档（2026-08-30 22:15）

> 给接手 AI 的自包含交接说明。目标是：让下一个 AI 无需翻历史对话就能继续推进。

---

## 0. 一句话现状

OronBox（小米手环工具）的 HarmonyOS fork 已能编译出可安装的签名版 HAP，版本号 1.1.3 对齐上游。当前唯一未完成的实质功能是**小米账号二次验证（2FA）的鸿蒙端 WebView 实现**——用户已拍板采用「完整 ArkWeb WebView 方案」，但代码还没写完。

---

## 1. 项目位置与环境

| 项 | 值 |
|---|---|
| 项目根目录 | `C:\Users\Administrator\OronBox` |
| 上游 | `zxor-org/OronBox`（v1.1.3 = commit `26dd89e`） |
| 用户 fork | `diana9905454/OronBox` |
| 当前分支 | `feat/harmonyos-ohos-port`（HEAD = `1243539`） |
| Flutter SDK | `C:\Users\Administrator\flutter_ohos\flutter_flutter`（ohos fork，Dart 3.12.2，framework 3.41.9） |
| DevEco Studio | `C:\Program Files\Huawei\DevEco Studio` |
| 鸿蒙 SDK | `C:\Program Files\Huawei\DevEco Studio\sdk`（API 24） |
| hvigorw | `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat` |
| ohpm | `C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm` |
| DevEco 自带 Node 18 | `C:\Program Files\Huawei\DevEco Studio\tools\node`（**构建必须用它**） |
| hdc | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe` |
| 测试手机 | PSN-AL00（HarmonyOS 7.0），网络调试曾用 `192.168.31.199:42033`（当前已掉线） |

**重要**：项目根目录是 `C:\Users\Administrator\OronBox`，**不是** WorkBuddy 工作区路径 `C:\Users\Administrator\WorkBuddy\2026-08-29-22-47-41`（后者只是 AI 会话的元数据目录，别混淆）。

---

## 2. Git 状态（重要，接手先看这个）

当前 `git status` 有两类改动：

**已暂存（staged，来自「特别感谢」功能，用户说过"先不发"所以还没 commit）：**
```
A  assets/images/team/diana.jpg
M  lib/src/app/generated/app_localizations{,_en,_ja,_ru,_zh}.dart   (5 个生成文件)
M  lib/src/app/l10n/app_{en,ja,ru,zh}.arb                            (4 个 ARB)
M  lib/src/core/constants/app_constants.dart
M  lib/src/features/settings/pages/about_software_page.dart
M  ohos/entry/src/main/ets/plugins/UrlLauncherStub.ets
```

**未暂存（unstaged，2FA 相关，刚改）：**
```
M  lib/src/features/accounts/services/mi_account_two_factor_resolver_io.dart
```

**未跟踪（untracked）：**
```
上架清单-鸿蒙激励计划.md   (之前的华为上架文档，与 2FA 无关，别动)
```

**⚠️ 关键坑：长分支名写 ref 会静默失败。** PortableGit 下 `refs/heads/feat/harmonyos-ohos-port` 是长名（含 `/`），`git commit` 会创建 commit 对象但**分支指针不前进**（写 loose ref 静默失败）。之前一次 commit（`6a42ba7`）就因此变成悬空 commit，分支仍停在 `1243539`。所以：
- 提交前先确认 `git rev-parse HEAD` 是否真的前进了；
- 若 ref 没更新，需手动改 `.git/packed-refs`（或先 `git pack-refs --all` 再直接编辑）。

---

## 3. 本次会话已完成的工作

1. **「特别感谢」UI 功能**（代码已写好，已 staged，未 commit/推送）：
   - `app_constants.dart`：`TeamRole` 枚举加 `harmonyAdaptation`；新增 `specialThanks` 列表（Diana + 头像 `assets/images/team/diana.jpg`）。
   - `about_software_page.dart`：`_teamRoleLabel` switch 加 `harmonyAdaptation`；开发团队下方隔开一行新增「特别感谢」分区。
   - 4 个 ARB 加 `settingsSpecialThanks` / `settingsTeamRoleHarmony`。
   - 头像图片已从用户提供复制到 `assets/images/team/diana.jpg`。
2. **版本号修复**：构建时注入 `--dart-define=APP_VERSION=1.1.3`（否则软件内显示 1.0.0-rc.1）。
3. **web 链接修复**：`UrlLauncherStub.ets` 补 `entities: ['entity.system.browsable']` + promise 化 startAbility。
4. **构建产物**：桌面 `C:\Users\Administrator\Desktop\OronBox-1.1.3-特别感谢.hap`（签名版，39MB，含 wasm3 原生库）。

---

## 4. 当前卡点：小米账号 2FA WebView（已实现，待端到端实测）

> **状态更新（2026-08-30 22:50）**：2FA 鸿蒙端已完整实现并编译通过、签名 HAP 已装到手机（PSN-AL00，端口 36691）且启动无崩溃。**唯一剩余**：用户在手机上实际登录小米账号触发 2FA，确认 WebView 弹出 + 验证后 token 回填成功。

### 4.0 已实现内容（本次会话新增）

新增 3 处改动 + 1 处注册，全部已编译进签名 HAP：

1. **`ohos/entry/src/main/ets/plugins/MiAccountTwoFactorBridge.ets`（新建）**
   - MethodChannel `oronbox/mi_account_2fa` 处理 `resolve`（参数 `url`）。
   - 保存 `pendingResult` → `router.pushUrl('pages/TwoFactorPage', {url})`。
   - 导出全局单例函数 `completeTwoFactor(cookieHeader)` / `cancelTwoFactor(reason)` 供 page 回填。
   - 防并发：已有未完成会话时先 `SUPERSEDED` 拒绝旧的。
2. **`ohos/entry/src/main/ets/pages/TwoFactorPage.ets`（新建）**
   - 独立 page（方案 B），顶部「取消」按钮 + 全屏 `Web` 组件。
   - `javaScriptAccess(true)` + `domStorageAccess(true)`。
   - `setInterval` 750ms 轮询 + `onPageEnd` 即时检查，聚合 `currentUrl + account.xiaomi.com + mi.com + xiaomi.com` 四域 cookie。
   - 命中 `passToken`/`cUserId`/`userId` 任一 → `completeTwoFactor` → `router.back()`。
   - 5 分钟超时、用户取消、页面异常消失均回填 `CANCELLED`。
3. **`main_pages.json`** 注册 `pages/TwoFactorPage`；**`EntryAbility.ets`** 注册 bridge。

**⚠️ 关键技术坑（接手必知）**：SDK API 24 里 `XiaomiLogin.ets` 示例写的 `webview.CookieManager.getInstance().getCookieSync(url, cb)` **已过时**。实际类名是 `webview.WebCookieManager`，方法为：
- `WebCookieManager.fetchCookieSync(url): string`（同步，无 cookie 会抛 BusinessError 17100002，需 try/catch）
- `WebCookieManager.clearAllCookiesSync()` / `clearSessionCookieSync()`
- `WebCookieManager.configCookieSync(url, value)`

### 4.1 问题现象
用户截图：登录小米账号后弹错「小米账号二次验证未完成，请重新登录」。预期行为是点登录后应弹出一个**内嵌 WebView** 完成短信/邮箱二次验证，但鸿蒙端什么都没弹。

### 4.2 根因（已定位）
鸿蒙端**没有实现** `oronbox/mi_account_2fa` MethodChannel 的原生 handler，导致 Dart 端回退到 `UnsupportedIoMiAccountTwoFactorResolver`，抛 `UnsupportedError`，被 `error_localization.dart` 翻译成"二次验证未完成"。

### 4.3 用户决策
已通过 AskUserQuestion 确认：采用**完整 ArkWeb WebView 方案**（不是外部浏览器 fallback，也不是禁用 2FA）。

### 4.4 完整代码链路（接手必读）

**Dart 端流程：**
1. 用户点登录 → `settings_page.dart` / `oobe_page.dart` 的登录按钮逻辑。
2. 登录时 `mi_account_service.dart` 的 `login()` / `refreshToken()` / `_finishLogin()` 检测到响应含 `notificationUrl` 时抛 `MiAccountTwoFactorRequired(url, deviceId)`。
3. 上层（`settings_page.dart` 约 751-765 行）catch 后：
   ```dart
   final cookieHeader = await createMiAccountTwoFactorResolver()
       .resolve(rootContext, Uri.parse(e.url));
   final account = await ref.read(hostAccountsProvider.notifier)
       .completeXiaomiTwoFactor(challenge: e, cookieHeader: cookieHeader);
   ```
4. `resolve()` 最终调用 `MethodChannel('oronbox/mi_account_2fa').invokeMethod('resolve', {'url': ...})`，返回 `cookieHeader`（形如 `passToken=xxx; userId=xxx; cUserId=xxx`）。
5. `mi_account_service.dart` 的 `completeTwoFactorLogin()` 用这个 cookieHeader 重跑 serviceLogin → STS，完成登录。

**平台分流（关键文件）：**
- `lib/src/features/accounts/services/mi_account_two_factor_resolver.dart` —— 条件导入：`dart.library.io` → `_io.dart`，`dart.library.html` → `_web.dart`，默认 → `_stub.dart`。
- `_io.dart` 里 `createPlatformMiAccountTwoFactorResolver()`：只有 `Platform.isAndroid/Linux/MacOS/Windows` 才返回 `NativeMiAccountTwoFactorResolver`（走 MethodChannel），否则返回 `UnsupportedIoMiAccountTwoFactorResolver`（抛错）。
- **我已经改了 `_io.dart`**（本次会话，未提交）：加了 `defaultTargetPlatform == TargetPlatform.ohos` 判断，让鸿蒙走 `NativeMiAccountTwoFactorResolver`。这条改动是对的，保留。

**Android 参考实现（鸿蒙端照抄逻辑）：**
- 文件：`android/app/src/main/kotlin/org/zxor/oronbox/MainActivity.kt`，方法 `resolveMiAccountTwoFactor`（约 1130-1282 行）。
- 逻辑：Dialog 内嵌 WebView 加载 url → CookieManager 每 750ms 轮询 cookie → 命中 `passToken`/`cUserId`/`userId` 任一即视为成功 → 把 cookie 序列化成 `name=value; ...` 字符串返回。
- cookie 来源域名：`https://account.xiaomi.com`、`https://mi.com`、`https://xiaomi.com`（Android 代码里还带 currentUrl 动态域名）。

**鸿蒙 ArkWeb 参考（项目里已有半成品示例）：**
- 文件：`ohos/universal_ble_ohos/ets/XiaomiLogin.ets`（这是之前会话留下的示例，展示了正确的导入和 API）：
  ```typescript
  import { webview } from '@kit.ArkWeb';
  webview.WebviewController   // 控制器
  controller.loadUrl(url)
  webview.CookieManager.getInstance().getCookieSync(url, (cookie) => {...})  // 注意是 callback 形式
  ```
- ⚠️ 注意：`getCookieSync` 名字带 Sync 但实际传 callback，是异步的。

### 4.5 鸿蒙端需要做什么（具体步骤）

1. **新建** `ohos/entry/src/main/ets/plugins/MiAccountTwoFactorBridge.ets`：
   - 参考 `OhosBleBridge.ets` 的 `register(flutterEngine)` 模式（见下）。
   - MethodChannel 名 `oronbox/mi_account_2fa`，处理 `resolve` 方法，参数 `url`。
   - 用 `@kit.ArkWeb` 的 `WebviewController` + `<Web>` 组件全屏加载 url。
   - 轮询 `webview.CookieManager` 提取 cookie，命中 `passToken`/`cUserId`/`userId` 返回成功。
   - 用户取消/关闭弹窗时 `result.error('CANCELLED', ...)`。
   - 5 分钟超时保护。
   - （我写过一版草稿但有 bug，已删除。关键坑：回调闭包要正确存下来，别像我之前 `pendingCallback` 忘了赋值；`ComponentContent`/`promptAction.openCustomDialog` 的 API 要实测。）

2. **注册** 到 `ohos/entry/src/main/ets/entryability/EntryAbility.ets` 的 `configureFlutterEngine`：
   ```typescript
   import { MiAccountTwoFactorBridge } from '../plugins/MiAccountTwoFactorBridge';
   new MiAccountTwoFactorBridge(this.context).register(flutterEngine);
   ```
   （现有 bridge 注册都在这个文件，照抄模式即可。）

3. **UI 实现方式二选一**（推荐先试 ComponentContent，失败再上独立 page）：
   - **方案 A**：`promptAction.openCustomDialog` + `ComponentContent` + `wrapBuilder`，全屏覆盖显示 `<Web>`。参考 `XiaomiLogin.ets` 的 controller 用法。
   - **方案 B**：新建独立 page（`ohos/entry/src/main/ets/pages/TwoFactorPage.ets` + 在 `main_pages.json` 注册路由），用 `router.pushUrl` 跳转，page 内放 `<Web>`，完成时 `router.back()` 并用全局单例/EventHub 回传结果。这个更稳，但要多改 main_pages.json。

4. **Cookie 提取**：ArkWeb 的 `CookieManager.getInstance().getCookieSync(url, cb)` 是异步 callback，注意聚合多个域名去重。完成判定复用 Android 的 `hasSessionCookie` 逻辑（`passToken`/`cUserId`/`userId` 任一存在）。

5. **验证**：装到手机，登录小米账号触发 2FA，确认弹出 WebView 且能完成验证回填 token。

### 4.6 参考文件路径速查
| 用途 | 路径 |
|---|---|
| Dart 平台分流 | `lib/src/features/accounts/services/mi_account_two_factor_resolver_io.dart` |
| Dart 条件导入 | `lib/src/features/accounts/services/mi_account_two_factor_resolver.dart` |
| Android 参考实现 | `android/app/src/main/kotlin/org/zxor/oronbox/MainActivity.kt`（`resolveMiAccountTwoFactor`） |
| 鸿蒙 ArkWeb 示例 | `ohos/universal_ble_ohos/ets/XiaomiLogin.ets` |
| bridge 注册处 | `ohos/entry/src/main/ets/entryability/EntryAbility.ets` |
| 现成 bridge 模板 | `ohos/entry/src/main/ets/plugins/OhosBleBridge.ets` |

---

## 5. 构建环境（坑清单，全部实测踩过）

**标准构建命令（PowerShell，非沙箱）：**
```powershell
$env:NODE_OPTIONS = $null
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\tools\node;C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin;C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin;C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
cd 'C:\Users\Administrator\OronBox'
C:\Users\Administrator\flutter_ohos\flutter_flutter\bin\flutter.bat build app --release --dart-define=APP_VERSION=1.1.3
```

**坑清单（按踩到顺序）：**
1. **Node 22 EINVAL**：`hvigorw.bat` 从 PATH 找 node，Node 22 安全补丁禁止 spawnSync 执行 .bat → FlutterTask 阶段 EINVAL。**修复：DevEco 自带 Node 18（`tools/node`）必须放 PATH 最前**。
2. **DEVECO_SDK_HOME 缺失**：系统环境变量没有，命令里必须 export，否则 `Invalid value of 'DEVECO_SDK_HOME'`。
3. **hvigorw/ohpm 找不到**：构建 `.app` 时 PATH 必须额外含 `tools/hvigor/bin` 和 `tools/ohpm/bin`，否则 `Failed to find "hvigorw"`。
4. **ohpm 重装冲掉 autoFillManager 补丁**：每次构建 ohpm install 会重装 `@ohos/flutter_ohos`，把 `ohos/oh_modules/.ohpm/@ohos+flutter_ohos@*/oh_modules/@ohos/flutter_ohos/src/main/ets/plugin/editing/OhosAutoFillHelper.ets` 的补丁覆盖回原始版，导致 ArkTS 报 15 个 `autoFillManager has no exported member` 错。**每次构建前必须重打 4 处补丁**（import 别名 `autoFillManager as _realAutoFillManager` + 顶层注入 `namespace autoFillManager {...}` 存根 + `as unknown as` 双重转换 ×2 + `requestAutoSave` 改 2 参）。补丁源码见 `HANDOFF.md` 第四节（那个文件还有效，勿删）。
5. **WorkBuddy 沙箱拦截**：构建必须非沙箱（dangerouslyDisableSandbox）。否则拦 impellerc/dartvm。
6. **wmic/reg 被黑名单拦截**：构建日志里 `PROGRAM BLOCKED ... wmic.exe / reg.EXE` 是 WorkBuddy 安全策略，**不影响构建结果**，忽略。判断成功与否看日志里的 `√ Built build\ohos\app\ohos-default-signed.app`。
7. **NODE_OPTIONS 干扰**：构建前必须 `$env:NODE_OPTIONS = $null`。
8. **wasm3 的 externalNativeOptions 勿丢**：`ohos/entry/build-profile.json5` 里的 `externalNativeOptions`（CMake 编译 wasm3）曾因 rebase 丢失导致 libwasm3.so 不进 HAP。rebse/cherry-pick 后要检查。
9. **长分支名 ref 静默失败**：见第 2 节。

**构建产物位置：**
- Release App Pack：`build/ohos/app/ohos-default-signed.app`
- 签名版 HAP：`ohos/entry/build/default/outputs/default/entry-default-signed.hap`

**hdc 安装（手机连上后）：**
```bash
HDC="/c/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
"$HDC" tconn <IP:端口>
"$HDC" list targets
cd <输出目录> && MSYS_NO_PATHCONV=1 "$HDC" install entry-default-signed.hap
```

---

## 6. 待办清单（按优先级）

1. **[高] 端到端实测 2FA**：代码已实现、HAP 已装手机（PSN-AL00，无线调试端口已变 `192.168.31.199:36691`，**不是**文档旧写的 42033）。用户在手机登录小米账号触发 2FA，确认 WebView 弹出 + 验证回填成功。若失败，抓 `hilog` 里 `OronBoxTwoFactorPage` / `OronBoxMiAccountTwoFactorBridge` tag 的日志定位。
2. **[高] 端到端实测「编辑页选图确定」**：已修复 `resource_image_processor.dart` 的 `Isolate.spawn` 崩溃（鸿蒙引擎不支持 isolate，报 `package_config.json` 缺失），改为鸿蒙走同步编码路径。HAP 已重装。需用户在手机编辑页选图→确定，确认不再弹 `resource image worker failed to start`。
3. **[中] 提交「特别感谢」+ 2FA + 选图修复**：注意第 2 节的 ref 坑，确认 `HEAD` 真正前进后再 push 到 fork `diana9905454/OronBox` 的 `feat/harmonyos-ohos-port`。用户之前说"先不发"，提交推送前最好再跟用户确认一次。
4. **[低] 上架华为应用市场**：参考 `上架清单-鸿蒙激励计划.md`（未跟踪文件，与本次功能无关）。

---

## 7. 给接手 AI 的速查结论

- **别混淆目录**：代码在 `C:\Users\Administrator\OronBox`。
- **先看第 2 节 git 状态**，别丢已暂存的「特别感谢」改动。
- **2FA 已实现**：Dart 端 `_io.dart` + 鸿蒙端 `MiAccountTwoFactorBridge.ets` + `TwoFactorPage.ets` 都已就位，编译通过、已装机。剩下只是手机端实测。
- **Cookie API 注意**：用 `webview.WebCookieManager.fetchCookieSync(url)`，不是示例里的 `CookieManager.getCookieSync(url, cb)`（后者 API 24 已不存在）。
- **构建前必重打 autoFillManager 补丁**（坑 #4），否则必报 15 个 ArkTS 错。
- **判断构建成功看 `√ Built` 日志，别信退出码**（坑 #6）。
- **ArkTS 对象字面量坑**：`Record<string,string>` 不通过 ArkTS 编译，必须定义显式 `interface`（本次踩过，报 `arkts-no-untyped-obj-literals`）。
- **鸿蒙不支持 `Isolate.spawn`**：spawn 出的 isolate 初始化时解析 `package_config.json` 失败（报 `resource image worker failed to start`）。任何 `Isolate.spawn`/`Isolate.run` 的后台任务在鸿蒙端都要改走同步路径或用其他机制（`resource_image_processor.dart` 已按此处理：`kIsWeb || defaultTargetPlatform == TargetPlatform.ohos` 走同步编码）。
- **手机无线调试端口会变**：上次 42033，本次变 36691。连接前先 `hdc list targets` 拿当前端口。
