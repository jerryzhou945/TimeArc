# 18 · 面试表达手册 / Interview Playbook

## 1. 30 秒版本 / 30-second pitch

### 中文

TimeArc 是我制作的一款本地优先跨平台时间记录应用。它用独立原生服务采集前台应用和有效媒体活动，写入服务独占的 SQLite；Qt/C++ 只读并聚合这些区间，QML 展示日周月年统计和时间回顾。最难的部分是准确定义活动语义、避免重叠计时，以及在跨平台实现中守住隐私边界。

### English

“TimeArc is a local-first, cross-platform time-tracking application I built with Qt 6 and QML. A separate native collector records foreground and validated media activity into a service-owned SQLite database. The C++ read layer aggregates those intervals, and QML presents timelines and reports. The hardest parts were reliable activity semantics, overlap deduplication, and privacy-preserving platform integration.”

## 2. 两分钟版本 / Two-minute explanation

### 中文结构

1. 问题：主动计时无法还原真实数字生活。
2. 架构：GUI 与 collector 两进程，磁盘契约解耦。
3. 采集：Windows C 状态机组合前台、idle、媒体和受限特殊策略。
4. 数据：服务独占 `timearc_service.db`；GUI 的 `timearc.db` 存设置和手动/移动数据。
5. 展示：Repository/Service/Manager → Qt meta-object → QML。
6. 正确性：区间裁剪和并集避免重复，Harness 与多层测试守契约。
7. 反思：跨语言和 schema 演进是代价，但换来隔离与原生能力。

### English model answer

“I started with the problem of reconstructing a trustworthy activity timeline without collecting private content. I split the desktop system into a Qt/QML GUI and a native collector. On Windows, the collector is written in C and samples foreground windows, user idle state, media sessions, and a few explicitly approved autonomous-activity policies. State machines convert noisy snapshots into intervals.

“The collector is the sole writer of `timearc_service.db`; the GUI opens it read-only. A second database, `timearc.db`, belongs to the GUI and stores settings, manual projects, and mobile synchronization data. C++ repositories and services clip and union intervals, then expose `QVariant` view models to QML through Qt’s meta-object system.

“The design improves crash isolation and keeps platform APIs out of the UI, but it requires strict schema ownership and multi-language testing. I use focused state-machine tests, SQLite smoke tests, QML/static checks, and a repository harness that records failures and protects frozen contracts.”

## 3. 为什么两个进程？ / Why two processes?

“Collection must survive window closure and UI failures. Separating it also keeps Win32 and Apple frameworks out of the Qt presentation process. The cost is a versioned boundary, which I make explicit through SQLite ownership, a C ABI, configuration files, and CLI lifecycle commands.”

若被问为什么不用 socket：当前数据要持久化、频率低，SQLite 已是事实源；通用 RPC 会扩大同步和版本面。macOS 服务实例间的窄控制 socket 是服务自身协调，不是 GUI 数据通道。

## 4. 如何避免重复计时？ / How do you avoid double counting?

“Foreground and media are independent evidence streams. I clip both to the requested calendar range, group by stable identity, sort intervals, and merge overlaps before summing. A ten-minute foreground browser session overlapping ten minutes of playback is still ten minutes of active coverage.”

## 5. Idle 怎么处理？ / How is idle handled?

“Idle does not necessarily close the foreground session. It pauses `active_sec`, so the stored row preserves wall-clock continuity and derives `idle_sec`. Explicit policies such as validated video playback, a foreground game, or a short Agent work lease may override keyboard-and-mouse idle.”

## 6. 数据库为什么分两份？ / Why two databases?

“The split follows ownership, not performance. Automatic history is collector-owned and read-only to the GUI. Settings, tags, manual projects, and mobile synchronization are GUI-owned. This prevents two processes from becoming competing writers of the same facts.”

## 7. 如何跨平台？ / How is it cross-platform?

“I share normalized contracts and timing semantics, but keep probes native: C with Win32/WASAPI on Windows, Swift with Apple frameworks on macOS, and Java plus JNI for Android Usage APIs. Linux is an architectural placeholder, not a completed backend.”

## 8. STAR 技术挑战示范

- Situation：多个信号重叠、idle 和媒体使统计不可信。
- Task：定义不会重复、不会无限后台计时的语义。
- Action：建立 snapshot → state machine → session → interval union；补开始、持续、停止、失败和去重测试。
- Result：“The result was a testable evidence pipeline where new policies can add confidence without changing the storage schema or inflating totals.”

## 9. 高频问题 / Common questions

### Why Qt and QML?

“Qt provides a mature cross-platform runtime, SQLite integration, and a meta-object bridge to QML. QML lets me iterate on desktop/mobile presentation while keeping database and aggregation logic testable in C++.”

### What would you improve next?

“I would prioritize release validation and contract tests: finish macOS signing and permission QA, expand Android device coverage, complete service-config wiring, and add shared behavioral vectors for collector state machines.”

### How do you protect privacy?

“The collector stores activity metadata, not content. It avoids chat bodies, screenshots, OCR, raw audio, and default browser-history capture. Sharing starts from an anonymized derived model, and raw history remains local.”

### What did you personally design?

只列你确实完成的部分，用 “I designed… / I implemented… / I integrated… / I validated…” 分清角色和证据，不把仓库中所有贡献都冒充个人完成。

## 10. 简历项目描述 / Resume bullets

- Built a local-first Qt 6/QML activity timeline with separate native collectors and a service-owned SQLite contract.
- Designed state-machine-based foreground/media tracking and interval-union aggregation to prevent double counting.
- Integrated Win32, WASAPI/COM, Swift/Apple frameworks, and Android Usage APIs behind platform-isolated boundaries.
- Added layered C++ repositories/services, reactive QML view models, and automated state, database, UI, and packaging checks.

## 11. 不要说错 / Claims to avoid

- 不说 Linux 已支持。
- 不说 macOS 已完成公开发行验证。
- 不说 AI 分析所有原始日志。
- 不说后台进程存在就会计时。
- 不把 `timearc.db` 和 `timearc_service.db` 混为一谈。
- 不只讲技术清单；要讲问题、选择、代价和验证。
