# 19｜从零制作 TimeArc：按可交付阶段重建开发过程

> 本章目标：把前面分散的技术重新排成一条“如果从零开始，我会怎样做”的产品开发路线。
> English focus: **vertical slice, milestone, risk-first development, evolutionary architecture**.

## 1. 不要从漂亮首页开始

TimeArc 最难的风险不是卡片颜色，而是：

- OS 能否可靠提供 activity signal；
- 两个进程如何避免冲突；
- interval 怎样定义；
- 崩溃/关机时怎样减少丢失；
- 长期数据库怎样查询。

正确顺序应先验证高风险核心，再逐渐做完整产品。

## 2. Milestone 0：写清产品语义

先回答：

- 什么叫 frontmost？
- idle 是否结束 session？
- 视频无输入算不算 active？
- 同时前台和音频怎样计算 coverage？
- 用户可以暂停追踪吗？
- 哪些 metadata 属于隐私？

这一步输出 domain glossary 和最小 acceptance scenarios。没有语义，代码只能把不确定性藏起来。

## 3. Milestone 1：做一个最小平台 probe

Windows prototype 只需打印：

```text
timestamp, process_id, executable_path, app_name, window_title, idle_ms
```

目标不是发布，而是验证 Win32 API、权限和 identity。不要立刻接 UI。

## 4. Milestone 2：把 probe 与状态机分开

定义普通 sample struct，编写 pure state machine：

```text
sample sequence → closed session sequence
```

先用 deterministic tests 覆盖切换、idle、checkpoint、shutdown。这样后面改平台 probe 不会重写 session policy。

## 5. Milestone 3：建立 SQLite contract

设计 `apps/frontmost_sessions/media_sessions`：

- 明确 unit（Unix seconds）；
- constraints 拒绝无效 interval；
- generated durations；
- indexes 支持 range query；
- schema version；
- unique keys/dedup；
- writer ownership。

再把 state-machine output 持久化。此时用 CLI/SQLite query 就能证明核心价值。

## 6. Milestone 4：独立 service lifecycle

加入：

- single-instance mutex/lock；
- start/stop/status；
- signal/console handler；
- graceful flush；
- autostart；
- config safe defaults；
- diagnostics。

这时 collector 才从 prototype 变成可长期运行的系统组件。

## 7. Milestone 5：建立最薄 GUI read path

用 Qt 创建：

```text
DatabaseManager → read-only connection
FrontmostSessionRepository → today query
StatsService → formatted summary
main.cpp → context property
QML → 一个 Text/列表
```

这是第一个 **vertical slice（垂直切片）**：从磁盘到用户可见结果整条链路都通了。

## 8. Milestone 6：GUI 私有数据库

加入 settings、manual project、tags 等用户数据，但保持与 service journal 分离。定义 migration 和 test isolation。

此时需要明确：

- 自动记录由 service owning；
- 用户编辑数据由 GUI owning；
- 设置若影响 service，则经 versioned control file/CLI 协调。

## 9. Milestone 7：产品化桌面 Shell

按顺序实现：

1. root window 与 platform chrome；
2. navigation shell；
3. home summary；
4. timeline/calendar；
5. stats/ranking；
6. settings；
7. timer/project；
8. tray/menu bar 生命周期。

每一页都走 repository/service，不让 SQL 混入 QML。

## 10. Milestone 8：丰富 activity signals

在最小 foreground+idle 正确之后，再逐步加：

- audio tracker；
- media metadata/title adapters；
- game policy；
- process counters；
- autonomous activity lease；
- background agent session。

每加一种 signal 都先定义 false positive / false negative 和 failure semantics。

## 11. Milestone 9：跨平台

先冻结共享 product semantics 和 disk contract，再分别实现：

- macOS Swift service + LaunchAgent + permission；
- Android UsageStats + JNI + mobile shell；
- Linux capability investigation。

不是复制 Windows 源码，而是实现相同外部语义的 platform adapter。

## 12. Milestone 10：Memory Lake 与 Memo

视觉和创作功能建立在稳定数据/窗口 shell 之上。Memo 本身再切 vertical slices：

1. overlay + background；
2. pen/eraser；
3. save/load；
4. notes/text；
5. multipage；
6. selection/clipboard；
7. undo/redo；
8. lifecycle flush。

## 13. Milestone 11：release hardening

最后不是“点一下 build”：

- test matrix；
- resource manifest；
- runtime log；
- installer/app bundle/APK；
- first launch；
- upgrade/migration；
- autostart；
- permission denied；
- database relocation；
- crash recovery；
- privacy disclosure。

## 14. 为什么架构会演进

旧版本曾使用 JSONL/live snapshot 和不同配置命名；当前迁移到 SQLite 双库、versioned control file 和更严格 ownership。这并不代表旧设计“愚蠢”，而是早期验证速度与后期可靠性需求不同。

专业表达是：

> We started with a simpler append-oriented prototype to validate collection, then migrated to a constrained SQLite contract once range queries, deduplication, multi-process reading, and long-term evolution became first-class requirements.

## 15. 一个人怎样讲“我做了这个项目”

不要逐文件背诵。用以下结构：

```text
Problem：要在 GUI 关闭后持续记录真实使用时间
Constraints：跨平台、隐私、后台限制、长期数据
Architecture：collector + GUI，disk contract
Hard part：effective time state machines
Trade-off：polling/checkpoint/read-only/dual DB
Evidence：tests/build/runtime/package
Evolution：JSONL → SQLite，更多 activity signals
```

## 16. 本章练习

1. 如果只有两周做 MVP，你会做到哪个 milestone？
2. 哪三个风险应该最早验证？
3. 为“视频标题追踪”写一个 vertical slice。
4. 解释为什么视觉页面放在核心采集之后。

下一章：[面试深度表达与追问](20-interview-deep-dive.md)
