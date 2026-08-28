# 06 · Windows 原生采集服务 / Windows Native Collector

## 本章目标 / Learning goals

追踪 Windows 上一次轮询如何收集前台、idle、进程活动和音频证据，并最终写入 SQLite。

## 1. 主循环骨架 / Sampling loop

`timearc_usage_tracker_run()` 初始化状态机后循环执行：

```text
read wall clock
poll audio sessions
probe foreground app
measure user idle
sample selected process activity
apply game/media/Agent policy
advance state machines
checkpoint long sessions
wait for poll interval or stop event
```

默认 poll period 由常量提供；当前 Windows 配置 reader 已接入总开关和 idle threshold，高级 sampling 叶子尚未全部接线。

## 2. 前台窗口探针

`active_app_win.c` 从 `GetForegroundWindow` 开始：窗口 → PID → 进程句柄 → executable path → title/name，最后填充 `AppInfo`。

Windows 字符串多为 UTF-16，落盘契约使用 UTF-8，因此平台层承担转换责任。失败时返回非零，tracker 把本轮视作没有可靠前台观察。

## 3. Idle 不是“没有前台应用”

`idle_win.c` 使用 `GetLastInputInfo` 计算距最近键鼠输入的毫秒数。前台应用仍然存在，只是状态机暂停 `active_ms` 的增长。

因此一个 session 可以跨越 idle：墙钟跨度 `duration_sec` 不变，真正活跃值由 `active_sec` 表示，`idle_sec = duration_sec - active_sec`。

## 4. 音频探针

`audio_win.c` 使用 Windows 音频会话 API（WASAPI/COM）枚举音频会话，并结合 GSMTC 媒体状态、会话活跃状态、静音状态、进程身份和前台标题判断是否应记录。

系统媒体状态 `Playing` 比单纯音量峰值更可信；拿不到状态时才允许有限回退。Wallpaper Engine 等装饰性音频被过滤。

## 5. 进程活动证据

普通后台进程的 CPU/I/O 变化不代表用户活动，因此不能通用记录。`process_activity_win.c` 只为明确策略采样相关进程树，例如前台 Codex 的工作进程。

**Interview English:** “Process existence and generic CPU activity were intentionally rejected as activity evidence because they create systematic false positives.”

## 6. 从观察到写盘

前台会话关闭时：

1. 丢弃零秒或无身份的抖动段。
2. `update_apps()` upsert 应用身份。
3. `update_frontmost()` 插入前台会话。

音频会话类似：先更新 app，再 `update_media()`。`data_bridge.c` 把同一逻辑包进事务，使身份和会话成为一次原子写入。

## 7. Checkpoint 的意义

长会话如果只在最终结束时写盘，崩溃会丢失很长一段数据。tracker 定期 checkpoint：关闭一个可持久化片段，然后从同一逻辑状态继续。

Checkpoint 改变物理行分段，不改变逻辑活动身份。统计层必须能合并相邻或重叠区间。

## 8. 资源与错误处理

C 代码必须显式处理：Windows HANDLE、COM 初始化与 Release、SQLite statement finalize、堆缓冲区、stop event。失败时宁可跳过不可靠观察，也不能制造虚假历史。

## 源码入口 / Source entry points

- `src/service/windows/tracker/usage_tracker.c`
- `src/service/windows/platform/active_app_win.c`
- `src/service/windows/platform/idle_win.c`
- `src/service/windows/platform/audio_win.c`
- `src/service/windows/platform/process_activity_win.c`
- `src/service/shared/data_bridge.c`

## 复习题 / Review

1. 为什么 wall clock 和 monotonic clock 都要用？——前者落盘表示真实时间，后者安全计算经过时长，避免系统时间调整影响。
2. 为什么音频独立于键鼠 idle？——播放活动可以在用户不操作键鼠时仍然有效。
3. checkpoint 会不会重复统计？——物理行可能相邻，读层通过区间合并避免重复。
