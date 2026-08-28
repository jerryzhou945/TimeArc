# 11｜SQLite 双数据库契约：两个进程如何通过磁盘合作

> 本章目标：理解 TimeArc 最重要的架构边界——two processes, one disk contract，以及为什么实际存在两个不同职责的数据库。
> Source map: `service/shared/database_storage.c`, `database_path.c`, `services/database_manager.cpp`.

## 1. 先纠正一句容易误解的话

“Two processes, one disk contract” 不是说所有数据都放进同一个 SQLite 文件。当前设计是：

| 文件 | writer | reader | 内容 |
|---|---|---|---|
| `timearc_service.db` | 后台 service | GUI 只读 | 自动采集历史 |
| `timearc.db` | GUI | GUI | 设置、标签、手动项目、移动同步/UI 状态 |

“one contract” 指 service 与 GUI 对自动历史的共同 schema 理解；并不取消 GUI 自己的数据所有权。

## 2. 为什么不让两个进程都写 service DB

SQLite 支持并发，但“技术上能写”不等于“架构上应该写”。单一 writer 带来：

- session ownership 清楚；
- schema migration 责任清楚；
- GUI bug 不会污染自动历史；
- 减少 write contention；
- 测试更容易建立不变量。

GUI 连接使用 `QSQLITE_OPEN_READONLY`。这不是团队口头约定，而是连接层执行的能力限制。

## 3. service DB 的三张核心表

DDL 集中在 `src/service/shared/database_storage.c`。

### `apps`

```sql
CREATE TABLE IF NOT EXISTS apps (
  app_id TEXT NOT NULL PRIMARY KEY,
  platform TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  icon_path TEXT NOT NULL DEFAULT '',
  executable_path TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

它是 app catalog：session 不重复存放全部 app metadata，只引用稳定 `app_id`。

### `frontmost_sessions`

```sql
app_id, window_title,
start_unix_sec, end_unix_sec,
duration_sec GENERATED,
active_sec,
idle_sec GENERATED
```

`duration_sec = end - start`，`idle_sec = duration - active` 由 SQLite 生成。这样避免 writer 写出三组互相矛盾的数字。

### `media_sessions`

```sql
app_id, media_type, media_title,
start_unix_sec, end_unix_sec,
duration_sec GENERATED
```

`media_type` 被 CHECK 限制为 `audio/video/unknown`，防止随意字符串污染 contract。

## 4. constraint 是数据库里的最后一道防线

前台表包含：

```sql
CHECK(end_unix_sec >= start_unix_sec)
CHECK(active_sec >= 0)
CHECK(active_sec <= end_unix_sec - start_unix_sec)
```

即使 C 状态机有 bug，数据库也拒绝明显不可能的数据。这个思想叫 **defense in depth（纵深防御）**：验证不只放在一个层。

## 5. generated column 为什么好

如果 `duration_sec` 由调用者传入，可能出现：

```text
start=100, end=160, duration=55  ← 矛盾
```

生成列让 duration 始终由唯一事实推导。它减少 **denormalized inconsistency（冗余不一致）**。

## 6. index 对查询有什么帮助

当前 schema 包含按时间、app 的 indexes。例如：

```sql
CREATE INDEX idx_frontmost_time
ON frontmost_sessions(start_unix_sec, end_unix_sec);
```

统计页面经常查询“今天 00:00 到现在”的重叠记录。没有 index 时数据越多越接近全表扫描；有合适 index 时 SQLite 可快速缩小候选范围。

unique session index 配合 `INSERT OR IGNORE` 提供基本 duplicate suppression：完全相同 identity/title/start/end 的 session 重试时不会重复插入。

## 7. prepared statement 与 bind

持久层不用字符串拼 SQL 值，而是：

```c
sqlite3_prepare_v2(...);
sqlite3_bind_text(..., SQLITE_TRANSIENT);
sqlite3_bind_int64(...);
sqlite3_step(...);
sqlite3_finalize(...);
```

好处：

- 避免引号和特殊字符破坏 SQL；
- 数据与 SQL 结构分离；
- SQLite 可以更好地处理类型；
- 每条 statement 都有明确 finalize 生命周期。

`SQLITE_TRANSIENT` 告诉 SQLite 复制传入文本，因此 caller 的 buffer 生命周期不必覆盖整个 statement。

## 8. WAL 与 busy timeout

打开连接后：

```c
sqlite3_busy_timeout(g_db, 5000);
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
```

WAL（write-ahead logging）通常改善一个 writer 与多个 reader 并存的体验；busy timeout 让短暂锁竞争先等待，而不是瞬间失败。但 WAL 不是取消 ownership 规则的理由。

## 9. 数据库路径也是 contract

如果 service 和 GUI 对文件位置理解不同，就会产生 **split brain（分裂脑）**：服务写 A，GUI 读 B，双方都“正常”却看不到数据。

TimeArc 使用固定 config directory 下的 `service_config.json` 保存可移动 service database pointer。C 侧 `database_path.c` 与 Qt 侧 `database_manager.cpp` 必须镜像相同路径规则。

配置大致是嵌套 versioned document：

```json
{
  "schema_version": 1,
  "database": {
    "dir": "..."
  },
  "tracking": {
    "enabled": true,
    "frontmost": {
      "idle_threshold_sec": 300
    }
  }
}
```

## 10. 为什么更新配置要 read-modify-write

GUI 可能只想修改 `tracking.enabled`，但同一文件还有 `database.dir`。若直接创建新 JSON，会擦掉未知 sibling keys。

`patchServiceConfig()`：

1. 读取现有对象；
2. 用 dotted path 修改指定 leaf；
3. 保留其他所有 key；
4. stamp `schema_version`；
5. 用 `QSaveFile` 临时写入后原子 rename。

如果旧文件非空但无法解析，它拒绝覆盖，以保留恢复证据。这是 **honest failure（诚实失败）**。

## 11. 旧版 JSONL 为什么退休

旧 learning 中可能出现 JSONL、live snapshot、`usage_config.json` 或共享 `timearc.db` 的描述。这些属于历史设计，不是当前 contract。SQLite migration 的动机包括：

- schema 与 constraints 更明确；
- range query 和 aggregation 更自然；
- indexes 支持长期数据量；
- transaction 和 dedup 更可靠；
- GUI 可通过 read-only connection 查询。

## 12. transaction 边界

storage 提供 `begin/commit/rollback`。复合写入（例如 app upsert + session insert）应该具有清晰 transaction policy，避免只成功一半。

初学者要区分：

- connection ownership：谁持有连接；
- schema ownership：谁负责建表和迁移；
- transaction ownership：谁决定一组写操作必须共同成功；
- query ownership：谁把表转换成 UI 需要的形状。

## 13. 面试表达

> The collector is the sole writer of `timearc_service.db`, while the GUI opens that journal read-only. The GUI owns a separate `timearc.db` for user-controlled state. The service schema uses generated duration columns, checks, indexes, and duplicate-suppressing unique indexes. A versioned atomic control file keeps both processes pointed at the same service database without allowing one setting update to clobber unrelated keys.

## 14. 本章练习

1. 为什么 read-only 是能力边界，而不只是编码习惯？
2. 写一条违反 `active_sec` constraint 的记录。
3. 解释 WAL 能解决什么、不能解决什么。
4. 如果移动数据库时只更新 GUI 路径，会出现什么症状？

下一章：[GUI 数据库与 Repository](12-gui-database-and-repositories.md)
