# 17 · 架构取舍与演进 / Architecture Trade-offs and Evolution

## 本章目标 / Learning goals

能够解释现有架构解决了什么、付出了什么、下一步怎样改，而不是把它说成唯一正确方案。

## 1. 双进程 + 磁盘契约

**收益：** 崩溃隔离、UI 可关闭、平台代码隔离、SQLite 可检查、无需维护复杂 RPC。

**代价：** 配置即时性较弱、schema 迁移敏感、状态通知不如实时 IPC、两边版本需兼容。

若未来需要高频双向命令，可以增加窄控制协议，但不能让 UI 绕过数据库所有权。

## 2. SQLite 而非日志文件

**收益：** 事务、索引、约束、范围查询、并发只读、跨语言成熟。

**代价：** schema 演进和锁需要纪律；损坏恢复比纯 append log 更复杂。JSONL/live snapshot 的退役说明唯一事实源比文件表面简单更重要。

## 3. C/Swift 原生 collector

**收益：** 靠近平台 API、较小 runtime、无 Qt service 依赖。

**代价：** 多语言维护、C 手动资源管理、平台差异和测试成本。适合共享状态机行为与 C ABI，而非强行共享每一行 probe 代码。

## 4. Context properties 与 QVariant

**收益：** 注入直接，QML 使用方便，模型灵活。

**代价：** 名称和字段多为运行时契约，编译期保障弱。规模扩大后可引入 typed list models、QML singleton/module 和模型契约测试。

## 5. QML 大页面

**收益：** 设计迭代快，视觉与交互靠近。

**代价：** binding 难追踪，运行时错误多。应按重复视觉、独立状态和可测试职责提取组件，而非只为减少行数拆分。

## 6. 准确率与隐私

TimeArc 选择 conservative attribution：只有明确策略才记录后台活动，未知状态宁可不猜。这是 precision over recall；对个人时间线，系统性误报比少量漏报更破坏信任。

## 7. 当前限制

- Windows 高级 service config 叶子尚未全部接线。
- macOS 需要实机权限、签名、公证和长期回归。
- Android 需要更多 ROM 验证。
- Linux collector 未实现。
- 部分 manager/service 边界和大型 QML 文件仍可收敛。
- 历史文档较多，需要区分 dated report 与 current contract。

## 8. 合理演进路线

1. 完成发布验证和可观察性，而非继续增加采集源。
2. 为跨平台状态机建立共享行为测试向量。
3. 给 view model 加结构化契约测试。
4. 不改变 DB 所有权地改善 service status 通知。
5. 若做同步，默认端到端加密并只同步用户明确选择的数据。

## 面试表达 / Interview answer

“The architecture optimizes for trust and failure isolation, not theoretical uniformity. Native collectors improve platform fidelity, while SQLite and a narrow C ABI keep the shared boundary inspectable. The main costs are schema discipline and multi-language testing.”

## 复习题 / Review

1. 为什么不用一种语言写全部平台？——平台 API 适配成本可能高于语言统一收益。
2. conservative attribution 是什么？——证据不足时不猜，优先减少误报。
3. 下一步应优先什么？——准确性、发布验证和契约测试。
