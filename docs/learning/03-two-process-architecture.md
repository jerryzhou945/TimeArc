# 03 · 双进程与一份磁盘契约 / Two Processes, One Disk Contract

## 本章目标 / Learning goals

掌握 TimeArc 最重要的架构决定，以及每个方向允许做什么、不允许做什么。

## 1. 两个进程 / Two processes

| 进程 | 技术 | 责任 |
| --- | --- | --- |
| `TimeArc` GUI | C++17 + Qt 6 + QML | 展示、查询、统计、设置、手动项目、移动功能 |
| `time-arc-service` | Windows C / macOS Swift | 观察系统活动、形成会话、写自动历史 |

一句话：**UI does not sample; the collector does not render.** UI 不采样，采集器不画界面。

## 2. 为什么不放在一个进程

- 用户关掉窗口后仍要继续采集。
- UI 崩溃、重载 QML 或切换页面不应切断会话。
- 原生平台 API 不应污染 GUI 依赖。
- 服务可以更小、更稳定，且不需要链接 Qt。
- 权限、启动和故障可以独立管理。

代价是必须定义稳定的进程边界和磁盘契约。

## 3. 允许的通信 / Allowed communication

```text
Operating-system signals
          |
          v
 native collector ------> timearc_service.db ------> C++ read layer ------> QML
          ^
          |
 service_config.json + service CLI
```

GUI 通过 CLI 请求服务启动/停止，并写受控配置文件。自动历史只从服务流向数据库，再流向 GUI。

macOS 允许服务实例之间用同用户 Unix socket 协调单实例和控制；这不改变 GUI 与服务之间“磁盘 + CLI”的边界。

## 4. 单向数据流 / Unidirectional data flow

采集事实的主方向是：producer → durable storage → consumer。

- Producer：原生服务。
- Durable storage：`timearc_service.db`。
- Consumer：Qt/C++ 只读仓储与统计层。

单向流减少循环依赖，也让问题定位更清楚：没采到看服务，写错看存储，显示错看查询或 QML。

## 5. 两个数据库不是一个数据库的两个名字

- `timearc_service.db`：服务拥有；自动应用与媒体历史；GUI 只读。
- `timearc.db`：GUI 拥有；设置、标签、手动项目、移动同步、UI 状态。

这叫 ownership boundary（所有权边界）。即使 SQLite 支持多个写连接，也不代表架构应该允许两个进程共同修改同一类事实。

## 6. 共享 C ABI / Shared C ABI

`src/service/shared/data_bridge.h` 声明 `update_apps`、`update_frontmost`、`update_media` 等稳定 C 函数。Windows C 直接调用；macOS Swift 通过 bridging header 和 `swift_name` 调用。

C ABI 的价值是名字修饰和调用约定稳定，避免把 C++ ABI 暴露给 Swift。

## 7. 平台隔离 / Platform isolation

- `src/service/windows/` 只在 Windows 构建。
- `src/service/macos/` 只在 Apple 平台构建。
- `src/service/linux/` 是当前占位实现。
- `src/service/shared/` 不得 include 平台专用头。

这是 dependency inversion 的朴素版本：共享层定义稳定能力，平台层提供观察实现。

## 8. 单实例 / Single instance

多个采集器同时写会造成重复会话。Windows 使用当前用户命名互斥量 `Local\TimeArcUsageService`；macOS 使用每用户文件锁，并验证控制通道对端身份。

## 9. 失败如何隔离

- GUI 打不开：服务仍可继续写历史。
- 服务不可用：GUI 仍可展示已有数据和手动功能。
- 配置损坏：读取器应使用安全默认值，而不是写坏数据库。
- 一次自动历史写入失败：应报告失败，不能假装部分成功。

## 面试表达 / Interview answer

“I separated collection from presentation. The native service is the sole writer of automatic history, and the Qt GUI is a read-side consumer. A versioned disk contract gives us crash isolation, simple debugging, and platform-specific collectors without linking native service code into the UI.”

## 源码入口 / Source entry points

- `.harness/CHARTER.md`
- `src/service/CMakeLists.txt`
- `src/service/shared/data_bridge.h`
- `src/service/shared/database_path.c`
- `src/main.cpp`

## 复习题 / Review

1. 为什么 GUI 不能写自动历史？——会破坏唯一写入者和事实所有权。
2. 为什么不用通用 IPC？——磁盘契约已提供持久、可检查、可恢复的低耦合边界。
3. 服务实例间 socket 是否违反架构？——不违反，它只用于服务自身协调，不是 UI 数据通道。
