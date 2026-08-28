# 08 · 平台实现 / Platform Implementations

## 本章目标 / Learning goals

理解共享产品语义如何映射到不同操作系统 API，并准确描述各平台当前成熟度。

## 1. 共享的是契约，不是所有采集代码

各操作系统提供完全不同的窗口、idle、媒体和后台机制。TimeArc 共享 SQLite schema、C ABI 和高层语义，但允许平台层使用最合适的原生语言。

**Interview English:** “The project shares contracts and semantics across platforms, while keeping operating-system probes native and isolated.”

## 2. Windows：主要测试平台

Windows collector 使用 C：

- Win32/PSAPI 获取前台窗口、进程和路径。
- `GetLastInputInfo` 计算 idle。
- WASAPI/COM 与 GSMTC 证据识别媒体和语音。
- 进程计数器支持受限的 Agent 活动策略。
- 命名 mutex 和 event 管理单实例与停止。
- GUI 通过 service CLI 管理当前用户会话采集和登录自启。

这是当前端到端最完整、最适合面试深挖的平台。

## 3. macOS：Swift 原生服务

macOS 目录按职责拆为：

- `CommandLine/`：命令解析与退出码。
- `Runtime/`：时钟、循环、信号、单实例。
- `Control/`：同服务实例间的受限 Unix socket 控制。
- `Autostart/`：LaunchAgent enable/disable。
- `Diagnostics/`：status/doctor 输出。
- `Tracking/`：Accessibility、应用、输入、媒体和状态机。

Swift 通过 `DataBridge.swift` 调 C ABI 写相同服务数据库。代码已实现，但签名、公证、权限引导和长时间实机回归仍是发布门槛。

## 4. Android：不同的数据入口

Android 不运行桌面 collector。Java 层通过 UsageStats/UsageEvents 读取系统授权的应用使用数据：

```text
Usage Access permission
 -> UsageEventsReader / UsageStatsReader
 -> UsageSyncWorker
 -> AndroidUsageNativeBridge (JNI)
 -> MobileUsageRepository / MobileUsageService
 -> mobile QML
```

WorkManager 负责后台同步，Activity 和 `MobileUiBridge` 处理生命周期、系统栏与分享等移动能力。不同 ROM 对权限和后台限制不同，所以仍需设备矩阵验证。

## 5. Linux：不要把占位说成完成

`src/service/linux/main.c` 只表示构建结构预留。X11/Wayland 前台识别与 PipeWire 媒体采集尚未实现。

面试中应说“the architecture reserves a Linux backend”而不是“Linux is supported”。

## 6. 平台抽象的设计原则

- 平台 SDK 类型不能进入 `shared/*.h`。
- 上层只依赖规范化的 app/media/session 数据。
- 各平台应遵守相同身份、时间区间、唯一写入者和隐私语义。
- “功能代码存在”与“发布验证完成”是两个状态。

## 7. 为什么不用一种语言写全部平台

一种语言表面统一，但会引入复杂绑定或不自然 API。当前选择把复杂度限制在清晰边界：Windows C 接近 C ABI 与 Win32；macOS Swift 接近 Apple frameworks；Android Java 接近系统权限与 WorkManager；Qt/C++/QML 共享展示层。

## 源码入口 / Source entry points

- `src/service/windows/`
- `src/service/macos/`
- `src/service/linux/main.c`
- `android/src/main/java/com/timearc/mobile/usage/`
- `src/services/mobile/`
- `android/README.md`

## 复习题 / Review

1. macOS 为什么用 Swift？——自然访问 Apple frameworks，同时通过 C ABI 复用存储契约。
2. Android 为什么不复用桌面服务？——系统提供不同权限、生命周期和 Usage API 模型。
3. 如何准确描述 Linux？——架构占位，采集尚未实现。
