# A1 · SQLite 主数据源迁移 · 实现启动（Kickoff / 多 session 拆分）

> 用途：把 `docs/implementation-backlog.md` §A1（keystone）从「散落待办」展开成**带依赖、可逐 session 落地**
> 的执行计划。A1 是 Track **B**、跨多 session、碰冻结磁盘契约（`CHARTER` I2 / `rules/03` §4），所以本文先把
> **真实现状**钉死，再给拆分、文件红线、变更提案边界、必须保留的语义、风险与验收口径。
>
> **体例**参照 `docs/stats-implementation-kickoff.md`（每 session 一张可粘贴的范围卡）。
> **配套权威**：`.harness/rules/03-data-contract.md`、`.harness/CHARTER.md` §2-4、
> `.harness/tracks/B-feature.md`「Playbook — SQLite migration」、`docs/stats-backend-performance.md`（增量/记忆化 parity）。
>
> 维护：完成一个 sub-session → 勾掉下表 + 移进 session log，并同步 `README.md §Roadmap` /
> `.harness/state/open-issues.md` / `docs/implementation-backlog.md §A1`。

---

## 0. 现状校正（这是 A1 的起点，backlog 旧描述已过时）

A1 在 backlog 里被描述为「service 侧 `timearc_storage_init_sqlite` / `write_sqlite` 是 no-op」。
**这是过时的错误前提。** 2026-06-09 对真实代码 + 真实磁盘的勘察结论如下（证据见 §0.3）：

### 0.1 写侧——**已完整实现并在生产启用（不是 stub）**
- `timearc_storage_init_global()` → `timearc_storage_init(&g_storage, /*jsonl=*/1, /*sqlite=*/1)`
  （`src/service/windows/storage/usage_storage.c:617`）：**JSONL 与 SQLite 双写同时开启**。
- `timearc_storage_init_sqlite`（:271）：开库、`busy_timeout=5000`、`PRAGMA foreign_keys` /
  `journal_mode=WAL`，建表 `apps` / `frontmost_sessions` / `media_sessions` + 索引 + 去重唯一索引。
- `timearc_storage_write_sqlite`（:364）：`BEGIN IMMEDIATE` → upsert `apps` → `INSERT OR IGNORE`
  到 `frontmost_sessions`（foreground）/ `media_sessions`（audio）→ `COMMIT`。**完整实现。**
- 派发遵守不变量 I5（全有或全无）：`timearc_storage_write_record`（:584）任一启用后端写失败即整条失败。
- ⚠️ `usage_storage.h:11-12`、`storage_context.h:10/16` 仍写「SQLite is stubbed / 先保留」——**过时注释**，
  与代码相悖；S1 须改正，避免有人据注释「重新 stub」。

### 0.2 读侧——**UI 生产路径仍只读 JSONL**
- `UsageStatManager`（`src/services/usage_stat_manager.cpp`）只读 `usage_records.jsonl` +
  `usage_current.json`，**从不碰 SQLite**（全文唯一 “SQLite” 字样是 :1369 的注释「不写 SQLite」）。
  Home / Stats / Memory-Lake / Recap / Calendar / Settings 全部经 `usageStatManager` 取数。
- UI 侧 SQLite 读仓 `FrontmostSessionRepository` / `MediaSessionRepository` **存在**，接进了
  `StatsService` / `DailyCardService`，但**没有任何 .qml 引用它们做自动用量**；它们只喂 C++ 卡片层。
- 没有任何 JSONL→SQLite **回填**代码（UI 或 service 都没有）。

### 0.3 实测证据（2026-06-09 本机，只读探针；数字会随采集增长）
| 维度 | JSONL | SQLite (`timearc.db`) | 结论 |
|---|---|---|---|
| DB 文件 | — | `%APPDATA%\TimeArc\TimeArc\timearc.db`，22.9 MB，**存在** | 路径**约定实测成立** |
| 前台 | 31,443 条 | `frontmost_sessions` **31,024 行** | service 确在双写；差 419 |
| 音频 | 21,662 条（source=audio） | `media_sessions` **21,395 行** | 同上；差 267 |
| 历史最早 start | 1780135221 | 1780139594 | DB 比 JSONL **晚 ~73 分钟**＝启用前的待回填尾巴 |
| 历史最新 start | 1780955108 | 1780955108 | **头部已对齐**（service 持续追平） |
| `schema_migrations` | — | **0 行** | 确认休眠表，无版本框架 |

**关键推论**：
1. 路径约定（service `make_db_path` 与 UI `QStandardPaths::AppDataLocation` 都落
   `%APPDATA%\TimeArc\TimeArc\timearc.db`）**在本机成立**——但仍是「两处独立构造、靠约定相等」，须在每个目标
   环境（min/max env、测试模式）复核。
2. 回填范围**很小**：只有「DB 最早 start 之前」的 JSONL 尾巴（~73 min）需要导入；头部 service 已实时写入。
3. 行数差（419 / 267）**大半是合法去重**（`INSERT OR IGNORE` 在 `(app_identifier, window_title, start, end)`
   折叠重复行）＋少量服务端 skip（空标识 / `start<=0` / `duration==0`）＋启用前尾巴。
   → **绝不能用「JSONL 行数 == SQLite 行数」做迁移校验**（会误报丢数据）。

### 0.4 schema 映射现实（读侧切换 / 回填都要按这个映射）
| JSONL 字段 | `frontmost_sessions` | `media_sessions` | 备注 |
|---|---|---|---|
| `app_id` / `path` | `app_identifier` | `app_identifier` | SQLite 无独立 `path` 列 |
| `app_name` | —（须 JOIN `apps.app_name/display_name`）| 同左 | `apps` 表 50 行，含 `app_icon_path`/`executable_path` |
| `window_title` | `window_title` | `media_title` | 音频复用为标题 |
| `source=foreground` | （整表即前台）| — | 表即语义 |
| `source=audio` | — | （整表即音频，`media_type`）| D5 并集的音频侧来自这里 |
| `duration_sec` | `duration_sec` / `active_sec` / `idle_sec` | `playback_sec` | service 派生 `end=start+dur` |

---

## 1. A1 真实范围与落地顺序

写侧已完成且经实测验证，A1 的剩余工作是**读侧 + 回填 + 翻转 + 退役**：

```
S1 对齐与去过时(地基)  ──> S2 SQLite 读源(flag OFF, parity) ──┬─> S4 翻转主源+契约修订(I2) ──> S5 退役 JSONL(未来)
                          └> S3 一次性 JSONL→SQLite 回填(.bak+事务+对账) ─┘
```

- **S1** 是地基：经验验证写侧、统一 schema/路径权威、去过时注释、（可选）激活 `schema_migrations`。无冻结改动。
- **S2 / S3** 可并行（都不依赖对方），但都依赖 S1 的对齐结论。
- **S4** 是收口：翻转默认读源 + JSONL 回退兜底 + **I2 / rules/03 数据契约修订（须变更提案 + CHARTER 版本号）**。
- **S5** 退役 JSONL 写入（service 改 `init(...,0,1)`）属未来发版里程碑，**不在本轮**。

> 提醒（CLAUDE.md 硬规则）：每个 sub-session **只走一条 track（全程 B）+ 最小可运行纵切**。不要把 S1–S4 混进一个
> session（`harness_check` pass 7 会拦混 track；但同为 B 时是「范围纪律」问题，仍应按纵切拆）。

---

## 2. 多 session 拆分（逐张范围卡）

### S1 — 对齐与去过时（地基 · 无冻结改动 · Track B）
**目标**：把「现状」从实测固化为代码与文档的单一事实源，消除路径/schema 双源漂移与过时注释。
- ① **经验复验写侧**：构建并真机运行 service（先 kill `TimeArc.exe`、`time-arc-service.exe`，exe 锁），确认
  `frontmost_sessions` / `media_sessions` 持续增长且头部追平 JSONL（复跑 §0.3 探针，把数字记进 session log）。
- ② **schema 单一权威**：当前 service（`usage_storage.c` 内联 DDL）与 UI（`database_manager.cpp:85` 内联 DDL）
  **各自 `CREATE TABLE IF NOT EXISTS`**，列实测一致但**可能漂移**。定权威＝由 UI `DatabaseManager` 拥有规范 DDL，
  service 内联须保持逐列兼容；加一个 **schema-parity 断言**（扩 `tests/db_smoke.cpp`，它已校验 `requiredTables`）。
- ③ **路径单一事实**：文档化「两处独立构造、约定相等」并在 `DatabaseManager::openDatabase` 加一处一次性
  `qWarning` 校验（不相等即告警）。**是否新增冻结 `usage_paths` 的 `timearc_get_usage_db_path()` 访问器留作 S4 决策**
  （见 §3）——本机已验证约定成立，**默认不加**，避免提前动冻结文件。
- ④ **去过时注释**：改 `usage_storage.h:11-12`、`storage_context.h:10/16`「stubbed/future」→「已实装且默认启用」。
- ⑤（可选，为 S3 铺路）**激活 `schema_migrations`**：写一个极小版本台账 helper（`applied version` 行），供 S3 记录回填。
- 文件红线：🟢 `usage_storage.{c,h}`、`storage_context.h`、`database_manager.{cpp,h}`、`tests/db_smoke.cpp`、
  `frontmost_session_repository.*`（均非冻结）。⛔ 不碰 `src/service/shared/*`、任何 `CMakeLists.txt`。
- 变更提案：**否**。验收：探针数字入 log；`db_smoke` 含 schema-parity 通过；`harness_check` exit 0。

### S2 — UsageStatManager 增 SQLite 读源（parity · flag 默认 OFF · Track B）
**目标**：在不改公开 `Q_INVOKABLE` API、不动冻结 `src/CMakeLists.txt` 的前提下，给 `UsageStatManager` 加一条
SQLite 读路径，产出与 JSONL **逐窗口等价**的聚合，默认仍以 JSONL 为主。
- 把 SQLite 读**写进现有 `usage_stat_manager.{h,cpp}`**（已在 `TIME_ARC_APP_SOURCES`，避开冻结 CMake；
  注意 `db_smoke` **不链接** USM，故这段不进 `db_smoke`，须真机 + 独立 parity 自检验证）。
- 装载 `frontmost_sessions`（前台）+ `media_sessions`（音频）**JOIN `apps`**（取 `app_name`/`path`/icon）→ 灌进
  **同一个** `m_records` 内存模型，按 §0.4 做字段映射；source 由「来自哪张表」决定。
- **必须保留的语义**（详见 §4）：D5 前台+音频并集去重、`platform` 过滤、`duration>0`/非空标识丢弃、本地时区
  分桶、`setReadFilters` 读层过滤、`recordsGeneration` 增量守卫（SQLite 用 `MAX(end_unix_sec)`/`MAX(id)`
  高水位替代字节偏移）、**live 快照仍用 `usage_current.json`（混合：SQLite 历史 + JSON 实时）**。
- **双读 parity 自检**：同窗口对比 SQLite vs JSONL 的 week/month/year/all 总时长 + top 应用排行，记录差异
  （应与 §0.3 的去重/尾巴一致）；写进 session log。
- 主源开关：加 `property/flag`（默认 **JSONL**）。本 session **不翻转**。
- 文件红线：🟢 `usage_stat_manager.{h,cpp}`。⛔ 不新增 .cpp/.h（否则动冻结 `src/CMakeLists.txt` 须提案）。
- 变更提案：**否**（无冻结改动）。验收：parity 自检差异可解释；抓图各页**不变**（仍走 JSONL）。

### S3 — 一次性 JSONL→SQLite 回填迁移器（.bak + 事务 + 对账 · Track B）
**目标**：把「DB 最早 start 之前」的 JSONL 尾巴幂等导入 SQLite，确立可复用的回填范式（修正旧 QSettings 迁移器
缺陷：无备份 / 无事务 / 无对账，见 `docs/settings-*`／survey 记录）。
- 折进**现有非冻结 .cpp**（建议 `DatabaseManager` 或 `FrontmostSessionRepository` 的方法；若放进
  `TIME_ARC_DATABASE_SOURCES` 链接域，**不得引用 USM 符号**，否则 `db_smoke` 链接失败）。
- 流程：① 先写 `usage_records.jsonl.bak`（rules/03 D1 要求备份）→ ② 解析 JSONL（复用 `parseRecordObject` 同款键）
  → ③ `BEGIN`→`INSERT OR IGNORE` 前台/音频 + upsert `apps`→`COMMIT`（事务，崩溃不留半库）→ ④ **对账**。
- **对账不按行数相等**：逐条按唯一键 `(app_identifier, window_title, start, end)` 校验「每条**非 skip、非重复**的
  JSONL 记录都已落库」；缺任一真实记录则**回滚 + 保留 JSONL 原样 + 不置标志**（拒绝前进）。计入合法 skip/去重
  （§0.3 的 419/267）。
- 幂等守卫：settings 表布尔标志 `usage_jsonl_backfill_v1_done`（仿 `legacy_qsettings_migration_v1_done`）
  或 `schema_migrations` 版本行。
- 并发：service 以 WAL 持有同库 → 回填**只导启用前尾巴**（`start < DB_min`，service 永不再写这段，碰撞最小）；
  仍须遵 `busy_timeout`/WAL；理想在 UI 启动早期、service 未活跃窗口执行。**与 service 写入并发须文档化**。
- 文件红线：🟢 折进现有 db 层 .cpp。⛔ 不新增源文件。变更提案：**否**（回填本身无冻结改动）。
- 验收：跑一次→`.bak` 生成、标志置位、对账通过；二次启动**不重复导入**（幂等）；DB 行数按去重后增量上升。

### S4 — 翻转主源 + JSONL 回退 + 端到端 parity + **数据契约修订（变更提案落地）· Track B**
**目标**：把默认读源翻成 SQLite，保留 JSONL 兜底，端到端证明**用户可见数字不变**，并正式修订磁盘契约。
- 翻转 S2 的开关默认 **ON**：`UsageStatManager` 优先 SQLite；**DB 缺失/空/旧版 service/ parity 自检失败 → 回退
  JSONL**（防空库假象）。
- **端到端验收**：真机 service + UI；week/month/year/all 总时长 == 翻转前 JSONL 数（`stats-backend-performance`
  §5 parity 口径）；逐页 PrintWindow-by-PID 抓图（Home/Stats/Memory-Lake/Recap/Calendar/Settings）；读层过滤、
  live「当前应用」磁贴均正常。
- **变更提案落地（这一步必须）**：`CHARTER` **I2 修订**——把 `timearc.db` 升为一等「主」契约文件（定义规范路径 +
  schema + reader=UI 主源），并据 `rules/03` §4 写迁移说明；**bump CHARTER 版本号**。若决定加 `usage_paths`
  db 路径访问器（见 §3）→ 同时改两个冻结文件 + 重生成 `state/frozen-files.json`。**提案须在改冻结文件前已落
  `journal/sessions/`**（本轮已起草，见该 session log；S4 据实补全并签核）。
- service JSONL **写入继续保留 N 个发版**（安全网）。同步 `README §Roadmap` / `open-issues` / `implementation-backlog`。
- 验收：抓图 parity 全过；`harness_check` exit 0；冻结改动有对应提案 + 哈希更新。

### S5 — 退役 JSONL（未来发版 · 独立 · 本轮不做）
- service 改 `timearc_storage_init(...,/*jsonl=*/0,1)`；UI 移除 JSONL 读路径；**最终 `rules/03` 修订**。
- 可选：删除遗留 QSettings 存储（**单独、带守卫**——迁移标志可能在半成功时置位，贸然删会丢未迁移数据）。

---

## 3. 冻结文件与变更提案边界

**非冻结（可直接改）**：`src/service/windows/storage/usage_storage.{c,h}`、`storage_context.h`、
`src/services/*.{cpp,h}`（含 `database_manager`、各 `*_repository`、`usage_stat_manager`、`daily_card_service`、
`stats_service`）、`tests/db_smoke.cpp`、`src/main.cpp`（入口，敏感但非冻结，慎改）。

**冻结（改前须先填 `.harness/templates/change-proposal.md` 进 `journal/sessions/`，并更新 `state/frozen-files.json`）**：
`src/service/shared/{data_bridge.h, usage_record.h, usage_record.schema.json, usage_paths.h, usage_paths.c,
app_info.h, app_env.h}`、`src/include/util.h`、`CMakeLists.txt`(顶层)、`src/CMakeLists.txt`、
`src/service/CMakeLists.txt`、`.harness/CHARTER.md`、`.harness/AGENTS.md`、`AGENTS.md`。

**关键事实**：
- sqlite3 **已链入** UI（`Qt6::Sql`）与 service（`thirdparty/sqlite3` 静态库 amalgamation）。**用 SQLite 无需动任何
  CMake。**
- **避让技巧**（统计页/设置页同款）：所有新逻辑**折进已登记的现有 .cpp**（`usage_stat_manager.cpp` /
  `usage_storage.c` / `database_manager.cpp` / `frontmost_session_repository.cpp`），就**不碰冻结 CMakeLists**。
  只有真正新增独立翻译单元才被迫提案。
- `db_smoke` 链接域＝`TIME_ARC_DATABASE_SOURCES`（不含 `usage_stat_manager.cpp`、不含 `Qt6::Quick`）。放进该域的
  代码**不得引用 USM 符号**（保持 `DailyCardService` 既有约束）。
- **A1 唯一必然的冻结改动＝S4 的 `CHARTER` I2 修订（数据契约：SQLite 升主源）。** 这正是 A1 在 backlog 标
  「变更提案：是」的所在。`usage_paths` db 访问器是**条件性**（约定已实测成立，默认不加；如要单一事实源再加，那时它
  也是冻结改动 + 可能的 I2 字段扩展）。

---

## 4. 必须保留的语义（读侧切换的不变量，违反即用户可见回归）

1. **D5 前台+音频并集去重**（`rules/03` D5；`mergedIntervalSeconds` cpp:205）：同时段前台+音频不得双算。SQLite 源
   必须同时喂 `frontmost_sessions` + `media_sessions` 两侧区间，否则音频侧空、"活跃"总时长漂移。
2. **增量/重算守卫**（`docs/stats-backend-performance.md`）：JSONL 走字节偏移增量解析 + `recordsGeneration` 仅在
   真有新行时自增（cpp:627），驱动 Stats `rebuild()` 跳过无谓重算（StatsPage:380）。SQLite 源须给等价**廉价**
   高水位信号（`MAX(end_unix_sec)`/`MAX(id)`），否则 5s tick 要么每次重算（卡顿）要么永不刷新（陈旧）。
3. **读层过滤**（`setReadFilters`：游戏/分类/合并/逐项显隐/标题脱敏/软暂停，cpp:1419）只活在 USM 聚合层；切 SQLite
   须在聚合前同样施加，否则设置页读层过滤特性整体失效。
4. **live 快照**（`usage_current.json` + 15s 新鲜度门）无 SQLite 等价物——**保留 JSON live**，混合架构（SQLite 历史
   + JSON 实时）；注意 live 记录叠加在 `m_records` 之上时勿与已落库的同段历史重复计数。
5. **字段丰度**：USM 的分类/分组/图标键依赖 `app_id+app_name+path+window_title`；SQLite 仅 `app_identifier` →
   必须 JOIN `apps` 还原 `app_name`/icon，否则图标/分类相对 JSONL 退化。
6. **过滤一致性**：`platform=='windows'`（`frontmost_sessions` 无 platform 列，整库即 windows，须文档化）、
   `duration>0`/非空标识丢弃、本地时区分桶——SQLite 源须逐条复刻，保证逐窗口 parity。

---

## 5. 风险登记

- **路径身份**：service `make_db_path`（裸 `getenv(APPDATA)`）vs UI `QStandardPaths::AppDataLocation` 独立构造；
  本机相等，但改 org/app 名或测试模式（`setTestModeEnabled`）会**静默分裂读写库**。每环境复核。
- **schema 漂移**：service 与 UI 各自 `CREATE TABLE`，须定单一权威 + parity 断言（S1）。
- **WAL 双进程**：service 写 + UI 读同一 WAL 库，是 CLAUDE.md「两进程一磁盘」边界；UI 侧须只读式访问 + 兼容 WAL。
  回填若与 service 并发写更敏感（S3 只导启用前尾巴以最小化碰撞）。
- **计数校验陷阱**：419/267 差是合法去重/skip/尾巴，**不可用行数相等校验**（§0.3）。
- **空库假象**：翻转后若 DB 空/旧版 service，必须回退 JSONL（S4）。
- **parity 回归**：增量解析 + 并集去重经过精调；SQLite 源必须复刻同一筛选/分桶/去重，否则各页数字静默偏移。
- **遗留 QSettings 删除**：迁移标志可能在半成功置位；删除须单独带守卫（S5），不并进回填。

---

## 6. 验收口径（贯穿各 session）

- **数值 parity**：翻转前后（及 SQLite vs JSONL 自检）week/month/year/all 总时长、top 应用排行**逐项一致**
  （`stats-backend-performance` §5）；差异仅限可解释的去重/尾巴。
- **真机端到端**：必须真 service + 真 UI 跑（**非** `db_smoke`）；先 kill 锁 exe 再 `python .harness/tools/build.py`；
  Qt 跑后 `python .harness/tools/scan_qt_log.py`。
- **抓图**：PrintWindow-by-PID 抓**本实例**（min 1280×720 + 最大化），逐页对比翻转前后无视觉/数字回归。
- **harness**：每 session 收尾 `python .harness/tools/harness_check.py` exit 0；任何 L1/L2/L3 走 `record_error.py`。

---

## 7. 与既有文档 / playbook 的关系

- backlog 行动项：`docs/implementation-backlog.md §A1`（本文是其展开；§A1 现状已据本文校正）。
- 简洁 known gaps：`.harness/state/open-issues.md`「Storage」（已校正「no-op」旧述）。
- 契约与迁移规则：`.harness/rules/03-data-contract.md`（§1 文件表、D1 迁移须停服+备份、D5 并集、§4 契约变更=charter
  amendment + track-B）、`.harness/CHARTER.md`（I2 数据契约、I5 全有或全无、§3 冻结表、§4 修订流程）。
- 官方 5 步范式：`.harness/tracks/B-feature.md`「Playbook — SQLite migration」（步骤 1「实现 write_sqlite」已
  完成；本文 S2=步骤 2 只读消费者、S3=步骤 3 一次性迁移器、S4=步骤 4 翻转、S5=步骤 5 退役）。
- 性能 parity：`docs/stats-backend-performance.md`（增量解析 / 记忆化 / 重算守卫——S2 必须等价保留）。
- 迁移器范式对照：UI 既有唯一一次性迁移器 `SettingsRepository::migrateLegacyQSettings`（一次性 + settings 标志，
  但**无备份/无事务/无对账**）——S3 据此修正成「.bak + 事务 + 拒绝不一致」。

> 本文是计划，不是代码。每个 sub-session 仍须独立走 harness（preflight → 纵切 → build/scan → harness_check）。
