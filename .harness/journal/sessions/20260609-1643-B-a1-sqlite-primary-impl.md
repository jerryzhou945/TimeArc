# Session — A1 SQLite 主数据源迁移 · 实现（S1→S4）

Track **B**。计划＝`docs/a1-sqlite-storage-migration-kickoff.md`；前置变更提案＝
`20260609-1614-B-a1-sqlite-storage-migration-kickoff.md`（S4 据此签核）。本 log 记实现进度。

## Metadata
- Author: Claude Code (Opus 4.8)
- Date: 2026-06-09 16:43 (local)
- Branch: `feat/a1-sqlite-storage-migration`（PR #35，base=dev）
- 范围：S1+S2+S3+S4（**不做 S5** 退役 JSONL）。逐切片 build+验证+commit。

## 设计：Service 侧 / UI 侧（Track B 必填）
- **Service 侧（不改写）**：`time-arc-service` 经 `usage_storage.c` 双写 JSONL + SQLite
  （`init(&g,1,1)`，WAL，`INSERT OR IGNORE`）。A1 仅 S1 去过时注释，写行为不变。
- **UI 侧（主战场）**：`UsageStatManager` 当前只读 JSONL→`m_records`。A1 给它加 SQLite 读源
  （S2，flag OFF）→ 回填启用前 JSONL 尾巴（S3，db 层 .bak+事务+对账）→ 翻转主源 + JSONL 兜底（S4）。
  保 D5 并集 / 增量守卫 / 读层过滤 / live 快照 / 字段丰度。

## 基线探针（2026-06-09 16:43 本机，只读；service 当时未运行，数同 kickoff §0.3）
| 维度 | JSONL | SQLite (`timearc.db` 22.94 MB) |
|---|---|---|
| 前台 | 31,443（start 1780135221..1780955108） | `frontmost_sessions` 31,024（1780139594..1780955108） |
| 音频 | 21,662（1780135221..1780955099） | `media_sessions` 21,395（1780139594..1780955099） |
| apps | — | 50 行；`schema_migrations` 0 行 |
- **回填尾巴精确量**：`start < DB_min(1780139594)` 的 JSONL＝前台 **419** + 音频 **267**，
  全部 `dur>0`、`app_id` 非空（无 skip）。头部（start≥DB_min）JSONL 计数 31,024 == DB 计数 → 头部 1:1。
- **结论**：419/267 差**全是启用前尾巴**（非 dedup）；头部已对齐。S3 回填范围＝这 686 条。
  仍按唯一键存在性对账（禁行数相等，留 dedup 余量）。

## 关键代码事实（勘察固化）
- 服务 DDL `usage_storage.c:289-350`；UI DDL `database_manager.cpp:85-172`+索引 → **逐列一致**（parity 成立）。
- frontmost 唯一键 `(app_identifier,window_title,start,end)`；media 唯一键含 `media_type`。
- 路径：service `make_db_path` 与 UI `QStandardPaths::AppDataLocation` 均落
  `%APPDATA%\TimeArc\TimeArc\timearc.db`（本机实测相等）。
- 连接名 `timearc`（各 repo 共用）；`DatabaseManager.initialize()`(main:107) 在 `UsageStatManager`(main:127) 前 → USM 可读同连接。
- `db_smoke` 链接域＝`TIME_ARC_DATABASE_SOURCES`（不含 usage_stat_manager.cpp）→ S3 折进 `database_manager.cpp` 且不引 USM 符号。
- 字段映射：frontmost.app_identifier→appId+path、JOIN apps.app_name→appName、window_title→title、source=foreground；
  media.app_identifier→appId、media_title→title、playback_sec→duration、source=audio。

## S1 写侧实测复验（2026-06-09 17:00，真机跑 service 28s）
- 跑前 SQLite frontmost 31,024 / media 21,395；跑后 **31,027**（+3 VS Code 会话，新 start 1780995597..615）/ 21,395（无音频）。
- JSONL 同步 31,443→**31,446**（+3，max start 1780995615 == SQLite）；audio 21,662 不变。
- `usage_current.json` 实时刷新（updated 1780995624）。→ **双写在生产持续启用、头部逐条对齐**。
- 差仍 419/267（尾巴恒定，3 新会话双写无新 dedup）。DB_min 仍 1780139594 → S3 回填范围＝419+267。

## 进度
- [x] preflight（track B）pass；基线探针入 log。
- [x] S1 对齐去过时：去 stub 注释（usage_storage.h/storage_context.h/usage_storage.c DDL 锚点）、
  `db_smoke` schema-parity 断言（apps/frontmost/media 列名+类型+notnull，ctest exit 0）、
  `DatabaseManager::openDatabase` 路径不等一次性告警（test mode 跳过）。写侧实测复验见上。
- [ ] S2 USM SQLite 读源（flag OFF + parity 自检）。
- [ ] S3 一次性回填（.bak + 事务 + 对账 + 幂等标志）。
- [ ] S4 翻转 + CHARTER I2 修订 + 端到端抓图 parity。
