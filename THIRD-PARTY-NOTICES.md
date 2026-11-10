# 第三方来源与修改声明 / Third-Party Notices and Modifications

本文件依 AGPL-3.0 第 5 条声明 OronBox 中来自第三方项目的材料、对应修改，以及各上游的署名
This file states, as required by AGPL-3.0 section 5, the material in OronBox that originates from third-party projects, the modifications made, and the attribution to each upstream

## 上游与性质 / Upstreams and nature of use

| 上游 | 本仓库位置 | 性质 | 说明 |
|------|-----------|------|------|
| [AstralSightStudios/AstroBox-NG-Module-Pb](https://github.com/AstralSightStudios/AstroBox-NG-Module-Pb) | `protos/xiaomi/` | 逐字采用 | 23 个 proto 文件取自上游 `03a9201`，本仓库仅修改 `wear_common.proto` |
| [AstralSightStudios/AstroBox-NG-Module-Core](https://github.com/AstralSightStudios/AstroBox-NG-Module-Core) | `lib/src/device/xiaomi/protocol/`、`lib/src/device/xiaomi/systems/` | 移植改写 | 小米设备协议与传输层的 Rust 实现移植为 Dart 并重构 |
| [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) | `lib/src/device/zeppos/` | 移植改写 | ZeppOS 协议实现移植为 Dart |
| [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) | `lib/src/device/xiaomi/health/` | 格式参照 | 小米健康与运动数据解析以 Mi Fitness 逆向 schema 为依据自行实现，个别文件布局参照其解析器 |
| [AstralSightStudios/AstroBox-NG-Module-Bluetooth](https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth) | `lib/src/device/core/`、`lib/src/core/services/` | 流程参考 | 蓝牙连接流程对齐 |
| [AstralSightStudios/AstroBox-NG-Module-Account](https://github.com/AstralSightStudios/AstroBox-NG-Module-Account) | `lib/src/features/accounts/` | 流程参考 | 小米账号登录与 authkey 获取流程对齐 |
| [AstralSightStudios/AstroBox-NG-Module-Provider](https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider) | `lib/src/data/astrobox/`、`lib/src/data/oronbox/` | 流程参考 | 社区资源索引与清单解析流程对齐 |
| [AstralSightStudios/AstroBox-NG-Module-AppWasm](https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm) | `lib/src/core/services/rfcomm_driver_web.dart` | 流程参考 | Web Serial 与浏览器端连接流程对齐 |
| [AstralSightStudios/AstroBox-Public](https://github.com/AstralSightStudios/AstroBox-Public) | `lib/src/app/`、`lib/src/features/` | 设计参考 | 界面结构与交互设计 |
| [Kazumi](https://github.com/Predidit/Kazumi) | `lib/src/app/theme/`、`lib/src/app/widgets/` | 设计参考 | Material Design 组件与界面设计 |
| [Breezy Weather](https://github.com/breezy-weather/breezy-weather) | `lib/src/features/devices/services/xiaomi_weather_sync_service.dart` | 数据参考 | 中国天气源实现 |
| [Open-Meteo](https://open-meteo.com/) | `lib/src/features/devices/services/xiaomi_weather_sync_service.dart` | 数据参考 | 天气预报、空气质量与地点搜索数据，遵循 CC BY 4.0 |

以上项目除 Open-Meteo 的部分数据适用 CC BY 4.0 外，均以 AGPL-3.0 授权；许可全文副本见 `assets/licenses/`

## 本仓库的修改 / Modifications made by this repository

- `protos/xiaomi/wear_common.proto`：`Timezone.offset`、`Timezone.dst_saving`、`KeyValue.value` 由 `int32` 改为 `sint32`（固件按 ZigZag 编码，单位 15 分钟），2026-08-22 与 2026-09-26
- `lib/src/device/xiaomi/`：上游 Rust 实现移植为 Dart，替换运行时与并发模型（bevy_ecs / tokio / anyhow → Riverpod / 事件总线 / Completer），重组模块边界，并按本项目需要增删功能；自 2026-07-03 起
- `lib/src/device/zeppos/`：上游 Java 实现移植为 Dart，并按本项目需要调整；具体来源标注见各文件注释

## 上游署名 / Attribution to upstreams

依各上游项目 README 中的 AGPL-3.0 第 7 条附加条款，OronBox 在应用内「关于软件 → 特别鸣谢」保留以下署名，并在「开放源代码许可」中提供各上游的许可全文：

- AstralSightStudios/AstroBox-NG-Module-Core
- AstralSightStudios/AstroBox-NG-Module-Bluetooth
- AstralSightStudios/AstroBox-NG-Module-Account
- AstralSightStudios/AstroBox-NG-Module-Provider
- AstralSightStudios/AstroBox-NG-Module-AppWasm

OronBox 自身的附加条款见 [`ADDITIONAL-TERMS.md`](ADDITIONAL-TERMS.md)

## English summary

Parts of OronBox are derived from the projects listed above: `protos/xiaomi/` is adopted verbatim
from AstroBox-NG-Module-Pb, the Xiaomi protocol and transport layer under `lib/src/device/xiaomi/`
is a Dart port of AstroBox-NG-Module-Core, and the ZeppOS layer under `lib/src/device/zeppos/` is a
Dart port of Gadgetbridge. The health and workout parsers under `lib/src/device/xiaomi/health/` are
implemented independently from Mi Fitness reverse-engineered schemas, with certain file layouts
referenced from Gadgetbridge's parsers. The remaining upstreams are referenced at the workflow,
design, or data level, except that Bluetooth, account, provider, and Web Serial integration show no
code-level correspondence. All upstreams except the CC BY 4.0 data from Open-Meteo are licensed under
AGPL-3.0, with license texts in `assets/licenses/`. Attribution required by the section 7
additional terms of the AstroBox-NG modules is preserved in the in-app acknowledgements page.
OronBox's own additional terms are in [`ADDITIONAL-TERMS.md`](ADDITIONAL-TERMS.md).
