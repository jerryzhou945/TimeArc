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
- [x] S2 USM SQLite 读源（folded 进 usage_stat_manager.{h,cpp}，flag 默认 JSONL，env `TIMEARC_USAGE_SOURCE` 覆盖）：
  refresh() 分派 JSONL/SQLite 历史 + 共享 live 快照；SQLite 增量按 MAX(id) 高水位、切源全量重载；JOIN apps 还原
  app_name/path；保 D5/读层过滤/live/增量守卫。双读 parity 自检写 `logs/a1-parity-report.json`（env 门控）。
  **parity 实测（TIMEARC_SQLITE_PARITY=1，flag 仍 OFF）**：week 32044==32044、month 373242==373242（**diff 0**）；
  year/all 422988 vs 415647（**diff 7341s**＝686 启用前尾巴，仅在 JSONL）；记录数 53108 vs 52422（diff 686=419+267）；
  top10 排行**顺序完全一致**，逐 app 秒差累加=尾巴。差异全可解释（§0.3）；抓图各页仍走 JSONL 不变；scan_qt_log 0 新告警。
- [x] S3 一次性回填（folded 进 database_manager.{cpp,h}，db 层、不引 USM 符号；main.cpp 启动后调用）：
  幂等标志 `usage_jsonl_backfill_v1_done`→先写 `.bak`→BEGIN IMMEDIATE→INSERT OR IGNORE 前台/音频 + apps
  （字段逐列对齐 service write_sqlite）→**按唯一键存在性对账**（非行数）→缺则 ROLLBACK 保 JSONL 不置标志。
  **实测**：前台 31027→**31446**(+419)、音频 21395→**21662**(+267)、MIN start→1780135221、flag='true'、`.bak` 19451200B=JSONL；
  **回填后 parity 全等**：记录数 53108==53108、week/month/year/all **全 diff 0**。二次启动 `.bak` mtime 不变、计数不再 +419/267（幂等）。scan_qt_log 无 log（0 告警）。
- [x] S4 翻转主源 + 契约修订：flag 默认翻 **SQLite**（`kDefaultUseSqliteSource=true`，DB 缺失/空→回退 JSONL，
  env `TIMEARC_USAGE_SOURCE=jsonl` 紧急回滚）；变更提案签核补全（kickoff session log §7）；**CHARTER I2 修订**
  （timearc.db 升一等主契约 + UI 主读源）+ **版本 v0.1→v0.2** + `rules/03 §1` 表/文同步；`harness_check --bootstrap`
  仅更新 CHARTER.md 哈希。**端到端实测（真 service+UI，flag=SQLite）**：Home 页 PrintWindow 抓图正常渲染真实数据
  （Memory Lake/APP 排行/今日主题 5.3h/live「当前应用」Chrome 磁贴/占比环）；parity 仍 53108==53108、week/month/year/all
  全 diff 0、top 排行一致；scan_qt_log 无 log（0 告警）；harness_check exit 0。service JSONL 写入不动（安全网）。

## 收尾：dev 同步 + 对抗式评审修正（PR 前）
- 合并 origin/dev（PR #36 docs-sync）入分支，解决落后；docs（README/open-issues/backlog/06-licensing）同步 A1 完成。
- 4-agent 对抗式评审（cloud workflow）出 3 处确认项，已修正：
  1. **回填阈值漏乱序音频**（medium）：原按 per-source `MIN(start)` 阈值只导尾巴，乱序 close 的音频会话跨边界可能被静默漏导。
     改为 **stage-all**（不预过滤），靠 INSERT OR IGNORE 吸收已存行 + 按唯一键存在性对账作权威保证（kickoff §6）。
  2. **schema-parity 注释夸大**（medium）：db_smoke 只跑 UI DDL（service C 未链入），注释称「双侧漂移都拦」不实。
     已校正 usage_storage.c / db_smoke.cpp / CHARTER 注释为「仅 UI DDL 钉死，service 侧靠人工 lockstep + 真机端到端」。
  3. **CHARTER I2 路径归属错**（low）：db 路径由 `usage_storage.c::make_db_path` 构造，非 `usage_paths.c`。已订正。
  （第 4 项「半写行 break 丢尾」经验证为非问题——readLine 语义下中段不会触发，已驳回。）
- 修正于隔离 git worktree 应用（主工作树被并行 B1 会话切换占用）；db_smoke rebuild + 跑通（schema-parity 绿）。
