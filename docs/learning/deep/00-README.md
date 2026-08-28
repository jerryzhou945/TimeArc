# TimeArc 源码精读教科书 / Source-guided Textbook

这部分不是速查表，而是面向零基础读者的长篇课程。建议一边打开源码一边阅读。每个代码片段都来自当前仓库；为了教学可能省略无关分支，但不会用旧接口冒充现状。

## 阅读方法

每章固定回答八个问题：

1. 这个模块在整个系统里负责什么？
2. 初学者需要先懂哪些语言或框架概念？
3. 程序从哪个函数进入？
4. 参数、返回值和成员变量分别代表什么？
5. 数据在执行前后怎样变化？
6. 为什么选择这种设计而不是更直观的写法？
7. 出错时怎样处理，测试怎样证明？
8. 面试中怎样用英文说明？

## 深读目录

### 语言与构建地基

- [01 · C 语言：读懂原生服务](01-c-foundations.md)
- [02 · C++ 与 Qt 对象模型](02-cpp-qt-foundations.md)
- [03 · QML 与 Qt Quick](03-qml-foundations.md)
- [04 · CMake 装配图](04-cmake-walkthrough.md)
- [05 · Harness 工程纪律](05-harness-and-safe-workflow.md)

### 原生采集服务

- [06 · Windows 服务入口与主循环](06-windows-service-loop.md)
- [07 · 前台窗口、进程和 Idle 探针](07-foreground-idle-and-autonomous-activity.md)
- [08 · WASAPI、COM 与媒体策略](08-audio-and-media-tracking.md)
- [09 · 前台与媒体状态机](09-state-machines-by-example.md)
- [10 · macOS Swift 与 Android Java/JNI](10-platform-backends.md)

### 数据与应用层

- [11 · C ABI、SQLite DDL 与事务](11-storage-contract.md)
- [12 · GUI 数据库与 Repository](12-gui-database-and-repositories.md)
- [13 · Service、Manager 与统计算法](13-services-managers-and-stats.md)
- [14 · main.cpp 与 QML 桥接](14-main-and-qml-bridge.md)

### 界面、质量与面试

- [15 · 桌面 Shell、页面与组件](15-desktop-qml.md)
- [16 · 移动 Shell、Android 权限与同步](16-mobile-android.md)
- [17 · 备忘黑板、Canvas 与持久化](17-memo-canvas.md)
- [18 · 测试、构建与发行](18-testing-build-release.md)
- [19 · 从需求到成品的开发复盘](19-development-story.md)
- [20 · 面试深挖题与英文回答](20-interview-deep-dive.md)

## 版本警告

旧版 `C:\TimeArc\learning\learning` 很适合学习写法，但其中的 JSONL、实时 JSON 快照、`usage_config.json`、共享写 `timearc.db`、macOS “只有原语没有主循环”等描述已经过期。当前教材只保留其教学结构，不沿用旧事实。

如果你想先建立全局地图，再回来逐行深读，可先看[简明学习手册](../00-README.md)。
