# OronBox 鸿蒙移植 — DevEco 执行手册

> 前提：本机已装 **DevEco Studio 6.x** + **OHOS SDK（API + Toolchains + Native）** + **CPF-Flutter oh-3.44.9-release**（已 `flutter config --ohos-sdk` 关联）。
> 估算耗时基于一个熟悉 Flutter + 略懂 ArkTS 的开发者。

## 阶段 0：环境（GUI，需你手动）

1. DevEco → Settings → SDK Manager → 勾 API + Toolchains + Native，Apply 下载完。
2. 验证：`SDK目录/toolchains/bin/hdc.exe` 存在；`flutter doctor -v` 的 ohos 工具链全绿。
3. clone flutter ohos：`git clone https://atomgit.com/CPF-Flutter/flutter_flutter.git` → `git checkout oh-3.44.9-release`。

## 阶段 1：生成空壳 ohos 工程（约 10 分钟）

```bash
cd OronBox
flutter create --platforms=ohos .      # 生成 ohos/ 标准工程
flutter pub get
flutter run -d ohos                    # 先跑通空壳（需真机/模拟器）
```

## 阶段 2：降级 Flutter 版本（约 3~5 天，最大体力活）

- 把 `.fvmrc` 的 3.47.1 改成 3.44.9。
- 把 `pubspec.yaml` 的 `environment.sdk` 与依赖约束按 `pubspec.ohos.patch` 调整。
- `flutter pub get` 解决冲突；逐个处理 Dart 3.13→3.7 语法回退（主要是某些包的 API 变动）。

## 阶段 3：换通用插件（约 1~2 天）

- `url_launcher` / `shared_preferences` / `path_provider` / `go_router` 等：CPF-Flutter 组织下已有 ohos 适配版，按 `pubspec.ohos.patch` 替换/锁定版本。
- 桌面专用插件（`window_manager` / `tray_manager` / `desktop_drop`）加条件导入守卫：
  在 `lib/` 里把它们的 import 包进 `if (dart.library.ffi) ...` 或 platform 判断，ohos 走 stub。

## 阶段 4：BLE（核心，约 1~2 周）

1. fork `Navideck/universal_ble` 到你的账号，加 `ohos` 平台目录。
2. `flutter pub run pigeon ...`（见 `UNIVERSAL_BLE_PIGEON_CONTRACT.md`）生成 C++ 骨架。
3. 把 `ohos/universal_ble_ohos/cpp/universal_ble_ohos_host.cpp` 的 TODO 填上：每个方法调 `@ohos.bluetooth.ble`。
4. 注册 NAPI 模块（`ohos/universal_ble_ohos/ets/UniversalBleOhosPlugin.ets`）。
5. OronBox `pubspec.yaml` 的 `universal_ble` 改为 git 指向该 fork。
6. 真机连通一台小米/ZeppOS 手环，验证扫描/连接/GATT 读写/notify。

## 阶段 5：后台同步 + 登录（约 3~5 天）

- 后台：`ohos/universal_ble_ohos/ets/BackgroundSync.ets` 模板 → 长时任务 + 代理提醒。
- 登录：`ohos/universal_ble_ohos/ets/XiaomiLogin.ets` 模板 → ArkWeb 加载小米 2FA。

## 阶段 6：原生库（可选，按需求）

- 砍掉 `flutter_soloud`（音频）、`wasm_run`/`quickjs_engine`（首版 stub）。
- 后续：`quickjs_engine` 纯 C+CMake 用 OHOS NDK 交叉编译较易；`flutter_soloud` 无现成适配，工作量最大。

## 验收

- [ ] `flutter build hap` 成功
- [ ] 真机安装，BLE 连上一台手环并读写数据
- [ ] 后台定时同步生效
- [ ] 小米账号登录可用
- [ ] 提交到 fork 的 `feat/harmonyos-ohos-port` 分支并开源（AGPL-3.0）
