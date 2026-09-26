<p align="center">
  <img src="assets/images/app_icon.png" width="112" alt="OronBox">
</p>

<h1 align="center">OronBox</h1>

<p align="center">A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter</p>

<p align="center">
  <a href="https://github.com/zxor-org/OronBox/releases"><img src="https://img.shields.io/github/v/release/zxor-org/OronBox?display_name=tag&sort=semver&label=release" alt="Latest release"></a>
  <a href="https://github.com/zxor-org/OronBox/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/zxor-org/OronBox/ci.yml?label=CI" alt="CI status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/zxor-org/OronBox" alt="License"></a>
  <a href="https://github.com/zxor-org/OronBox/stargazers"><img src="https://img.shields.io/github/stars/zxor-org/OronBox?style=flat" alt="GitHub stars"></a>
</p>

<p align="center"><a href="README.md">简体中文</a> · English</p>

## Quick links

- [Download the latest release](https://github.com/diana9905454/OronBox/releases)
- [User documentation](https://oronbox.zxor.org/user)
- [Developer documentation](https://oronbox.zxor.org/developer)
- [Report an issue](https://github.com/zxor-org/OronBox/issues)

## What is OronBox?

OronBox is a cross-platform wearable device management tool that connects to and manages VelaOS / ZeppOS devices without the official client, installs resources, and synchronizes fitness and weather data.

## Supported platforms

> We recommend using a device with Bluetooth support. If you are using Ubuntu, Ubuntu 24.04 or later is recommended.

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Supported | Android 7+ |
| Linux | ✅ Supported | x86_64 / aarch64 |
| Web | ✅ Supported | The browser must support Web Serial / Bluetooth |
| macOS | ✅ Supported | macOS 12+ |
| Windows | ✅ Supported | Windows 10+; Xiaomi account 2FA login requires WebView2 |
| iOS | ❌ Not currently supported | No physical device is available for debugging or testing |
| Harmonyos | ✅ supported | OH api23+ |


## Supported devices

### Xiaomi VelaOS

| Device / family | Status |
|-----------------|--------|
| Xiaomi Smart Band 8 Pro / 9 / 9 Pro / 10 / 10 Pro | ✅ Supported |
| Xiaomi Watch S1 Pro / S3 series / S4 series / S5 | ✅ Supported |
| REDMI Watch 4 / 5 / 5 eSIM / 6 | ✅ Supported |

### ZeppOS

| Device / family | Status |
|-----------------|--------|
| Amazfit ZeppOS devices | ✅ Supported |
| Xiaomi Smart Band 7 | ✅ Supported |

## Feature support

| Feature | Description |
|---------|-------------|
| Connect VelaOS and ZeppOS devices | Manage paired devices and their connection state |
| View device status and resource overview | Show battery, storage, apps and watch face information |
| Install watch face and app resources | Install watch faces and apps on the device |
| Adjust device app order | Change the app order in the device launcher |
| Set the device app layout | Adjust how the device app list is displayed |
| Manage device alarms | Add, edit and delete device alarms |
| Find devices in both directions | Let the wearable ring the phone, or make the wearable ring or vibrate from the phone |
| Check or install device firmware | Download and install full or incremental packages, or install local firmware |
| Schedule background data synchronization | Check every 15 minutes and synchronize every hour |
| Sync music to the device | Transfer MP3 files to the device music library |
| Sync and export device recordings | Retrieve and save recordings from the device |
| Receive and save watch screenshots | Save screenshots to the user's Pictures directory |
| Sync city weather to the device | Update weather information for the selected city |
| Sign in to Xiaomi accounts with 2FA | Download GNSS ephemeris data and obtain the device authkey |
| Read authkey from Xiaomi Fitness logs | Parse local Xiaomi Fitness app logs to retrieve the device authkey |
| Sync Xiaomi device GNSS ephemeris | Support watch-initiated ephemeris updates; Xiaomi account required |
| Access AstroBox-Repo and BandBBS resources | Browse and obtain community resources |
| Sign in to BandBBS with OAuth | Obtain BandBBS community resources |
| Publish resources from the creator center | Publish to BandBBS and AstroBox-Repo |

## CLI usage

OronBox provides a powerful, scriptable command-line interface for managing devices, installing resources, accessing community sources and controlling background tasks without the GUI. See the [OronBox documentation site](https://oronbox.zxor.org/user/cli) for usage details.

## Build from source

### Prerequisites

- Flutter stable (we recommend managing it with [fvm](https://fvm.app); the repo root `.fvmrc` pins the version), then `flutter pub get`
- Platform-specific dependencies:
  - **Linux**: `gtk3` `webkit2gtk-4.1` `bluez` `libblkid` `libasound2` (`libasound2-dev` when building) `xz`; packaging tools as needed: `dpkg-deb` (deb), `rpmbuild` (rpm), `makepkg` (arch), `linuxdeploy` or `appimagetool` (AppImage), `flatpak-builder` with the GNOME SDK (Flatpak)
  - **Linux ARM64**: also require `libflac-dev`, `libogg-dev`, `libopus-dev`, and `libvorbis-dev`; the `flutter_soloud` bundled Xiph `.so` files are amd64-only, so ARM64 builds use system libraries and ARM64 packages declare the matching runtime dependencies
  - **Android**: the Android SDK/NDK bundled with a standard Flutter setup
  - **Windows**: Visual Studio 2022 (Desktop development with C++); the WebView2 SDK can be installed via `windows/scripts/install_webview2_sdk.ps1`
  - **macOS**: Xcode; can only be built on a macOS host
  - **Web**: no extra dependencies

### Build everything

```bash
tool/build_all.sh [--dev]
```

Builds Android + Web + the desktop platform of the current host. Artifacts land in `build/release/` along with a generated `sha256sums.txt`.

### Per-platform builds

```bash
# Android
tool/build_android.sh [--format apk|appbundle|all] [--abi arm64-v8a|armeabi-v7a|x86_64]

# Linux
tool/build_linux.sh [--format tar.gz|deb|rpm|arch|appimage|flatpak|all] [--abi x86_64|aarch64]

# macOS (macOS hosts only)
tool/build_macos.sh

# Windows (either one)
tool\build_windows.bat [--dev]
powershell -File tool/build_windows.ps1 [-Dev] [-SkipWebView2Sdk] [-WebView2SdkVersion <version>]

# Web
tool/build_web.sh
```

- Without `--format` / `--abi`, every format / ABI is built; on Linux `--abi` defaults to the host architecture
- Android release signing is configured through environment variables: `ORONBOX_KEYSTORE_PATH`, `ORONBOX_KEYSTORE_PASSWORD`, `ORONBOX_KEY_ALIAS`, `ORONBOX_KEY_PASSWORD`; without them the debug signing config is used
- Cross-building Linux aarch64 from an x86_64 host requires `ORONBOX_LINUX_ARM64_SYSROOT` pointing to an arm64 sysroot with the gtk3/webkit2gtk/alsa/flac/ogg/opus/vorbis development packages; cross mode only produces tar.gz / deb / rpm / arch packages

### Version and artifact conventions

- The version is taken from the `version` field in `pubspec.yaml`
- The git worktree must be clean by default; `--dev` allows a dirty worktree and appends git metadata to the version (for example, `1.0.0.dirty.abc1234`)
- Artifacts are named `oronbox-<version>-<platform>[-<arch>].<ext>`, with symbol files archived alongside the packages

## AI development disclosure

This project was developed with the help of AI agent tools.

Usage:

| Model | Areas assisted |
|-------|----------------|
| GPT 5.5/5.6-Sol | Dart Bluetooth connection behavior/protocol, backend logic rewrite and parts of the frontend |
| GPT 5.6-Luna | GitHub CI / Release script rewrites and fixes, and Fitness implementation |
| Kimi K3 | OOBE, creator-related logic |
| Kimi K2.6 | Parts of the frontend, UI/UX, initial backend |

## Acknowledgements

OronBox references and uses code from the following excellent projects:

| Project | What we referenced |
|---------|--------------------|
| [AstroBox-Public](https://github.com/AstralSightStudios/AstroBox-Public) | UI structure, resource flow and interaction design |
| [AstroBox-NG-Module-Core](https://github.com/AstralSightStudios/AstroBox-NG-Module-Core) | Xiaomi device protocol, installation flow and transfer behavior |
| [AstroBox-NG-Module-Bluetooth](https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth) | Bluetooth connection behavior |
| [AstroBox-NG-Module-Account](https://github.com/AstralSightStudios/AstroBox-NG-Module-Account) | Xiaomi account login, device synchronization and authkey retrieval |
| [AstroBox-NG-Module-Provider](https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider) | Community resource index, CDN and manifest parsing |
| [AstroBox-NG-Module-AppWasm](https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm) | Web Serial and browser-side connection flow |
| [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) | ZeppOS and wearable device protocol research |
| [Kazumi](https://github.com/Predidit/Kazumi) | Material Design components and UI design |

## License

OronBox is licensed under the [GNU Affero General Public License v3.0](LICENSE)

## Star History

<a href="https://www.star-history.com/?repos=zxor-org%2FOronBox&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=zxor-org/OronBox&type=date&theme=dark&legend=bottom-right&sealed_token=zjHhbYRQSFR--PiwPij12KvbSLyZpMjCTzHDFKh0Tmg1j9Od44-VRoc2Z_O7YjiNpEWX2n72xgKNaSEpSAXqDiRF709__x-d5YB-JXY2_yqVgDV1FGdGOCwsNkXUFXs37GfZqGiqTnNCKAiIuQh2Njdoxx_yE9I48b4Q6iItHM-O40tXhJhnMJsHn908" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=zxor-org/OronBox&type=date&legend=bottom-right&sealed_token=zjHhbYRQSFR--PiwPij12KvbSLyZpMjCTzHDFKh0Tmg1j9Od44-VRoc2Z_O7YjiNpEWX2n72xgKNaSEpSAXqDiRF709__x-d5YB-JXY2_yqVgDV1FGdGOCwsNkXUFXs37GfZqGiqTnNCKAiIuQh2Njdoxx_yE9I48b4Q6iItHM-O40tXhJhnMJsHnN908" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=zxor-org/OronBox&type=date&legend=bottom-right&sealed_token=zjHhbYRQSFR--PiwPij12KvbSLyZpMjCTzHDFKh0Tmg1j9Od44-VRoc2Z_O7YjiNpEWX2n72xgKNaSEpSAXqDiRF709__x-d5YB-JXY2_yqVgDV1FGdGOCwsNkXUFXs37GfZqGiqTnNCKAiIuQh2Njdoxx_yE9I48b4Q6iItHM-O40tXhJhnMJsHnN908" />
 </picture>
</a>
