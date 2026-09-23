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
