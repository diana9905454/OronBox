# OronBox → HarmonyOS (OpenHarmony NEXT) 移植方案

> 本文基于 `OronBox` 真实 `pubspec.yaml`（已逐项核对）与 `universal_ble` 的真实 Pigeon 契约撰写。
> 本目录 `harmonyos-port/` 是移植脚手架，需在装有 DevEco Studio + OHOS SDK + flutter ohos 的机器上收尾。

## 一、结论

- **UI 与业务逻辑（约 70% 代码）可直接复用**：Flutter-OH（CPF-Flutter）社区适配已成熟。
- **真正要动刀的只有 4 处平台强相关代码**：BLE 蓝牙、原生 C/C++ 库、后台同步、WebView 登录。
- 最小可用版（砍掉音频 WASM/原生库、mDNS）约 3~4 周；全功能约 5~8 周。

## 二、版本决策（关键）

- OronBox 用 fvm 锁 **Flutter 3.47.1**，但 `pubspec.yaml` 的 `environment.sdk: ^3.13.0`，约束宽松。
- 鸿蒙社区适配版 **CPF-Flutter**（`atomgit.com/CPF-Flutter/flutter_flutter`）已发布到 `oh-3.44.9-release`。
- **选用 `oh-3.44.9-release`**：离 3.47.1 仅差 3 个 minor，降级幅度远小于退回 3.35.7，依赖约束冲突最少。
- 需把 `OronBox/.fvmrc` 的 3.47.1 改到 3.44.9，并处理少量 Dart/插件 API 差异。

## 三、依赖兼容性矩阵（基于真实 pubspec）

| 依赖 | 版本 | ohos 现状 | 处理 |
|------|------|-----------|------|
| flutter / flutter_localizations | sdk | CPF-Flutter 提供 | 换 ohos flutter |
| go_router | ^17.3.0 | ✅ 纯 Dart | 直接复用 |
| flutter_riverpod | ^3.3.2 | ✅ 纯 Dart | 直接复用 |
| url_launcher | ^6.3.1 | ✅ CPF 已适配 | 换依赖 |
| shared_preferences | ^2.5.5 | ✅ 已适配 | 换依赖 |
| path_provider | ^2.1.6 | ✅ 已适配 | 换依赖 |
| protobuf / fixnum | ^6.0.0 / ^1.1.1 | ✅ 纯 Dart | 直接复用 |
| **universal_ble** | ^2.1.0 | ❌ 无 ohos | **fork 加 Pigeon C++ host（见下）** |
| **flutter_soloud** | ^4.0.12 | ❌ C++ 原生 | 首版砍掉音频，后续 NDK 移植 |
| **wasm_run_flutter** | ^0.1.0 | ❌ WASM runtime | 首版 stub，后续 NDK |
| **quickjs_engine** | ^0.1.5 | ❌ C 原生 | NDK 交叉编译（纯 C+CMake，难度中） |
| **mdns_dart** | ^2.2.2 | ❌ 原生 mDNS | 首版 stub，用 ohos 网络发现替代 |
| **desktop_drop** | ^0.8.0 | ❌ 桌面专用 | 条件导入守卫（仅 desktop 启用） |
| **window_manager** | ^0.5.2 | ❌ 桌面专用 | 条件导入守卫 |
| **tray_manager** | ^0.5.3 | ❌ 桌面专用 | 条件导入守卫 |
| oronbox_network | git zxor-org | ✅ 纯 Dart | 直接复用 |
| dio / file_picker / cross_file 等 | — | ⚠️ 部分需 ohos 适配 | 逐个核对 CPF 列表 |

## 四、四个攻坚点

1. **BLE（最核心）**：app 的 GATT 逻辑全在 `lib/src/core/services/ble_gatt_driver.dart`，只通过 `UniversalBle.*` 调用。
   → **fork `universal_ble` 加 `ohos` 平台**，用 Pigeon 生成 C++ host，在 C++ 里调 `@ohos.bluetooth.ble`。
   → 这样 `ble_gatt_driver.dart` 一行都不用改。真实契约见 `UNIVERSAL_BLE_PIGEON_CONTRACT.md`，C++ 骨架见 `ohos/universal_ble_ohos/cpp/`。
2. **原生 C/C++ 库**：`flutter_soloud`/`quickjs_engine`/`wasm_run` 需用 OHOS NDK（`--target=aarch64-linux-ohos`）交叉编译，经 NAPI 挂入 ohos 工程。首版建议砍掉音频与 WASM。
3. **后台定时同步**：鸿蒙后台管控严格，需用 `backgroundTaskManager` 长时任务（BLUETOOTH_INTERACTION）+ 代理提醒，纯轮询会被杀。模板见 `ohos/universal_ble_ohos/ets/BackgroundSync.ets`。
4. **WebView 登录**：小米 2FA 用 ArkWeb（`webview_flutter` 的 ohos 适配版）。模板见 `ohos/universal_ble_ohos/ets/XiaomiLogin.ets`。

## 五、建议执行顺序

空壳 ohos 工程 → 换通用插件 → BLE 真机连通一台手环 → 迁移原生库 → 后台任务。每步单独提交，方便回退。

## 六、许可证

OronBox 为 **AGPL-3.0**：你移植后的版本一旦分发（含网络服务）必须同样开源；对 `universal_ble` 的 fork 同理。

## 七、本目录文件清单

- `README.md` — 本文件（方案 + 依赖矩阵）
- `UNIVERSAL_BLE_PIGEON_CONTRACT.md` — BLE 平台通道真实契约
- `runbook.md` — DevEco 内逐步执行手册
- `pubspec.ohos.patch` — pubspec.yaml 需做的具体修改
- `ohos/entry/src/main/module.json5` — 权限与能力声明
- `ohos/entry/src/main/ets/entryability/EntryAbility.ets` — 平台通道注册入口
- `ohos/universal_ble_ohos/ets/UniversalBleOhosPlugin.ets` — NAPI 加载器
- `ohos/universal_ble_ohos/cpp/universal_ble_ohos_host.cpp` — Pigeon C++ host 骨架
- `ohos/universal_ble_ohos/ets/BackgroundSync.ets` — 后台同步模板
- `ohos/universal_ble_ohos/ets/XiaomiLogin.ets` — 小米登录模板
