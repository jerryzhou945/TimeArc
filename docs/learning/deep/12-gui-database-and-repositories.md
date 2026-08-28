# 12｜GUI 数据层：DatabaseManager 与 Repository

> 本章目标：理解 Qt 应用怎样同时管理 GUI 自有数据库和只读 service journal，并把 SQL 隔离在 repository 层。
> Source map: `database_manager.*`, `*_repository.*`.

## 1. Repository 是什么

Repository（仓储）把数据库访问包装成领域操作。例如 QML 不应直接写：

```sql
SELECT SUM(active_sec) FROM frontmost_sessions ...
```

而应调用：

```text
frontmostRepository.getTotalActiveSecondsByRange(start, end)
```

这样 UI 只知道“我要范围内活跃秒数”，不必知道表名、连接名和 SQL overlap 规则。

## 2. DatabaseManager 的责任

`src/services/database_manager.cpp` 负责：

- 解析 GUI database path；
- 创建/升级 GUI-owned schema；
- 解析 service control file；
- 打开 service DB read-only connection；
- 暴露连接名和生命周期；
- 支持数据库 relocation 与 test isolation；
- 原子更新 `service_config.json`。

它是 **infrastructure service（基础设施服务）**，不是业务统计服务。

## 3. 两个命名连接

代码中定义：

```cpp
const QString kGuiConnectionName = QStringLiteral("timearc");
const QString kServiceConnectionName = QStringLiteral("timearc_service");
```

Qt SQL 连接是按名称注册的。Repository 必须使用正确连接：

- `SettingsRepository`、`TagRepository`、`ManualProjectRepository` → GUI connection；
- `FrontmostSessionRepository`、`MediaSessionRepository`、`AppRepository` → service read connection。

如果误用默认 connection，代码可能在开发机“看起来能跑”，却跨进程写错数据库。

## 4. service read-only 的现实意义

GUI 打开 journal 时设置 `QSQLITE_OPEN_READONLY`。因此即使 repository 不小心发出 INSERT，SQLite 也会拒绝。

这是 **least privilege（最小权限）**：组件只得到完成工作所需的最小能力。

## 5. range query 的 overlap 条件

查询 `[rangeStart, rangeEnd)` 内与 session 重叠的数据，通常不能只写 `start >= rangeStart`。正确候选条件是：

```sql
session.end > rangeStart
AND session.start < rangeEnd
```

然后裁剪：

```text
clippedStart = max(session.start, rangeStart)
clippedEnd   = min(session.end, rangeEnd)
```

否则一个从昨天 23:59 延续到今天 00:10 的 session 会被漏掉。

## 6. Repository 的常见返回类型

Qt/QML 边界常使用：

- `int`：总秒数；
- `QString`：格式化文本；
- `QVariantMap`：一条 key/value model；
- `QVariantList`：列表数据；
- `bool`：命令成功与否。

`QVariantMap/List` 便于 QML 使用，但也牺牲部分 compile-time type safety。大型模型可进一步演进为 `QAbstractListModel`。

## 7. GUI 自有 Repository

### SettingsRepository

负责语言、主题、启动、追踪开关等用户设置，并通过 service CLI/control file 协调后台采集。它还迁移历史 QSettings 数据。

### ManualProjectRepository

保存用户手动项目和计时记录。它属于用户主动创建的数据，不应混进自动采集 journal。

### TagRepository

管理标签与颜色/关联等结构，让 UI 不直接拼 SQL。

### MobileUsageRepository

保存或查询 Android usage 同步后的数据，适应移动端不同的采集来源。

## 8. service journal Repository

### AppRepository

把 app catalog 转换成 UI 可展示 metadata，并配合 identity/icon policy。

### FrontmostSessionRepository

负责前台 session 的 range query、ranking 和 active seconds 聚合。

### MediaSessionRepository

负责媒体区间、播放总量与 ranking。

这些 repository 是 read model 的起点。service 写模型简单、稳定；GUI 可构建更丰富的查询模型。

## 9. migration 与 compatibility

数据库应用要面对旧用户已有文件。典型做法：

1. 读取 `PRAGMA user_version`；
2. 按版本顺序执行 migration；
3. transaction 内完成 schema changes；
4. 成功后更新 version；
5. 失败 rollback，并保留可诊断错误。

不要“看到表存在就猜版本”。Migration 是持久化软件的产品功能。

## 10. test isolation

`QStandardPaths::isTestModeEnabled()` 与 `TIMEARC_TEST_APPDATA` 让测试使用独立目录，不接触真实用户数据库。

这解决两个风险：

- 测试污染真实历史；
- 测试结果依赖开发者电脑已有设置。

面试可称为 **hermetic test environment（封闭测试环境）**。

## 11. Repository 不应承担的责任

Repository 负责数据访问，但不应：

- 决定页面导航；
- 创建 QML controls；
- 直接调用平台窗口 API；
- 混合多个来源形成复杂产品指标；
- 持有跨页面动画状态。

多来源组合应该进入 service 层，展示状态进入 QML/ViewModel。

## 12. 从页面请求追到 SQL

建议练习路径：

```text
DesktopHomePage.qml
  → statsService.getHomeSummary()
  → FrontmostSessionRepository / MediaSessionRepository
  → named read-only Qt SQL connection
  → timearc_service.db
```

每一跳问三个问题：输入是什么？输出是什么？谁拥有错误处理？

## 13. 面试表达

> `DatabaseManager` owns connection setup, schema lifecycle, path resolution, and read-only enforcement. Repositories hide SQL and expose domain-oriented queries. This prevents QML from knowing table details and makes the two-database ownership model explicit at the connection boundary.

## 14. 本章练习

1. 找出三个 repository，并标注它们使用哪一个数据库。
2. 写出正确的 interval overlap condition。
3. 为什么 `QVariantList` 方便？它损失了什么？
4. 测试若连接真实 AppData，会有哪些严重后果？

下一章：[Services、Managers 与统计](13-services-managers-and-stats.md)
