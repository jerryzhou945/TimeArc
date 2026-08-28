# 06｜Windows 后台服务：从 `main()` 到每一次采样

> 本章目标：从进程入口开始，完整理解 Windows 采集器的生命周期。
> Source map: `src/service/windows/main.c`, `tracker/usage_tracker.c`, `service/win_service.c`.

## 1. 它是一个独立程序

`time-arc-service` 不是 GUI 中的一个线程，而是独立可执行文件。独立进程带来三个重要结果：

1. GUI 关闭后仍可记录；
2. 采集崩溃不会直接带崩 QML 界面；
3. 两个进程不能靠普通指针共享数据，只能通过稳定的磁盘契约通信。

这叫 **process isolation（进程隔离）**。

## 2. `main()` 做了什么

当前入口位于 `src/service/windows/main.c`。核心结构可以概括为：

```c
int main(int argc, char** argv) {
  if (argc >= 2) {
    return dispatch_verb(argc, argv);
  }

  SetConsoleCtrlHandler(console_handler, TRUE);
  HANDLE instance_mutex = CreateMutexA(NULL, TRUE,
                                       TIMEARC_INSTANCE_MUTEX_NAME);
  // ...防止重复实例...

  TimeArcUsageTrackerConfig config = {
      .poll_interval_ms = TIMEARC_USAGE_POLL_INTERVAL_MS,
      .idle_threshold_ms = TIMEARC_USAGE_IDLE_THRESHOLD_MS,
      .track_enabled = 1,
  };
  timearc_read_service_config(&config.idle_threshold_ms,
                              &config.track_enabled);
  return timearc_usage_tracker_run(&config);
}
```

逐段理解：

- `argc/argv`：操作系统传给程序的命令行参数；
- `dispatch_verb`：如果用户传了 `--start` 等参数，就执行生命周期命令；
- `SetConsoleCtrlHandler`：注册 Ctrl+C、关机等退出通知；
- `CreateMutexA`：创建系统级命名互斥量，保证只有一个 collector；
- `config`：先放安全默认值，再从文件覆盖合法字段；
- `timearc_usage_tracker_run`：真正进入采样循环。

## 3. 为什么同一可执行文件有多个 verb

`dispatch_verb()` 支持：

```text
--install    注册自动启动
--uninstall  取消注册
--start      启动用户会话中的采集器
--stop       请求干净停止
--status     查询状态
--status --json  输出机器可读状态
--run-service    运行服务生命周期入口
无参数       直接运行前台采集循环
```

这是一种轻量 **command-line interface（CLI）**。它让安装器、GUI、测试和人类都能操作同一个进程，而不必复制启动逻辑。

## 4. 为什么一定要单实例

如果同时运行两个 collector：

- 两者都看到同一个前台窗口；
- 两者都写入同一数据库；
- 同一段时间可能被记录两次；
- session 边界互相独立，结果难以修复。

命名 mutex 是 **single-instance guard（单实例保护）**。若 `GetLastError()` 返回 `ERROR_ALREADY_EXISTS`，新进程安静退出。

## 5. 默认配置再覆盖

程序不是先把结构体清零，然后完全相信配置文件。它先设置兼容默认值：

```c
TimeArcUsageTrackerConfig config = {
    .poll_interval_ms = TIMEARC_USAGE_POLL_INTERVAL_MS,
    .idle_threshold_ms = TIMEARC_USAGE_IDLE_THRESHOLD_MS,
    .track_enabled = 1,
};
```

这样即使 `service_config.json` 不存在或字段损坏，服务也有定义明确的行为。这叫 **fail-safe defaults（安全默认值）**。

当前 Windows reader 实际接入的是：

- `tracking.enabled`
- `tracking.frontmost.idle_threshold_sec`

不要因为配置模型中出现其他高级字段，就假设 Windows runtime 已经使用它们。阅读配置系统时必须区分 **declared（已声明）** 和 **wired（已接线）**。

## 6. 进入采样循环前的内存对象

`timearc_usage_tracker_run()` 创建：

- `TimeArcForegroundState`：当前前台 app session；
- `TimeArcProcessActivityProbe`：保存上次 CPU/I/O counters；
- `TimeArcAgentActivityState`：后台 Codex 工作 session；
- `TimeArcAudioTrackerState`：多 app 音频 session；
- named stop event：跨进程停止信号。

这些对象说明采集不是无状态函数，而是 **stateful polling system（有状态轮询系统）**。

## 7. 一次 while-loop 的完整顺序

`usage_tracker.c` 中每轮大致执行：

```text
读取当前墙上时间和单调时间
  ↓
独立采样音频 app
  ↓
读取前台窗口/进程/标题
  ↓
读取键鼠空闲时间
  ↓
比较 CPU/I/O counters，判断自主活动
  ↓
应用音频、游戏、Codex 特殊策略
  ↓
推进 agent state machine
  ↓
推进 foreground state machine
  ↓
必要时 checkpoint 到 SQLite
  ↓
等待 poll interval 或 stop event
```

音频先采样很重要，因为随后前台状态会询问：当前前台 app 是否也是本轮确认正在播放音频的 app。

## 8. 两种时间为什么同时存在

代码同时用：

- `unix_time_sec()`：**wall clock（墙上时间）**，用于数据库中的真实日期；
- `GetTickCount64()`：**monotonic clock（单调时钟）**，用于计算经过时长。

如果用户手动调整系统时间，wall clock 可能向前或向后跳；单调时钟只向前走，更适合计算 duration。成熟的追踪器通常需要同时保留两者。

面试表达：

> We use wall-clock timestamps for persistence and a monotonic clock for duration accounting, so clock adjustments do not directly corrupt active-time accumulation.

## 9. checkpoint 不是 session 结束

长时间使用同一个 app 时，不能等几个小时后才第一次写数据库。TimeArc 定期执行 checkpoint：

1. 导出当前区间；
2. 写入数据库；
3. 把内存 session 的 start 推到当前点；
4. 继续追踪同一个 app。

这降低了进程突然崩溃时可能丢失的数据量。它是 **durability vs write frequency（持久性与写入频率）** 的折中。

## 10. 干净退出

停止时不是直接结束进程，而是：

```c
timearc_foreground_state_shutdown(...);
timearc_audio_tracker_flush(...);
timearc_agent_activity_checkpoint(...);
timearc_audio_tracker_shutdown();
```

这称为 **graceful shutdown（优雅退出）**。没有它，内存中尚未 checkpoint 的最后一段使用记录会消失。

## 11. 失败怎么处理

采样系统必须允许局部失败：

- 获取前台 app 失败：本轮没有 app，但进程继续；
- 创建 stop event 失败：仍可依靠 console handler；
- 配置无效：保留默认值；
- 数据库写入失败：放弃该落盘动作，避免写半条记录；
- 音频 probe 失败：不能误判为“所有音频立即停止”。

这里体现 **fault containment（故障隔离）**：一个平台 API 的瞬时失败不应杀掉整个长期运行服务。

## 12. 面试表达

> The Windows collector is a single-instance native process. Its entry point handles lifecycle verbs, loads fail-safe configuration, and then runs a stateful polling loop. Each iteration samples audio, foreground identity, idle state, and process activity before advancing independent state machines. Sessions are persisted on transitions, checkpoints, and graceful shutdown.

追问“为什么不用 GUI 定时器？”：

> Collection must continue when the UI is closed, and platform probing should be isolated from rendering. A dedicated process gives us a clearer ownership boundary and better fault isolation.

## 13. 本章练习

1. 画出 `main()` 到 `timearc_usage_tracker_run()` 的调用路径。
2. 解释 mutex 和 stop event 的不同用途。
3. 如果删除 checkpoint，发生崩溃时最坏会丢失多少数据？
4. 为什么 duration 使用 monotonic clock，而数据库仍需要 wall clock？

下一章：[前台、空闲与自主活动](07-foreground-idle-and-autonomous-activity.md)
