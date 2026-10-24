<p align="center">
  <img src="assets/images/app_icon.png" width="112" alt="OronBox">
</p>

<h1 align="center">OronBox</h1>

<p align="center">一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建</p>

<p align="center">
  <a href="https://github.com/zxor-org/OronBox/releases"><img src="https://img.shields.io/github/v/release/zxor-org/OronBox?display_name=tag&sort=semver&label=release" alt="Latest release"></a>
  <a href="https://github.com/zxor-org/OronBox/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/zxor-org/OronBox/ci.yml?label=CI" alt="CI status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/zxor-org/OronBox" alt="License"></a>
  <a href="https://github.com/zxor-org/OronBox/stargazers"><img src="https://img.shields.io/github/stars/zxor-org/OronBox?style=flat" alt="GitHub stars"></a>
</p>

<p align="center"><a href="README.en.md">English</a> · 简体中文</p>

## 快速入口

- [下载最新版本](https://github.com/zxor-org/OronBox/releases)
- [用户文档](https://oronbox.zxor.org/user)
- [开发文档](https://oronbox.zxor.org/developer)
- [问题反馈](https://github.com/zxor-org/OronBox/issues)

## OronBox 是什么？

OronBox 是一款跨平台可穿戴设备管理工具，无需官方客户端，即可连接、管理 VelaOS / ZeppOS 设备，并为其安装资源、同步运动健康和天气等数据

## 支持平台

> 我们首先希望您的设备支持蓝牙，如果你正在使用 Ubuntu，我们希望它的版本最好是 24.04+

| 平台 | 状态 | 说明 |
|------|------|------|
| Android | ✅ 已支持 | Android 7+ |
| Linux | ✅ 已支持 | x86_64 / aarch64 |
| Web | ✅ 已支持 | 浏览器需要支持 Web Serial / Bluetooth |
| macOS | ✅ 已支持 | macOS 12+ |
| Windows | ✅ 已支持 | Windows 10+，小米账号 2FA 登录需 WebView2 |
| iOS | ❌ 暂不支持 | 我们没有用于调试和测试的实机！ |


## 设备支持

### Xiaomi VelaOS

| 设备/系列 | 状态 |
|----------|------|
| Xiaomi Smart Band 8 Pro / 9 / 9 Pro / 10 / 10 Pro | ✅ 已支持 |
| Xiaomi Watch S1 Pro / S3系列 / S4系列 / S5 | ✅ 已支持 |
| REDMI Watch 4 / 5 / 5 eSIM / 6 | ✅ 已支持 |

### ZeppOS

| 设备/系列 | 状态 |
|----------|------|
| Amazfit ZeppOS 设备 | ✅ 已支持 |
| Xiaomi Smart Band 7 | ✅ 已支持 |

## 功能支持

| 功能 | 说明 |
|------|------|
| 连接 VelaOS 与 ZeppOS 设备 | 管理已配对设备及其连接状态 |
| 查看设备状态与资源概览 | 展示电量、存储空间、应用和表盘信息 |
| 安装表盘和应用资源 | 将表盘、应用安装到设备 |
| 调整设备应用顺序 | 修改设备启动器中的应用排列 |
| 设置设备应用布局 | 调整设备应用列表的展示方式 |
| 管理设备闹钟 | 支持新增、编辑和删除 |
| 双向查找设备 | 支持穿戴设备发起找手机响铃和手机发起查找设备使穿戴设备响铃或震动 |
| 检查或安装设备固件 | 支持完整/增量包下载安装和本地固件安装 |
| 后台定时同步数据 | 每15分钟检查一次，每1小时同步一次 |
| 同步音乐到设备 | 将 MP3 文件传输到设备音乐 |
| 同步并导出设备录音 | 从设备取回录音并保存 |
| 接收并保存手表截图 | 保存到用户图片目录 |
| 同步城市天气数据到设备 | 为设备更新选定城市的天气信息 |
| 小米设备 eSIM 管理 | 支持标准 GSMA LPA eSIM 配置文件下载、启用、停用与删除 |
| 小爱同学语音协同与语音转文字 | 监听设备小爱语音唤醒与音频流，支持本地与云端 ASR 接管解析 |
| Wi-Fi 凭据协同同步 | 响应手表 Wi-Fi 扫描与网络认证请求，完成设备 Wi-Fi 快速配网 |
| 手机辅助定位协同 | 手机后台为无独立 GPS 设备实时下发定位数据，辅助轨迹记录 |
| 登录小米账号并支持 2FA | 提供 GNSS 星历数据下载和设备 authkey 获取能力 |
| 从小米运动健康日志读取 authkey | 从本地小米运动健康应用日志中解析并读取设备 authkey |
| 同步小米设备 GNSS 星历 | 支持手表发起星历更新请求，需要登录小米账号 |
| 访问 AstroBox-Repo 与米坛资源 | 浏览和获取社区资源 |
| 通过 OAuth 登录米坛社区 | 获取米坛社区资源 |
| 从创作者中心发布资源 | 支持同步发布到米坛和 AstroBox-Repo |

## CLI 使用

OronBox 提供功能完整且可脚本化的命令行界面，可在无 GUI 模式下管理设备、安装资源、访问社区源以及控制后台任务，用法参见 [OronBox 文档站](https://oronbox.zxor.org/user/cli)

## 从源码构建

### 环境准备

Flutter stable 与 Rust stable 是所有平台的前提：

- Flutter stable：版本见 `.fvmrc`，可用 [fvm](https://fvm.app) 安装，装好后 `flutter pub get`
- Rust stable：用 rustup 安装；WASM 运行库在首次构建时从源码编译

Debian / Ubuntu 依赖：

```sh
sudo apt install libsecret-1-dev clang cmake ninja-build pkg-config zip curl \
  libgtk-3-dev libblkid-dev liblzma-dev libasound2-dev libwebkit2gtk-4.1-dev \
  libbluetooth-dev libayatana-appindicator3-dev dpkg-dev rpm flatpak flatpak-builder
```

ARM64 另需音频库（`flutter_soloud` 自带的 Xiph `.so` 仅 amd64，ARM64 改用系统库）：

```sh
sudo apt install libflac-dev libogg-dev libopus-dev libvorbis-dev
```

其他发行版按对应包名安装同等依赖与打包工具：gtk3、webkit2gtk-4.1、bluez、libblkid、libasound2、xz，以及 dpkg-deb / rpmbuild / makepkg / linuxdeploy / appimagetool / flatpak-builder

Windows：Visual Studio 2022（C++ 桌面工作负载）；WebView2 SDK 可用 `windows/scripts/install_webview2_sdk.ps1` 安装

macOS：Xcode，仅能在 macOS 主机上构建

Android / Web：无额外依赖

### 一键构建

```sh
tool/build_all.sh [--dev]
```

构建 Android + Web + 当前宿主桌面平台，产物统一输出到 `build/release/`，并生成 `sha256sums.txt`

### 分平台构建

#### Android

```sh
tool/build_android.sh [--format apk|appbundle|all] [--abi arm64-v8a|armeabi-v7a|x86_64]
```

- `--format` / `--abi` 缺省时构建全部格式 / 全部 ABI
- 发布签名通过环境变量配置：`ORONBOX_KEYSTORE_PATH`、`ORONBOX_KEYSTORE_PASSWORD`、`ORONBOX_KEY_ALIAS`、`ORONBOX_KEY_PASSWORD`；未设置时使用 debug 签名

#### Linux

```sh
tool/build_linux.sh [--format tar.gz|deb|rpm|arch|appimage|flatpak|all] [--abi x86_64|aarch64]
```

- 缺省时打包全部可用格式，`--abi` 缺省取宿主架构
- 交叉编译 aarch64（x86_64 宿主）需将 `ORONBOX_LINUX_ARM64_SYSROOT` 指向包含 gtk3/webkit2gtk/alsa/flac/ogg/opus/vorbis 等开发包的 arm64 sysroot；交叉模式产出 tar.gz / deb / rpm / arch

#### macOS（仅 macOS 宿主）

```sh
tool/build_macos.sh
```

#### Windows

```powershell
powershell -File tool/build_windows.ps1 [-Dev] [-SkipWebView2Sdk] [-WebView2SdkVersion <版本>]
```

或在 CMD 中执行批处理：

```bat
tool\build_windows.bat [--dev]
```

#### Web

```sh
tool/build_web.sh
```

## AI 开发声明

本项目使用了 AI Agent 工具协助开发

## 鸣谢

OronBox 使用或参考了以下项目：

| 项目 | 来源性质 |
|------|----------------|
| [AstralSightStudios/AstroBox-Public](https://github.com/AstralSightStudios/AstroBox-Public) | 界面结构与交互设计参考 |
| [AstralSightStudios/AstroBox-NG-Module-Core](https://github.com/AstralSightStudios/AstroBox-NG-Module-Core) | 小米设备协议与传输层，移植改写 |
| [AstralSightStudios/AstroBox-NG-Module-Pb](https://github.com/AstralSightStudios/AstroBox-NG-Module-Pb) | 小米 wear 协议定义，逐字采用 |
| [AstralSightStudios/AstroBox-NG-Module-Bluetooth](https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth) | 蓝牙连接流程参考 |
| [AstralSightStudios/AstroBox-NG-Module-Account](https://github.com/AstralSightStudios/AstroBox-NG-Module-Account) | 小米账号登录与 authkey 获取流程参考 |
| [AstralSightStudios/AstroBox-NG-Module-Provider](https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider) | 社区资源索引与清单解析流程参考 |
| [AstralSightStudios/AstroBox-NG-Module-AppWasm](https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm) | Web Serial 连接流程参考 |
| [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) | ZeppOS 协议实现，移植改写 |
| [Kazumi](https://github.com/Predidit/Kazumi) | Material Design 组件与界面设计 |

## 许可证

[GNU Affero General Public License v3.0](LICENSE) · [附加条款](ADDITIONAL-TERMS.md) · [第三方声明](THIRD-PARTY-NOTICES.md)

## Star History

<a href="https://www.star-history.com/?repos=zxor-org%2FOronBox&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=zxor-org/OronBox&type=date&theme=dark&legend=bottom-right&sealed_token=zjHhbYRQSFR--PiwPij12KvbSLyZpMjCTzHDFKh0Tmg1j9Od44-VRoc2Z_O7YjiNpEWX2n72xgKNaSEpSAXqDiRF709__x-d5YB-JXY2_yqVgDV1FGdGOCwsNkXUFXs37GfZqGiqTnNCKAiIuQh2Njdoxx_yE9I48b4Q6iItHM-O40tXhJhnMJsHn908" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=zxor-org/OronBox&type=date&legend=bottom-right&sealed_token=zjHhbYRQSFR--PiwPij12KvbSLyZpMjCTzHDFKh0Tmg1j9Od44-VRoc2Z_O7YjiNpEWX2n72xgKNaSEpSAXqDiRF709__x-d5YB-JXY2_yqVgDV1FGdGOCwsNkXUFXs37GfZqGiqTnNCKAiIuQh2Njdoxx_yE9I48b4Q6iItHM-O40tXhJhnMJsHn908" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=zxor-org/OronBox&type=date&legend=bottom-right&sealed_token=zjHhbYRQSFR--PiwPij12KvbSLyZpMjCTzHDFKh0Tmg1j9Od44-VRoc2Z_O7YjiNpEWX2n72xgKNaSEpSAXqDiRF709__x-d5YB-JXY2_yqVgDV1FGdGOCwsNkXUFXs37GfZqGiqTnNCKAiIuQh2Njdoxx_yE9I48b4Q6iItHM-O40tXhJhnMJsHn908" />
 </picture>
</a>
