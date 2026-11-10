# Vendored Native Dependencies

这两个原生库的源码**直接复制在本仓库内**（不在 pub 依赖里），因此它们的
安全更新**不会自动流入**。上游 `zxor-org/OronBox` 用的是 pub 包
（`quickjs_engine: ^0.1.5` / `wasm_run_flutter: ^0.1.0`），由包作者负责构建与
更新；本 fork 改为自行交叉编译，**责任随之转移到本仓库维护者**。

本文件是该责任的落点：记录版本、来源、更新方法。

## 清单

| 库 | 版本 | 源码位置 | 上游来源 | 用途 |
|---|---|---|---|---|
| QuickJS-NG | **0.14.0**（`CONFIG_VERSION="ng-0.14.0"`） | `ohos/entry/src/main/cpp/quickjs/` | https://github.com/quickjs-ng/quickjs | 执行第三方插件的 JS（`libquickjs_c_bridge_plugin.so`） |
| wasm3 | **0.9.1-beta.1** | `ohos/entry/src/main/cpp/wasm3/` | https://github.com/wasm3/wasm3 | 解释 .wasm（Opus 解码等）（`libwasm3.so`） |

同源但走 `path:` 依赖的 Dart 侧 fork：`packages/quickjs_engine/`（相对
pub 版 `quickjs_engine: ^0.1.5`，同样不会自动跟随上游更新）。

> 风险说明：两者都是**解析不可信输入的 C 代码** —— quickjs 直接执行第三方插件
> 的脚本，wasm3 解析插件/资源里的 .wasm 字节。历史上两者均有 CVE。wasm3 使用的
> 还是 **beta** 版本。

## 构建集成点

- CMake 目标与硬化选项：`ohos/entry/src/main/cpp/CMakeLists.txt`
- 编译进 HAP 的 ABI：`ohos/entry/build-profile.json5` → `externalNativeOptions`
  （`abiFilters: ["arm64-v8a"]`，`targets: ["wasm3", "quickjs_c_bridge_plugin"]`）
- Dart 侧加载：`packages/quickjs_engine/lib/quickjs/ffi.dart`（`Platform.isOhos`
  分支用 `DynamicLibrary.open('libquickjs_c_bridge_plugin.so')`）

⚠️ 因为 Dart 通过 **符号名** 解析 bridge 入口，CMake 中**不要**加
`-fvisibility=hidden`（会隐藏导出符号导致 `dart:ffi` 查找失败）。

已开启的硬化项，并在产物上**实测验证过**（2026-09-23，`llvm-readelf` + 符号表检索）：

| 硬化项 | 验证结果 |
|---|---|
| `-fstack-protector-strong` | ✅ 两库均引用 `__stack_chk_fail` |
| `-Wl,-z,relro` | ✅ 存在 `GNU_RELRO` 段 |
| `-Wl,-z,now` | ✅ 动态段含 `BIND_NOW`（立即绑定） |
| `-Wl,-z,noexecstack` | ✅ 存在 `GNU_STACK` 段 |
| `-D_FORTIFY_SOURCE=2` | ⚠️ 未观察到 `__*_chk` 符号 —— OpenHarmony 用 musl libc，其 fortify 覆盖远小于 glibc。保留无副作用，但不要指望它 |

验证命令（替换 `<so>` 为 `ohos/entry/build/default/intermediates/libs/default/arm64-v8a/lib*.so`）：

```powershell
$readelf = "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\native\llvm\bin\llvm-readelf.exe"
& $readelf -l <so>   # 查 GNU_RELRO / GNU_STACK
& $readelf -d <so>   # 查 BIND_NOW
```

## 更新流程

1. 记录当前版本：`grep -r "CONFIG_VERSION\|M3_VERSION " ohos/entry/src/main/cpp/`
2. 从上游拉取对应 tag 的源码，替换 `cpp/quickjs/` 或 `cpp/wasm3/` 下同名文件
   （注意：**不要**引入 quickjs-libc.c —— 它依赖 OpenHarmony 受限 libc 中不存在的
   POSIX fork/exec，见 CMakeLists 注释）
3. 构建验证：
   ```powershell
   $env:DEVECO_SDK_HOME = "C:\Program Files\Huawei\DevEco Studio\sdk"
   $env:JAVA_HOME       = "C:\Program Files\Huawei\DevEco Studio\jbr"
   $env:PATH = "C:\Program Files\Huawei\DevEco Studio\jbr\bin;" + ((($env:PATH -split ';') | Where-Object { $_ -notmatch 'Wbem' }) -join ';')
   Set-Location ohos
   & ".\hvigorw.bat" assembleApp -p product=default -p buildMode=release `
     -p "DART_DEFINES=QVBQX1ZFUlNJT049MS4xLjM=" -p TARGET_PLATFORM=ohos-arm64 --no-daemon
   ```
   （构建前先删 `build\ohos\intermediates\flutter`，否则可能撞 errno 183）
4. 真机验证 JS 插件与 Opus 解码功能（这两条是唯一走这两个库的路径）。

## 订阅（每次上游发版时顺手做一次）

- quickjs-ng：https://github.com/quickjs-ng/quickjs/security/advisories
- wasm3：https://github.com/wasm3/wasm3/security/advisories
- 也可用 OSV 查询：https://osv.dev/list?q=quickjs-ng / `?q=wasm3`

**建议节奏**：与"同步上游 OronBox"同一批次处理（见 `harmonyos-port/runbook.md`），
避免两套更新流程各自遗忘。

## 上游 1.2.0 依赖适配（2026-11-07）

合并 `OronCanopy/OronBox` v1.2.0 后，依赖层有四处本地适配：

1. **material_ui / cupertino_ui 本地 shim**（`packages/material_ui`、
   `packages/cupertino_ui`，在 `pubspec.yaml` 的 `dependency_overrides` 里指向本地路径）。
   原因：上游把 Material/Cupertino 拆成 pub 包，这两个包对 `TargetPlatform`
   做穷举 switch，不认识 ohos fork 新增的 `TargetPlatform.ohos`，会报
   `non_exhaustive_switch_expression`。shim 直接 `export package:flutter/material.dart`
   / `cupertino.dart`，复用 fork 里已适配 ohos 的 in-tree 实现。
   *将来若上游 in-tree Material 被彻底移除，需要改为给 pub 包逐个补 case。*

2. **三条 git 依赖的本地镜像**（仅本机，`pubspec_overrides.yaml` 已被 gitignore）：
   `oronbox_network`、`oronbox_location`、`wasm_run` 镜像在
   自选的本地依赖目录。GitHub 直连不稳时用它跑 `pub get`；
   网络恢复后可删除该文件回到上游 git 依赖。注意：该文件会**整段替换**
   `pubspec.yaml` 的 `dependency_overrides`，所以上面的 shim 也要在里面重复一遍。

3. **flutter_zxing 3.1.0 的 pub cache 补丁**（不可复现，cache repair 后需重打）：
   `flutter_zxing-3.1.0/lib/src/ui/reader_widget.dart` 的
   `_preferredImageFormatGroup()` 里，在 `case TargetPlatform.fuchsia:` 前加
   `case TargetPlatform.ohos:`（与 linux 同分支，返回 `ImageFormatGroup.unknown`）。

4. **flutter_secure_storage 本地 fork**（`packages/flutter_secure_storage`，
   在 `dependency_overrides` 里指向本地路径）。
   原因：上游 11.2.0 的 `_selectOptions()` 对未知平台直接
   `throw UnsupportedError('unsupported_platform')`，鸿蒙 fork 报的是
   `TargetPlatform.ohos`，于是 `PrivateAppState` / AI 密钥 / OAuth 凭证 / 云 ASR
   四处全部抛异常，`PrivateAppState.initialize()` 必失败，连「导出备份」都会在
   `appdata.maintenance.end` 处被连带打断（报「文件导出失败」）。
   fork 只改一处：`ohos` 分支返回空 options 表。原生侧由
   `ohos/entry/src/main/ets/plugins/SecureStorageBridge.ets` 实现同名通道
   `plugins.it_nomads.com/flutter_secure_storage`，底层用 **Asset Store Kit**
   （`@ohos.security.asset`，系统托管密钥，等价 Keychain/Keystore）。
   Asset 单条 `SECRET` 上限 1024 字节，而 vault 是 JSON，因此按 900 字节分片
   （`<key>` 存清单、`<key>#<i>` 存分片），对 Dart 侧透明。

**构建现状**：`assembleApp -p buildMode=debug` 可通过（HAP ≈ 224 MB，含 JIT 引擎）；
`buildMode=release` 仍受 Windows 端 `gen_snapshot` 产物缺口阻塞（详见
`SDK_UPGRADE_ASSESSMENT.md`），需 macOS 构建或等官方补 Windows 版工件。

## 客户端证明（build attestation）

服务端的 `/api/v1/*` 要求客户端对请求做 HMAC 签名，密钥由主密钥按
`HMAC-SHA256(master, "oronbox:v1:<version>:<commit>")` 派生。自编译包默认没有
密钥 → 不签名 → 全部 401。

本地构建步骤（密钥永不入库）：

1. 主密钥放 `config/attestation_master.local`（64 hex，`.gitignore` 已忽略）；
2. 跑 `tool/prepare_build_integrity.py --version <ver> --commit <HEAD>`，
   环境变量 `ORONBOX_AUTH_MASTER` 从该文件读入，产出
   `build/integrity_defines.json`（每版本派生密钥）；
3. 跑 `tool/ohos_dart_defines.py --out build/dart_defines.txt
   --dart-out lib/src/core/network/attestation_build_values.g.dart`，
   同时产出 hvigor 的 `DART_DEFINES` blob 和 Dart 常量文件（已忽略）；
4. 再调 hvigor。

**为什么还要 Dart 常量**：hvigor 插件把 `DART_DEFINES` 转成
`flutter assemble --DartDefines=<blob>`，但在本 fork 里这些值只落进
environment 的普通键，ohos 的 kernel 目标读不到（实测 `kernel_blob.bin` 中
搜不到常量，且没有报错）。因此 `ClientAttestationConfig` 的默认值改为
`String.fromEnvironment(..., defaultValue: kBuildAttestation*)`：环境 define
优先，取不到就用生成文件里的常量。构建后可直接在
`resources/rawfile/flutter_assets/kernel_blob.bin` 里 grep 派生密钥来验证是否进包。
