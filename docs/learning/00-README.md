# TimeArc 中英双语学习手册 / Bilingual Learning Handbook

这套手册按“为什么做 → 怎样拆分 → 数据怎样流动 → 每层怎样实现 → 怎样测试和表达”的顺序讲解 TimeArc。目标不是背代码，而是建立一张可以反复使用的心智地图。

## 先记住一句话 / One-sentence summary

> TimeArc is a local-first time-tracking application built with Qt 6 and QML. A separate native collector records activity into a service-owned SQLite database, while the GUI reads and transforms those records into timelines, statistics, and private memories.

中文：TimeArc 是一款本地优先的时间记录应用。独立的原生采集服务把活动写入它独占的 SQLite 数据库；Qt/QML 图形界面读取这些记录，再生成时间线、统计和私人回顾。

## 当前事实 / Current facts

- 两个桌面进程：GUI `TimeArc` 与原生服务 `time-arc-service`。
- 服务是自动采集历史的唯一写入者；GUI 对服务数据库只读。
- 服务数据库是 `timearc_service.db`；GUI 私有数据库是 `timearc.db`。
- GUI 与服务之间没有通用 socket/RPC；主要通过磁盘数据库、`service_config.json` 和 CLI 协作。
- Windows 是主要测试平台；macOS 代码已实现但仍需实机发布验证；Android 是功能预览；Linux 尚未实现。

旧版 `C:\TimeArc\learning\learning` 中的 JSONL、实时 JSON 快照和 `usage_config.json` 已经退役，只能当历史设计阅读。

## 零基础长篇教材 / Source-guided textbook

如果你需要像旧版 learning 那样，从语言概念开始、结合当前真实代码逐段解释，请进入：

> [TimeArc 源码精读教科书（20 章）](deep/00-README.md)

本页以下内容适合建立全局地图和面试前速查；`deep/` 版本适合第一次系统学习。建议先读本页 01–03，再按深度教材顺序学习并亲手打开对应源码。

## 三条阅读路线 / Three reading paths

| 目标 | 阅读顺序 |
| --- | --- |
| 面试准备 / Interview | 01 → 03 → 07 → 09 → 13 → 17 → 18 → 19 |
| 从零开发 / Build from scratch | 01 → 02 → 03 → 04 → 05 → 06 → 07 → 09 → 10 → 11 → 12 → 15 → 16 |
| 维护项目 / Contribute | 全部顺序阅读，并对照每章“源码入口” |

## 完整目录 / Contents

| 章 | 内容 |
| --- | --- |
| [01](01-product-and-requirements.md) | 产品问题、隐私与需求 / Product problem, privacy, requirements |
| [02](02-technology-foundations.md) | 技术地基 / Technology foundations |
| [03](03-two-process-architecture.md) | 双进程与磁盘契约 / Two processes and disk contract |
| [04](04-repository-and-build.md) | 目录与构建 / Repository and build |
| [05](05-startup-and-composition.md) | 启动与对象装配 / Startup and composition |
| [06](06-windows-collector.md) | Windows 采集服务 / Windows collector |
| [07](07-tracking-policies.md) | 计时策略与状态机 / Tracking policies and state machines |
| [08](08-platform-implementations.md) | macOS、Android、Linux / Platform implementations |
| [09](09-data-contract-and-databases.md) | SQLite 与所有权 / SQLite and ownership |
| [10](10-cpp-application-layers.md) | C++ 应用层 / C++ application layers |
| [11](11-qt-qml-bridge.md) | Qt/QML 桥 / Qt/QML bridge |
| [12](12-qml-ui.md) | 桌面与移动 UI / Desktop and mobile UI |
| [13](13-statistics-and-identity.md) | 统计与身份 / Statistics and identity |
| [14](14-configuration-lifecycle-privacy.md) | 配置、生命周期、隐私 / Configuration, lifecycle, privacy |
| [15](15-testing-build-release.md) | 测试、Harness、发布 / Tests, harness, release |
| [16](16-build-timearc-from-zero.md) | 从零制作顺序 / Build sequence from zero |
| [17](17-tradeoffs-and-evolution.md) | 架构取舍与演进 / Trade-offs and evolution |
| [18](18-interview-playbook.md) | 面试表达 / Interview playbook |
| [19](19-glossary-and-exercises.md) | 双语术语与练习 / Glossary and exercises |

## 每章怎么学 / How to study

1. 先用中文复述核心流程，不看英文。
2. 打开“源码入口”，找到类、函数或 QML 对象。
3. 用英文术语重新讲一次，但不要逐字翻译中文。
4. 回答章末问题；答不出时回到数据流，而不是背句子。
5. 最后用第 18 章录一段两分钟项目介绍。

## 事实来源 / Sources of truth

事实优先级为：当前源码与测试 → `.harness/CHARTER.md` → 根 `README.md` 与 `src/service/README.md` → 其他设计/报告文档。历史报告只说明当时发生过什么，不自动代表当前行为。

## 学完以后应该会什么 / Exit criteria

你应该能回答：为什么分两个进程？谁拥有哪一个数据库？一次前台观察如何变成统计卡片？Qt/C++ 对象怎样进入 QML？为什么媒体和前台时间不能直接相加？Windows、macOS、Android 的采集方式有什么差别？项目怎样验证并打包？
