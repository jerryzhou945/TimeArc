# 10｜跨平台后端：Windows、macOS、Android 与 Linux

> 本章目标：理解“同一个产品能力”怎样被拆成共享 contract、平台 probe 和平台生命周期。
> English focus: **platform abstraction, native API, parity, capability matrix, graceful degradation**.

## 1. 跨平台不等于所有代码相同

TimeArc 的界面主要使用 Qt/QML，但后台采集必须调用原生系统 API：

- Windows：Win32、WASAPI、process counters；
- macOS：AppKit/Accessibility、Swift runtime、LaunchAgent；
- Android：UsageStats、UsageEvents、WorkManager、JNI；
- Linux：目前只有 placeholder，不能描述成完整支持。

真正的跨平台架构不是消灭差异，而是把差异限制在清晰边界内。

## 2. 三层思考模型

```text
产品语义 Product semantics
  “前台 app session / media session / effective time”
                 ↓
共享磁盘契约 Shared disk contract
  apps / frontmost_sessions / media_sessions
                 ↓
平台实现 Platform implementation
  Win32 C / macOS Swift / Android Java+JNI
```

只要下层最后生成相同 contract，上层 GUI 就不必理解每个平台如何取得数据。

## 3. Windows：C + Win32 的模块边界

Windows 文件按责任拆分：

```text
windows/main.c                    进程入口和 CLI verbs
windows/service/win_service.c     生命周期、自动启动、stop/status
windows/tracker/usage_tracker.c   编排每轮采样
windows/tracker/foreground_state.c 纯前台状态机
windows/tracker/audio_tracker.c   音频 session 状态
windows/platform/active_app_win.c 前台窗口和进程 metadata
windows/platform/idle_win.c       键鼠空闲时间
windows/platform/audio_win.c      WASAPI probe
windows/platform/process_activity_win.c CPU/I/O 增量
```

`platform/` 负责“系统怎样告诉我”，`tracker/` 负责“这个信号在产品中是什么意思”。这一区分非常适合面试说明。

## 4. macOS：为什么采用 Swift

macOS service 位于 `src/service/macos/`，入口为 `TimeArcService.swift`。它拆成：

```text
CommandLine/      命令解析、帮助、退出码
Runtime/          进程锁、时钟、signal、run loop
Control/          本地 control socket、start/stop
Autostart/        LaunchAgent 注册与禁用
Configuration/   service_config.json 读取与路径
Diagnostics/     status 输出
Tracking/        app/audio/title/input probe 与状态机
```

为什么 Windows 是 C，macOS 是 Swift？跨平台项目不必强迫所有平台使用同一语言。Swift 更自然地接入现代 macOS frameworks；真正需要一致的是外部 contract 和产品 policy。

当前仓库有较完整的 macOS 实现与静态/烟雾测试，但发布结论仍要经过真实设备、权限和打包验证。文档必须区分：

- **implemented in source（源码已实现）**；
- **verified in release environment（发布环境已验证）**。

## 5. macOS 权限模型

macOS 获取窗口标题、输入状态或其他敏感信息时可能需要 Accessibility 等权限。`Tracking/AccessibilityRequest.swift` 表达请求流程。

权限被拒绝时应 **gracefully degrade（优雅降级）**：

- 不崩溃；
- 返回缺失 metadata 或较低能力；
- status/diagnostics 能说明原因；
- UI 不伪装成已经取得完整数据。

## 6. macOS 生命周期为何不是 Windows SCM 的复制

macOS 使用 LaunchAgent，Windows 则通过用户会话中的 service wrapper 和系统启动机制管理。平台生命周期机制不同，但上层目标一致：

- 用户能 enable/disable；
- 可查询 status；
- 防止重复实例；
- stop 时能 flush；
- GUI 打开不偷偷破坏用户显式设置。

抽象应该统一 **capability（能力）**，而不是统一每一个原生 API 调用。

## 7. Android：它不是桌面 service 的直接移植

Android 受后台执行、电池和权限限制，不能长期运行桌面式高频轮询。当前路径大致是：

```text
Android UsageStats / UsageEvents
          ↓ Java
WorkManager 周期或即时同步
          ↓ JNI
android_usage_jni_bridge.cpp
          ↓ C++
MobileUsageRepository
          ↓
MobileUsageService / MobileUiService
          ↓ context properties
Mobile QML pages
```

Android 统计是 OS 提供的历史事件/聚合读取，而不是 Windows foreground poll 的等价实现。因此数据精度、刷新频率、权限提示都不同。

## 8. JNI 是什么

**JNI — Java Native Interface** 让 Java/Kotlin 和 C/C++ 互相调用。这里它是翻译边界：

- Java 更适合调用 Android framework；
- C++ repository/service 更适合接入现有 Qt 应用层；
- JNI 将字符串、时间和列表在两种 runtime 之间转换。

JNI 常见风险：线程附着、local reference 泄漏、字符串编码、异常未清理、method signature 不匹配。因此项目同时需要 Java 侧和 C++ 侧的静态验证。

## 9. Linux placeholder 的诚实表达

`src/service/linux/main.c` 存在不等于 Linux 已实现完整采集。它目前是占位边界。面试中正确说法：

> The architecture reserves a Linux backend, but production-grade Linux collection is not implemented yet.

不要说“四端完全支持”。**Scope honesty（范围诚实）** 比夸大功能更专业。

## 10. parity 不等于逐行相同

可以建立 capability matrix：

| Capability | Windows | macOS | Android | Linux |
|---|---|---|---|---|
| 前台 app 历史 | 原生轮询 | 原生 probe/state machine | UsageEvents | placeholder |
| 输入空闲 | Win32 | macOS input probe | 不同语义 | placeholder |
| 音频 app | WASAPI | audio process probe | 当前非同等能力 | placeholder |
| 自动启动 | Windows wrapper | LaunchAgent | WorkManager/系统调度 | placeholder |
| GUI | Qt/QML desktop | Qt/QML desktop | Qt/QML mobile | 架构预留 |

矩阵里的“不同语义”比硬写一个勾更准确。

## 11. 添加新平台应从哪里开始

推荐顺序：

1. 明确该平台允许获取哪些信号；
2. 定义 capability gaps；
3. 复用 `apps/frontmost_sessions/media_sessions` contract；
4. 实现路径、生命周期和权限；
5. 将原生信号归一化为状态机 sample；
6. 用 deterministic state-machine tests 验证 policy；
7. 再做真实设备验证与 packaging。

## 12. 面试表达

> We standardize product semantics and the persisted contract, not every platform call. Windows uses a C collector around Win32 and WASAPI, macOS uses a modular Swift service and LaunchAgent lifecycle, and Android reads system usage history through Java and bridges it into the Qt layer through JNI. Unsupported capabilities degrade explicitly instead of being hidden.

## 13. 本章练习

1. 为什么“使用 Qt”不能自动解决后台采集的跨平台差异？
2. 写出 platform probe 与 tracker policy 的区别。
3. 为 Linux 后端列出至少四个必须先调查的问题。
4. 解释 implemented 与 release-verified 的差别。

下一章：[SQLite 双数据库契约](11-storage-contract.md)
