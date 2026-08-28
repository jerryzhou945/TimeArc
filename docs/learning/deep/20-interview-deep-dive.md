# 20｜面试深度表达：从 30 秒介绍到系统设计追问

> 本章目标：把“我看懂代码”转化为“我能清楚说明问题、设计、取舍、证据和不足”。
> 建议：不要背全文；先用中文理解，再用英文关键词建立自己的句子。

## 1. 30 秒中文版本

> TimeArc 是一个 Qt6/QML 的跨平台时间追踪应用。它把系统采集和界面拆成两个独立进程：原生后台服务负责读取前台应用、空闲、音频和部分自主活动，并作为唯一 writer 写入 `timearc_service.db`；GUI 只读这份 journal，再通过 repository 和 service 聚合成时间线、排名和覆盖时长。GUI 另有 `timearc.db` 保存设置、标签和手动项目，避免所有权混乱。

## 2. 30 秒英文版本

> TimeArc is a cross-platform time-tracking application built with Qt 6 and QML. It separates collection from presentation into two processes. A native background collector samples foreground applications, idle state, audio, and selected autonomous activity, and is the sole writer of a SQLite journal. The GUI reads that journal through repositories and services, while a separate GUI-owned database stores settings, tags, and manual projects.

## 3. 两分钟架构版本

可以按五层讲：

1. **Platform probes** — Win32/WASAPI, macOS frameworks, Android UsageStats；
2. **State machines** — samples 转成 foreground/media/agent intervals；
3. **Persistence contract** — constrained SQLite, single writer, read-only GUI；
4. **Application layer** — DatabaseManager, repositories, services, managers；
5. **Presentation** — Qt meta-object bridge and desktop/mobile QML shells。

英文串联：

> Native probes produce timestamped samples. Pure state machines turn those snapshots into intervals, and the collector persists them through a constrained SQLite schema. The Qt application opens the journal read-only, hides SQL behind repositories, combines metrics in services, and exposes selected QObject APIs to desktop and mobile QML shells.

## 4. 追问：为什么两个进程

中文回答要点：

- GUI 关闭仍追踪；
- 平台采集和 rendering 故障隔离；
- 生命周期独立；
- 代价是需要 IPC/disk contract、single writer 和配置同步。

English:

> The main reason is lifecycle independence: collection must continue after the window closes. Process isolation also contains platform-probing failures. The trade-off is that we need an explicit cross-process contract and cannot share in-memory objects.

## 5. 追问：为什么 SQLite，不继续 JSONL

> SQLite gives us schema constraints, indexed range queries, generated duration columns, transactions, and duplicate suppression. JSONL was useful for an early append-only prototype, but it became awkward for long-term aggregation and multi-process read access.

不要否定 prototype；要解释需求成长后为什么迁移。

## 6. 追问：怎样判断有效时间

> We separate wall duration from accumulated active duration. Input activity is one signal, but verified foreground audio, recognized foreground games, and process activity can extend a short lease. Idle does not necessarily close the app session, so the timeline stays continuous while statistics use effective active seconds.

随后举一个 8 分钟 VS Code、其中 3 分钟 idle 的例子。

## 7. 追问：怎样避免重复计算

分两类回答：

- persistence duplicate：unique session indexes + `INSERT OR IGNORE`；
- metric overlap：clip intervals, sort, merge union，不直接相加 foreground/media。

这展示你知道“重复行”和“时间重叠”是两个不同问题。

## 8. 追问：为什么 wall clock + monotonic clock

> Wall-clock time is necessary for calendar queries and persisted timestamps, while monotonic time is safer for elapsed-duration accounting because it is not affected by normal system-clock adjustments.

## 9. 追问：怎样处理平台 API 失败

用音频例子：

> A successful probe with an empty result is evidence that playback stopped; a failed probe is uncertainty. We keep the existing session on transient failure instead of closing everything. This distinction reduces fragmentation, although a prolonged failure may slightly overestimate the tail and could be bounded by a future timeout.

最后一句主动说明 trade-off，可信度更高。

## 10. 追问：Qt C++ 怎样连接 QML

> `main.cpp` acts as the composition root. It creates repositories, services, and managers, then exposes selected QObject instances as context properties. QML calls invokables and binds to properties with notify signals. The QML engine loads the packaged `time_arc` module from the Qt resource system.

## 11. 追问：移动端为什么不同

> Android background execution is constrained, so we cannot reuse the desktop polling loop. Java reads UsageStats and UsageEvents, WorkManager schedules refreshes, JNI bridges normalized records into C++, and the mobile shell presents permission and data-freshness state explicitly.

## 12. 追问：最难的 bug 会在哪里

可选一个深入：

### 状态机边界

App 切换点 elapsed 归属、checkpoint、shutdown flush、lease expiry。

### 跨进程路径

GUI 与 service 指向不同 DB 会形成 split brain；用固定 control-file location 和原子 read-modify-write 避免。

### Memo 异步恢复

图片 callback ownership 错误可能重绘旧页，形成 ghost ink；用一次性 pending URL 分离 restore 与 stamp requests。

回答结构：symptom → root cause → invariant → fix → regression evidence。

## 13. 追问：怎样测试

> Pure C state machines have deterministic unit tests with synthetic timestamps. Repositories and resources have smoke tests, and Python static tests protect platform wiring and packaging manifests. A release check also includes the common build wrapper, runtime Qt log scanning, and artifact-level installation checks on the target platform.

不要声称没有执行过的真机测试。

## 14. 追问：你会怎样改进

好的改进必须基于现有限制：

- stronger crash recovery/idempotency key；
- batch transaction for app+session writes；
- typed QML view models instead of many global context properties；
- database retention/compaction；
- explicit maximum uncertainty for prolonged probe failures；
- Linux backend and platform capability diagnostics；
- sync conflict policy and privacy controls；
- memo incremental stroke storage to reduce snapshot memory。

不要随口说“上微服务、上云、上 AI”，除非能说明问题和代价。

## 15. STAR 项目故事模板

### Situation

> I needed a time tracker that continued collecting after the UI closed and could distinguish foreground presence from effective use.

### Task

> I had to design a cross-platform boundary that remained queryable, testable, and privacy-aware.

### Action

> I separated the native collector from the Qt UI, modeled activity with deterministic state machines, introduced a single-writer SQLite contract, and layered the GUI into repositories, services, QObject managers, and QML shells.

### Result

只讲你能用证据支持的结果，例如测试覆盖的边界、能够从 service DB 展示的页面、安装包验证或性能测量。不要编造用户数或百分比。

## 16. 术语发音与搭配

| 中文 | 英文表达 | 常用搭配 |
|---|---|---|
| 前台应用 | foreground application | sample the foreground application |
| 空闲阈值 | idle threshold | configurable idle threshold |
| 单调时钟 | monotonic clock | measure elapsed time with a monotonic clock |
| 状态转换 | state transition | deterministic state transition |
| 活动租约 | activity lease | renew/expire an activity lease |
| 优雅退出 | graceful shutdown | flush sessions during graceful shutdown |
| 唯一写入者 | sole writer | the collector is the sole writer |
| 只读连接 | read-only connection | enforce a read-only connection |
| 区间并集 | interval union | merge overlapping intervals |
| 构造函数注入 | constructor injection | inject repositories through constructors |
| 优雅降级 | graceful degradation | degrade gracefully when permission is denied |
| 装配根 | composition root | main.cpp is the composition root |

## 17. 面试禁区

不要说：

- “所有平台完全一样”；
- “Qt 自动处理了全部跨平台问题”；
- “GUI 和 service 共用一个可写数据库”；
- “没有键鼠输入就一定是 idle”；
- “把所有时长加起来就是总使用时间”；
- “测试通过所以绝对没有 bug”；
- “Linux 已完成”或“macOS 已发布验证”，除非当时确有证据。

## 18. 本章练习与自测问题

如果能不看文档回答下面问题，就已形成整体模型：

1. 两个进程各自拥有何种生命周期？
2. 两个 SQLite 文件分别由谁写？
3. sample 怎样变成 interval？
4. idle 为什么不关闭 session？
5. audio probe 失败怎样处理？
6. coverage 为什么要 union？
7. C++ 对象怎样暴露到 QML？
8. Android 为什么使用 UsageStats + WorkManager？
9. Memo 为什么分三层？
10. 从源码到 release 需要哪些证据？

## 19. 最后的学习方法

对每一章做三遍：

1. **Explain in Chinese**：不看术语，用生活语言说明；
2. **Trace the source**：打开本章 Source map，找到入口、状态和输出；
3. **Explain in English**：用 3–5 个关键词说 60 秒。

你不需要背每一行代码。真正要掌握的是：某段代码解决什么问题、为什么放在这一层、有哪些不变量、失败时怎样表现、你用什么证据知道它正确。

返回：[深度教材目录](00-README.md) · [简明手册目录](../00-README.md)
