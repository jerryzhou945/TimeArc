# 07 · 计时策略与状态机 / Tracking Policies and State Machines

## 本章目标 / Learning goals

理解“采到信号”不等于“应该计时”，以及状态机如何把瞬时观察变成连续区间。

## 1. Snapshot 与 session

Snapshot（快照）是某一轮看到的状态；session（会话）是多个连续、身份相同的快照形成的区间。

状态机需要回答三件事：何时开始、何时继续、何时关闭。它比“每秒插一行”更节省空间，也更接近用户理解的活动段。

## 2. 前台状态机

`TimeArcForegroundState` 有关闭、活跃和 idle 模式。每轮先推进上一段的时间，然后：

- 没有旧会话且有 app：开始。
- 完整应用观察身份变化：导出旧段并立即开始新段。
- 身份相同：更新最新观察。
- 有用户输入或 autonomous lease：进入 active。
- 否则进入 idle，但不关闭 session。

只有 active 模式增加 `active_ms`。

## 3. “身份相同”必须比较完整观察

仅比较 executable path 不够。标题或归因变化可能代表浏览器从一个站点切到另一个站点。项目使用规范化后的完整观察决定逻辑身份；字段变化形成边界。

## 4. Autonomous activity lease

视频播放、已识别游戏或 Agent 工作可提供 autonomous activity。为避免采样瞬间抖动，状态机给证据一个短 lease；lease 期间即使下一轮信号暂缺，活动也不会立即断裂。

Lease 不是无限后台计时，它有短期限且只服务明确白名单策略。

## 5. 媒体状态机

音频 tracker 同时维护多个 app session。每轮先把 `seen_this_poll` 清零，再标记本轮可靠观察到的会话：

- 新身份：开始 session。
- 已存在：刷新 observation。
- 采样成功但本轮消失：立即关闭，没有静默宽限。
- 采样失败：不因缺失而错误关闭已有会话。

这一区分非常重要：absence after a successful sample 是事实；absence caused by probe failure 不是事实。

## 6. 特殊策略 / Specialized policies

| 场景 | 继续依据 |
| --- | --- |
| 普通应用 | 前台 + 未超过 idle threshold |
| 浏览器视频 | 系统媒体 `Playing` 优先，必要时谨慎回退 |
| 音乐播放器 | 有效媒体/音频 session |
| Discord/KOOK/Oopz | 白名单语音 session Active 且未静音 |
| Codex | 前台身份 + 相关工作进程 CPU/I/O 增量 + 短 lease |
| 识别游戏 | 主进程在前台，可跨过键鼠 idle |

后台进程仅仅存在，永远不是充分条件。

## 7. 为什么前台和媒体不能直接相加

同一分钟里浏览器既在前台又播放视频。如果把两张表的 duration 求和，会得到两分钟。统计层应把区间做 union：先按开始时间排序，再合并重叠或相邻区间。

```text
foreground: [10:00, 10:10]
media:           [10:05, 10:15]
union:       [10:00, 10:15] = 15 min, not 20 min
```

## 8. 测试一个策略要覆盖什么

- start：证据出现能开始。
- continue：身份相同不会碎片化。
- stop/pause：证据消失能按规则结束。
- false positive：普通后台进程不会误记。
- deduplication：多信号不会重复累计。
- probe failure：观察失败不会被误认为状态消失。

## 面试表达 / Interview answer

“I modeled activity as state machines rather than periodic rows. Each policy defines valid evidence, logical identity, continuation, and termination. The read side unions overlapping intervals so multiple signals improve confidence without inflating time.”

## 源码入口 / Source entry points

- `src/service/windows/tracker/foreground_state.c`
- `src/service/windows/tracker/audio_tracker.c`
- `src/service/windows/platform/app_identity.c`
- `tests/windows_foreground_state_test.c`
- `tests/windows_audio_tracker_test.c`

## 复习题 / Review

1. 为什么探针失败时不能关闭媒体？——没有观察结果不等于确认媒体已停止。
2. lease 解决什么？——吸收短暂采样抖动，同时保持有限边界。
3. 区间并集解决什么？——防止同一真实活动被多个信号重复累计。
