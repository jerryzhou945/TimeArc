# 19 · 中英术语表与源码练习 / Glossary and Source Exercises

## 1. 架构术语 / Architecture

| 中文 | English | 在 TimeArc 中的含义 |
| --- | --- | --- |
| 双进程架构 | two-process architecture | GUI 与原生 collector 独立运行 |
| 磁盘契约 | disk contract | 两进程共同遵守的路径、schema 和配置格式 |
| 唯一写入者 | sole writer | 服务独占写自动历史 |
| 所有权边界 | ownership boundary | 谁可以修改哪类数据 |
| 单向数据流 | unidirectional data flow | collector → DB → read layer → UI |
| 故障隔离 | failure isolation | 一个进程失败不拖垮另一个 |
| 组合根 | composition root | `main.cpp` 创建并连接应用对象 |
| 依赖注入 | dependency injection | 从外部传入对象依赖 |
| 平台隔离 | platform isolation | 平台 SDK 限定在各自目录 |

## 2. 采集与时间 / Tracking and time

| 中文 | English | 含义 |
| --- | --- | --- |
| 快照/观察 | snapshot/observation | 某次轮询看到的瞬时状态 |
| 会话 | session | 连续同身份观察形成的区间 |
| 前台应用 | foreground/frontmost application | 当前用户正在交互的窗口应用 |
| 空闲阈值 | idle threshold | 无键鼠输入多久后暂停普通活跃时间 |
| 自主活动 | autonomous activity | 媒体、游戏、Agent 等明确非键鼠证据 |
| 短租约 | short lease | 吸收采样抖动的有限延续时间 |
| 检查点 | checkpoint | 长会话的周期性持久化切片 |
| 单调时钟 | monotonic clock | 只向前的经过时间来源 |
| 墙上时钟 | wall clock | 真实日期时间，用于落盘 |
| 区间裁剪 | interval clipping | 把 session 限制到查询范围 |
| 区间并集 | interval union | 合并重叠，避免重复计时 |

## 3. Qt/QML

| 中文 | English | 含义 |
| --- | --- | --- |
| 元对象系统 | meta-object system | Qt 的运行时属性、信号和方法信息 |
| 信号槽 | signals and slots | Qt 事件通信机制 |
| 属性绑定 | property binding | 依赖值改变时自动重算 QML 属性 |
| 上下文属性 | context property | C++ 注入 QML 的应用级对象 |
| 可调用方法 | invokable method | QML 可调用的 C++ 方法 |
| 通知信号 | NOTIFY signal | 告诉 QML 属性已变化 |
| 声明式 UI | declarative UI | 描述目标状态而非逐步绘制 |
| 门面 | façade | 为 UI 提供简单稳定接口的对象 |
| 视图模型 | view model | 已整理为页面消费形状的数据 |

## 4. 数据与可靠性 / Data and reliability

| 中文 | English | 含义 |
| --- | --- | --- |
| 事务 | transaction | 一组写入整体提交或回滚 |
| 幂等 | idempotent | 重复执行不改变最终结果 |
| 预处理语句 | prepared statement | SQL 与参数分离 |
| 唯一索引 | unique index | 防止相同键重复行 |
| 生成列 | generated column | 数据库按表达式计算的字段 |
| 写前日志 | write-ahead logging (WAL) | 改善一写多读协作 |
| 只读连接 | read-only connection | GUI 不可修改服务历史 |
| 安全默认值 | safe default | 配置缺失/无效时的保守行为 |
| 优雅停止 | graceful shutdown | 停止前 flush 并释放资源 |
| 保守归因 | conservative attribution | 证据不足时不猜测活动身份 |

## 5. 源码练习 / Source exercises

### Exercise 1：画出启动链

阅读 `src/main.cpp`。答案：application → resources/logger → engine → DB → repositories → services/managers → context properties → `qml/main.qml` → event loop。

### Exercise 2：追踪一次应用切换

从 `active_app_win.c` 追到 tracker、state、bridge、storage。答案：新 snapshot 身份不同 → 导出 A → 开始 B → upsert A → transaction insert A session。

### Exercise 3：解释 idle 行

答案：session 在 idle 中保持开放；只有 ACTIVE 模式按 monotonic delta 累加，数据库生成 idle difference。

### Exercise 4：找出只读保障

答案：`DatabaseManager` 对 service connection 使用 `QSQLITE_OPEN_READONLY`，GUI 不链接服务写模块。

### Exercise 5：从 QML 找到 C++

选择一个 `usageStatManager` 调用。答案链：QML command → Qt meta-object → C++ aggregate → QVariant return。

### Exercise 6：证明不会双算

`[0,10]`、`[5,15]`、`[20,30]` 的 union 是 `[0,15]` 与 `[20,30]`，总计 25，而不是 30。

### Exercise 7：设计 Linux 后端

答案要点：不改 GUI 写权限、数据库文件名和 C ABI；实现 X11/Wayland foreground、idle、PipeWire media、单实例、配置、生命周期和行为测试。

## 6. 自测清单 / Self-check

- 用英文解释 two-process architecture。
- 说出两份数据库和至少三张表。
- 解释 snapshot 如何变成 session。
- 解释 Qt meta-object system 怎样连接 C++ 和 QML。
- 解释 interval union、idle continuity、checkpoint。
- 准确说出四个平台的当前状态。
- 给出一个架构收益和一个代价。
- 不看稿完成第 18 章两分钟英文回答。

做到这些，你已经不只是“看过代码”，而是能以工程语言解释 TimeArc。
