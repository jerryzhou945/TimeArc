# 09 · SQLite 磁盘契约与数据库所有权 / Data Contract and Database Ownership

## 本章目标 / Learning goals

能画出两份数据库、说清每张核心表的用途，并解释只读连接、事务、WAL 和唯一索引的价值。

## 1. 为什么称为“契约”

数据库文件名、目录规则、表名、字段名和类型同时被服务与 GUI 依赖。任意一方单独修改都会破坏另一方，因此它们是 process boundary 上的 contract，而不只是实现细节。

## 2. 服务数据库 `timearc_service.db`

默认位置：

| 平台 | 路径 |
| --- | --- |
| Windows | `%APPDATA%\TimeArc\service\timearc_service.db` |
| macOS | `~/Library/Application Support/TimeArc/service/timearc_service.db` |
| Linux 规划 | `${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db` |

`service_config.json` 的 `database.dir` 只能重定向目录，文件名固定。

### 核心表

| 表 | 作用 |
| --- | --- |
| `apps` | 稳定 `app_id`、平台、显示名、图标和 executable path |
| `frontmost_sessions` | 窗口标题、起止时间、`active_sec`；生成 `duration_sec` 与 `idle_sec` |
| `media_sessions` | 媒体类型、标题和起止时间；生成 `duration_sec` |

服务用 SQLite C API 打开唯一写连接，启用 foreign keys、WAL 和 5 秒 busy timeout。GUI 用 `QSQLITE_OPEN_READONLY` 打开独立只读连接。

## 3. GUI 数据库 `timearc.db`

它保存 UI 自己拥有的状态：

- `schema_migrations`
- GUI `apps` 元数据与自定义展示名
- `device_usage_summaries`、`device_usage_sessions`
- `tags`、`settings`
- `manual_projects`、`manual_sessions`

注意：两个数据库都有名为 `apps` 的表，但 schema 和所有权不同。面试时不要把它们混成同一张表。

## 4. 写入事务 / Transactional write

一次自动历史写入先 upsert app，再 insert session。两步应在事务内完成：

```text
BEGIN IMMEDIATE
  update apps
  insert frontmost/media session
COMMIT
on failure -> ROLLBACK
```

这保证不会留下“会话引用了不存在身份”或“身份更新成功但会话丢失”的半成品。

## 5. 生成列与约束

前台表由数据库计算：

```text
duration_sec = end_unix_sec - start_unix_sec
idle_sec     = duration_sec - active_sec
```

CHECK constraint 保证时间非负、结束不早于开始、active 不超过跨度。生成列减少不同写入端各算各的风险。

## 6. 唯一索引与幂等

前台唯一键包含 app、title、start、end；媒体唯一键包含 app、type、title、start、end。`INSERT OR IGNORE` 让重复 checkpoint/重试不制造相同会话。

Idempotent operation（幂等操作）指重复执行后的最终结果与执行一次相同。

## 7. WAL 与只读消费者

WAL（write-ahead logging）让写入先进入日志，通常更适合“一写多读”。GUI 读历史时不需要阻止服务继续写。busy timeout 处理短暂锁竞争，但不能代替正确的所有权设计。

## 8. 配置文件不是第三个历史数据库

`service_config.json` 是控制文件，只存设置和数据库目录指针，不保存历史。已经退役的 JSONL 和实时 JSON 快照不再是数据源，也不能恢复为 fallback。

## 9. 数据迁移思维

服务 schema 用 `PRAGMA user_version` 标记版本；GUI 有 `schema_migrations`。修改契约需要先写 migration plan，考虑旧用户数据、回滚、只读兼容和跨版本启动顺序。

## 面试表达 / Interview answer

“We split persistence by ownership. The collector is the sole writer of `timearc_service.db`, while the GUI owns `timearc.db` for settings and manual/mobile data. Read-only Qt connections, WAL, constraints, and unique indexes keep the cross-process contract predictable.”

## 源码入口 / Source entry points

- `src/service/shared/database_storage.c`
- `src/service/shared/database_path.c`
- `src/service/shared/data_bridge.h`
- `src/services/database_manager.cpp`
- `src/services/frontmost_session_repository.cpp`
- `src/services/media_session_repository.cpp`

## 复习题 / Review

1. 为什么固定服务数据库文件名？——避免两进程对同一配置产生不同路径解释。
2. WAL 解决什么？——改善持续写入与并发只读的协作。
3. 两个 `apps` 表是否相同？——不是；它们属于不同数据库和业务所有者。
