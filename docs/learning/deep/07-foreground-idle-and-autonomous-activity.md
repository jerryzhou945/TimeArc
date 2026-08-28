# 07｜前台、空闲与自主活动：什么才算“有效使用”

> 本章目标：理解 TimeArc 不只判断“窗口在不在前台”，还要判断用户或应用是否真的活跃。
> English focus: **foreground app, input idle, autonomous activity, lease, effective time**.

## 1. 最简单的方案为什么不够

最幼稚的统计方式是：浏览器在前台十分钟，就记十分钟。但现实中：

- 用户可能离开电脑；
- 视频播放时用户没有键鼠输入，却仍在消费内容；
- 游戏手柄活动不一定更新传统键鼠 idle；
- Codex 在后台执行任务，窗口不在前台；
- 瞬间的 probe 抖动不应切碎 session。

所以 TimeArc 把“时间”拆成：

- `wall duration = end - start`：这段窗口身份持续多久；
- `active_ms`：其中真正有效的活跃时间；
- `idle_sec`：存储层可由两者推导的空闲时间。

## 2. 一份前台 sample

状态机的输入可以理解为：

```c
typedef struct {
  int has_app;
  AppInfo app;
  int input_active;
  int autonomous_active;
  int64_t wall_sec;
  uint64_t monotonic_ms;
} TimeArcForegroundSample;
```

字段语义：

- `has_app`：本轮是否成功取得前台 app；
- `app`：进程 id、路径、显示名、窗口标题等；
- `input_active`：键鼠空闲时间是否低于阈值；
- `autonomous_active`：即使没有键鼠输入，app 是否在做可计时工作；
- 两种 clock：分别服务于持久化和 duration。

## 3. 空闲检测

Windows 平台实现位于 `src/service/windows/platform/idle_win.c`。概念上它读取系统最后一次输入时间：

```text
idle_ms = current_tick - last_input_tick
input_active = idle_ms < configured_threshold
```

若阈值设为 0，当前实现将输入判断视为始终 active。这个边界值必须明确，否则“0”可能被不同人理解成“立即空闲”或“禁用空闲检测”。

## 4. ACTIVE 与 IDLE 不会自动结束 session

`foreground_state.c` 的状态包括：

```text
CLOSED  没有正在跟踪的前台 session
ACTIVE  有 session，本轮时间计入 active_ms
IDLE    仍是同一 session，但本轮不计 active_ms
```

最关键的设计是：**进入 IDLE 不代表关闭 session**。假设用户在 VS Code 中写代码五分钟，离开三分钟，又回来继续：

```text
session wall time:  8 min
active time:        5 min
idle time:          3 min
```

这样时间线仍显示一个连续的 VS Code 区间，同时统计服务可以使用真正 active duration。

## 5. `advance()` 如何累计

核心逻辑是：

```c
if (monotonic_ms >= state->last_monotonic_ms &&
    state->mode == TIMEARC_FOREGROUND_ACTIVE) {
  state->active_ms += monotonic_ms - state->last_monotonic_ms;
}
```

逐行解释：

1. 防止时间倒退造成无符号数下溢；
2. 只有“上一段状态是 ACTIVE”才累计；
3. 累加的是两次采样之间的间隔，而不是固定假设每轮正好一秒。

这让程序能承受 scheduler 延迟。例如一次轮询实际晚了 1.2 秒，它仍根据真实 elapsed time 计算。

## 6. app 切换如何结束旧 session

在 `timearc_foreground_state_step()` 中：

```c
advance(...);
if (sample->has_app &&
    !timearc_app_identity_equal(&state->app, &sample->app)) {
  export_closed(state, out_closed);
  start_session(state, sample);
  return 1;
}
```

返回 `1` 表示“产生了一条可持久化的 closed session”。状态机本身不写 SQLite，它只做纯状态转换；外层 tracker 收到结果后调用 `close_session()`。

这是 **separation of concerns（关注点分离）**：

- state machine 决定何时关闭；
- persistence adapter 决定怎样写库。

## 7. 什么是 autonomous activity

`autonomous_active` 用来表达“没有键鼠输入，但活动仍应计时”。当前 Windows 逻辑包含：

1. 前台进程 CPU/I/O counters 有有效增长；
2. 本轮确认该前台 app 正在输出音频；
3. 前台 executable 是已识别主游戏；
4. 对特定 Codex 工作进程，单独形成后台 agent session。

注意边界：不是看到进程存在就算 active。否则常驻后台应用会全天候制造假时间。

## 8. counters 为什么需要 delta

Windows 返回的是累计 CPU/I/O counters，例如：

```text
上次 CPU total = 10,000
本次 CPU total = 10,350
delta = 350 > threshold → 有活动
```

第一次采样只能建立 baseline，不能证明这段时间有活动；后续相同进程、相同路径的 counter 增长才有意义。这也解释了为什么 probe 是有状态对象。

## 9. lease 解决采样抖动

如果某一轮检测到视频播放，下一轮平台 API 短暂没返回，立刻从 ACTIVE 切到 IDLE 会造成碎片。TimeArc 使用 **activity lease（活动租约）**：

```c
if (sample->autonomous_active) {
  state->lease_until_ms = sample->monotonic_ms + state->lease_duration_ms;
}
state->mode = sample->input_active || lease_active
                  ? TIMEARC_FOREGROUND_ACTIVE
                  : TIMEARC_FOREGROUND_IDLE;
```

一次可靠的 autonomous signal 给未来一小段时间“续租”。租约不是永久豁免；没有新证据时会自然过期。

## 10. 游戏为什么有特殊策略

许多游戏：

- 使用手柄而不是键鼠；
- cutscene 或 loading 时 CPU/I/O 模式不稳定；

但不能把后台/最小化游戏算作前台游戏时间。因此策略是：只有识别出的主游戏 executable **同时处于 foreground** 时，前台 presence 可以作为 work signal。

这是一个业务 policy，而不是 Windows API 的天然事实。

## 11. Codex 后台工作为什么单独记录

Codex 可能在用户切到浏览器后继续执行构建或分析。当前实现缓存已识别的 Codex app，并对其进程 counters 单独采样。活动区间通过 `TimeArcAgentActivityState` 记录为 media contract 中的兼容类型，标题固定为 `Codex task`。

这里体现一个务实取舍：为了不立即扩张 on-disk enum，先复用稳定 contract 的 fallback 类型，再用固定标题表达语义。面试时应坦诚这是 **compatibility trade-off（兼容性折中）**，而不是声称数据模型完美。

## 12. 典型时间线推演

```text
10:00 VS Code 前台，键鼠 active
10:05 用户停止输入
10:07 CPU probe 无活动，lease 过期 → IDLE
10:09 用户继续输入 → ACTIVE
10:12 切换 Chrome → 导出 VS Code session
```

落盘结果概念上是：

```text
start = 10:00
end = 10:12
active = 10 min
idle = 2 min
```

不是三条 session，也不是简单的 12 分钟 active。

## 13. 面试表达

> Foreground presence alone is not equivalent to effective usage. We keep a continuous foreground session but separately accumulate active duration. Keyboard and mouse activity is one signal; verified audio, recognized foreground games, and process activity can also extend an activity lease. This preserves a readable timeline without overstating active time.

## 14. 本章练习

1. 为什么 IDLE 不关闭 session？列出优点和代价。
2. 第一次读取 CPU counter 为什么不能直接判定 active？
3. lease 太长或太短分别会产生什么错误？
4. 设计一个你认为合理的“视频会议 app 活跃策略”。

下一章：[音频与媒体追踪](08-audio-and-media-tracking.md)
