# D1 · SQLite 整库 导出/备份/恢复 · 实现启动（Kickoff / 多 session 拆分）

> 用途：把 `docs/implementation-backlog.md` §D1（数据运维）从「散落待办」展开成**带依赖、可逐 session 落地**的
> 执行计划。D1 是 Track **B**、跨平台 UI 工作、**A1 解锁的第一个正向依赖项**（`A1 → D1 → D2`）。本文先钉死**真实
> 现状**，再给拆分、文件红线、变更提案边界、必须保留的语义、风险与验收口径。
>
> **体例**参照 `docs/a1-sqlite-storage-migration-kickoff.md` / `docs/stats-implementation-kickoff.md`（每 session
> 一张可粘贴的范围卡）。
> **配套权威**：`.harness/rules/03-data-contract.md`（**D1「Append-only history」= 迁移须停服 + 产备份**，:51-53）、
> `.harness/CHARTER.md` §2（I1 两进程一磁盘 / I2 数据契约 / I5 全有或全无）+ §3（冻结表）、
> `docs/b1-windows-service-scm-kickoff.md`（停采集通道 `Local\TimeArcStop`）。
>
> 维护：完成一个 sub-session → 勾掉下表 + 移进 session log，并同步 `README.md §Roadmap`（:569）/
> `.harness/state/open-issues.md`（Storage）/ `docs/implementation-backlog.md §D1`。

---

## 0. 现状校正（这是 D1 的起点）

### 0.1 已有「导出」——只是**偏好/报告 JSON**，不是整库
- `UsageStatManager::exportReport(fileBaseName, jsonContent)`（`src/services/usage_stat_manager.cpp:1651`）：把 UI
  组装好的 JSON 写到 Download→Documents→usageDataDir 级联目录，文件名净化，**短写报失败（不假成功）**，返回完整
  路径 / 失败空串。消费者＝统计页导出、设置页「导出设置 JSON」（`DesktopProfilePage.qml:329 doExport`）。
- **它是报告文件，不是 usage 数据**（注释 :1653 明示「不动磁盘契约、不写 usage/SQLite」）。
- 设置页「导入」＝`settingsRepository.readTextFile` 读所选 JSON → 逐键 `setValue` 写 `settings` KV
  （`DesktopProfilePage.qml:374 doImport` + `:389 FileDialog`），**只动设置 KV，不碰 usage/契约**。

### 0.2 **无整库备份/恢复**——这正是 D1
- 全仓没有任何「复制/恢复整个 `timearc.db`」的路径。`DesktopProfilePage.qml:366 clearUiCache()` 的注释已显式留坑：
  「仅清 UI 私有/派生缓存（窗口几何）：**不动 usage 历史(D1)**、设置偏好、备忘内容」——即整库备份/恢复被预留为 D1。
- `README.md:569`：`- [ ] Add export/backup and restore flows for SQLite-backed desktop data.`（D1 顶层路线项，未做）。

### 0.3 DatabaseManager 现有事实（D1 的扩展点）
- `src/services/database_manager.{h,cpp}`（**非冻结**）已是 QML context property `databaseManager`
  （`src/main.cpp:137`），已暴露 `Q_INVOKABLE QString getDatabasePath()`（`database_manager.h:16`）。
- 库路径 = `databasePath()`（`database_manager.cpp:84`）= `QStandardPaths::AppDataLocation` + `timearc.db`
  （= `%APPDATA%\TimeArc\TimeArc\timearc.db`，与 service `make_db_path` 约定相等，已加一次性分裂告警
  `warnIfDbPathDivergesFromService` :34）。
- 库以 **`PRAGMA journal_mode = WAL`** 打开（`database_manager.cpp:75`）+ `busy_timeout=5000`、`foreign_keys=ON`。
- **已有可复用的「.bak + 事务 + 对账 + 幂等标志」范式**：A1-S3 `backfillUsageFromJsonl()`（`database_manager.cpp:447`）
  先写 `.bak`（注释 :558 引用「rules/03 D1」）→ `BEGIN IMMEDIATE` → 导入 → **按唯一键存在性对账（非行数）** → 失败
  ROLLBACK 留原样 → settings 布尔标志幂等。**D1 的备份/恢复安全姿态直接沿用此范式。**
- `UsageStatManager` 辅助：`fileSizeBytes(path)`（:1678）、`recordCount()`（:1688）、`exportReport` 的目录级联可复用。

### 0.4 两进程并发现实（决定恢复路径的难点）
- 后台 service 以 WAL **持同一 `timearc.db` 句柄并实时双写**（A1 后 SQLite 升主源，service dual-write JSONL+SQLite）。
- **备份**＝只读快照，与 live 写并发安全（WAL 读者不阻塞写者；`VACUUM INTO` 取一致快照）。
- **恢复**＝替换 live 库文件，在 service 句柄下替换＝损坏 / Windows 文件锁失败风险 → **必须停采集 + 重启**
  （`rules/03 D1`：迁移须服务停止 + 产备份；B1 提供 `Local\TimeArcStop` 优雅停采集通道）。

---

## 1. D1 范围与落地顺序（依赖图）

```
S1 整库备份(VACUUM INTO 一致快照) ──> S2 校验 + 恢复(停服 + .pre-restore.bak + 重启) ──> S3 保留/自动备份(未来,本轮不做)
```

- **S1** 是 MVP 纵切：只读、不可能伤 live 数据、高价值、立即可用。**无冻结改动、无变更提案。**
- **S2** 是敏感纵切：恢复须校验候选库 + 先备份当前库 + 与实时双写 service 协调（停采集）+ 提示重启。仍**无冻结改动**。
- **S3** 退保留策略/启动自动备份属未来，**本轮不做**。

> 提醒（CLAUDE.md 硬规则）：每个 sub-session **只走一条 track（全程 B）+ 最小可运行纵切**。不要把 S1+S2 混进一个
> session（同为 B 时是「范围纪律」问题，仍应按纵切拆：先 S1 备份落地验收，再 S2 恢复）。

---

## 2. 多 session 拆分（逐张范围卡）

### S1 — 整库备份（MVP 纵切 · 无冻结改动 · Track B） · ✅ 已实装（PR #40，2026-06-10）
**目标**：一键把整个 `timearc.db` 导出成一份**一致**的单文件备份到用户可见目录，只读、不扰动 live。
- C++（折进 `database_manager.{h,cpp}`）：`Q_INVOKABLE QString backupDatabase()`。
  - 用 **`VACUUM INTO 'dst'`**（**不是** `QFile::copy`）——产出单文件一致快照，隐式 checkpoint WAL 进副本，避免漏掉
    `-wal` 里未合并的写入；只读、不动源库。
  - 目标目录复用 `exportReport` 级联：`DownloadLocation`→`DocumentsLocation`→AppData；文件名
    `timearc-backup-YYYYMMDD-HHMMSS.db`（时间戳避免覆盖）。
  - 诚实失败（G6）：VACUUM 失败 / 目录不可写 / 写盘短写 → 返回**空串**（不假成功）；成功返回完整路径。
- QML（`DesktopProfilePage.qml`「导入导出」tab）：「备份数据库」按钮 → `backupDatabase()` → `showToast` 显示产物路径
  或失败；存储概览（`refreshStorage` :167）可顺带显示库大小（`fileSizeBytes(getDatabasePath())` 已在用）。
- 文件红线：🟢 `database_manager.{cpp,h}`、`DesktopProfilePage.qml`。⛔ 不新增 .cpp/.h（否则动冻结
  `src/CMakeLists.txt`）、不碰 `src/service/shared/*`、不碰 `usage_paths.*`。
- 变更提案：**否**（无冻结改动、不碰 I2）。
- 验收：先 kill `TimeArc.exe`（exe 锁）→ `python .harness/tools/build.py`；跑一次 → 产物存在；用独立 sqlite/Qt 打开
  `PRAGMA integrity_check` = `ok`、三张契约表 `apps/frontmost_sessions/media_sessions` 行数与源库一致；
  `python .harness/tools/scan_qt_log.py`；PrintWindow-by-PID 抓设置页（min 1280×720 + 最大化）；`harness_check` exit 0。

### S2 — 校验 + 恢复（敏感纵切 · 无冻结改动 · Track B） · ✅ 已实装（PR #40，2026-06-10）
**目标**：从一份备份 `.db` 安全恢复整库，**先校验、先自备份、停服协调、提示重启**，绝不在不确定时假成功。
- C++（折进 `database_manager.{h,cpp}`）：
  - `Q_INVOKABLE QVariantMap inspectBackup(const QString& path)`：**只读**打开候选库（独立连接名，结束即关）→
    `PRAGMA integrity_check` + **断言 `apps`/`frontmost_sessions`/`media_sessions` 三表存在**（schema 兜底，拒绝
    随机 .db）→ 返回 `{ok, integrity, frontmostRows, mediaRows, minDate, maxDate, sizeBytes}` 供 UI 预览校验。
  - `Q_INVOKABLE bool restoreDatabase(const QString& path)`：① `inspectBackup` 不过 → 直接 false；② 当前库先存
    `timearc.db.pre-restore.bak`（沿用 S3 `.bak` 范式，可回滚）；③ **关 `QSqlDatabase` 连接**（释放 UI 句柄）；
    ④ 替换库文件 + **清理陈旧 `-wal`/`-shm` 旁文件**（防新库配旧 WAL）；⑤ 失败/锁文件冲突 → 还原 `.pre-restore.bak`
    + 返回 false（诚实报错）。
- 停采集协调：恢复前须经 B1 `Local\TimeArcStop` 优雅停采集（service 放开句柄），恢复后**提示用户重启 app**
  （UI 句柄已重置；service 重新自启会对新库继续追加）。**权威＝`rules/03 D1`：迁移须服务停止 + 产备份。**
- QML（设置页）：「恢复数据库」按钮 → `FileDialog`（`nameFilters: *.db`）选文件 → `inspectBackup` 预览（行数/日期范围/
  完整性）→ `askConfirm(..., danger=true, ...)`（`DesktopProfilePage.qml:350` 已有二次确认范式）→ `restoreDatabase`
  → `showToast` 结果 + 重启提示（含「请先在后台采集开关停采集」引导）。
- 文件红线：🟢 同 S1。⛔ 同 S1。变更提案：**否**（替换库**内容**不改 schema/字段/路径 → 不触发 I2 charter amendment；
  与 A1-S4 的关键差异）。
- 验收：**往返**真机验证——备份 → 人为改库（删几条）→ 恢复 → 数字复原；`integrity_check` 通过；坏 .db / 非 TimeArc .db
  被 `inspectBackup` 拒绝；锁文件冲突走还原分支不假成功；逐页抓图无回归；`harness_check` exit 0。

### S3 — 保留策略 / 自动备份（未来 · 本轮不做）
- 滚动保留最近 N 份、启动时自动备份、可选目录设置。列为后续；与 D2（用户可选数据库路径迁移）相邻（D2 若含「迁移后
  改读新路径」会与冻结 `usage_paths` db 访问器耦合，**那才是冻结改动**——D1 本身不碰）。

---

## 3. 冻结文件与变更提案边界

**非冻结（可直接改）**：`src/services/database_manager.{cpp,h}`、`src/services/usage_stat_manager.{cpp,h}`、
`qml/desktop/pages/DesktopProfilePage.qml`、`src/main.cpp`（入口，敏感但非冻结，慎改/本轮多半不需）。

**冻结（改前须先填 `.harness/templates/change-proposal.md` 进 `journal/sessions/` + 更新 `state/frozen-files.json`）**：
`src/service/shared/{data_bridge.h, database_path.h, database_path.c, app_info.h, app_env.h}`、
`src/include/util.h`、`CMakeLists.txt`(顶层)、`src/CMakeLists.txt`、
`src/service/CMakeLists.txt`、`.harness/CHARTER.md`、`.harness/AGENTS.md`、`AGENTS.md`。

**关键事实**：
- sqlite3 **已链入** UI（`Qt6::Sql`）。`VACUUM INTO` 需 SQLite ≥ 3.27（2019）——Qt6 自带的 SQLite 远新于此，**无需动
  任何 CMake / 不新增依赖**。
- **避让技巧**（统计页/设置页/A1 同款）：所有新逻辑**折进已登记的现有 .cpp**（`database_manager.cpp`），就**不碰冻结
  `CMakeLists`**。只有真正新增独立翻译单元才被迫提案。
- **D1 的关键差异**：与 A1-S4 不同，D1 **不修订 I2 数据契约**——备份是只读副本；恢复只替换库**内容**，不改 schema/字段/
  路径。故 **D1 全程无冻结改动、无变更提案**（backlog §D1 标「提案：否」即此）。

---

## 4. 必须保留的语义 / 不变量

1. **两进程一磁盘（I1）**：D1 全程**只经磁盘**（读/写库文件、读 B1 的命名停采集事件），**不得引入 IPC/socket/共享内存**，
   不得从 UI 链 service 内部代码。停采集走 B1 既有 `Local\TimeArcStop` 通道，不新造控制面。
2. **备份只读、不扰 live**：`VACUUM INTO` 取一致快照，不写源库、不阻塞 service 写入；备份**绝不**改动 `timearc.db`。
3. **恢复须停服协调 + 自备份（rules/03 D1）**：替换 live 库前停采集 + 先存 `*.pre-restore.bak`；失败可回滚；提示重启。
4. **诚实失败（G6）**：任何失败（VACUUM 失败 / 目录不可写 / 短写 / 校验不过 / 锁冲突）→ 返回空串/false + toast 实情，
   **绝不写死假成功**（沿用 `exportReport` 短写报失败、设置页 `askConfirm` 不假成功的既有姿态）。
5. **校验先行**：恢复前 `inspectBackup` 必须 `integrity_check` + 断言三张契约表存在，拒绝随机/损坏 .db（防把垃圾灌成主库）。
6. **WAL 旁文件一致**：恢复替换库时清理陈旧 `-wal`/`-shm`，避免新库配旧 WAL 造成读写错乱。

---

## 5. 风险登记

- **WAL 一致性**：裸 `QFile::copy` 会漏未 checkpoint 的 `-wal` 数据 → **改用 `VACUUM INTO`**（一致快照）。
- **恢复与实时双写并发**：service 持同库句柄 → 替换文件须**先停采集 + 关 UI 连接 + 重启**；否则损坏/锁失败（最敏感项）。
- **Windows 文件锁**：被占用的 `timearc.db` 在 Windows 上替换会失败 → 走「停采集 → 关连接 → 替换 → 失败还原」分支，
  诚实报错不假成功。
- **磁盘满 / 短写**：备份写盘失败 → 返回空串报失败（沿用 `exportReport` 短写姿态）。
- **坏备份灌库**：恢复前未校验会把损坏/无关 .db 变主库 → `inspectBackup` 完整性 + 三表断言前置拦截。
- **路径身份**：库路径取自 DatabaseManager（与 service `make_db_path` 约定相等，已有 :34 一次性分裂告警）；改 org/app
  名或测试模式会分裂——沿用 A1 既有告警，不在 D1 新增冻结访问器。

---

## 6. 验收口径（贯穿各 session）

- **真机端到端**：必须真 service + 真 UI 跑；build 前 kill `TimeArc.exe`（exe 锁）→ `python .harness/tools/build.py`；
  Qt 跑后 `python .harness/tools/scan_qt_log.py`。
- **备份产物校验**：用独立 sqlite/Qt 打开备份 → `PRAGMA integrity_check` = ok、三张契约表行数与源一致。
- **恢复往返**：备份 → 人为改库 → 恢复 → 用户可见数字复原；坏 .db 被拒；锁冲突走还原分支。
- **抓图**：PrintWindow-by-PID 抓**本实例**设置页（min 1280×720 + 最大化），导入导出 tab 无视觉回归。
- **harness**：每 session 收尾 `python .harness/tools/harness_check.py` exit 0；任何 L1/L2/L3 走 `record_error.py`。

---

## 7. 与既有文档 / playbook 的关系

- backlog 行动项：`docs/implementation-backlog.md §D. D1`（本文是其展开；§D1 现状据本文校正、状态置 `[~]`）。
- 简洁 known gaps：`.harness/state/open-issues.md`「Storage」（加 D1 指针）；顶层路线：`README.md:569`（加本文链接）。
- 契约与迁移规则：`.harness/rules/03-data-contract.md`（**D1「Append-only history」:51-53 = 迁移须停服 + 产备份**，
  这是 D1 恢复路径的直接权威）、`.harness/CHARTER.md`（I1 两进程一磁盘、I2 数据契约、I5 全有或全无、§3 冻结表）。
- 停采集通道：`docs/b1-windows-service-scm-kickoff.md` + B1 实装（`Local\TimeArcStop`，PR #37）——恢复停服复用此通道。
- 同避让技巧 / 安全范式：`docs/a1-sqlite-storage-migration-kickoff.md`（§3 避让冻结 CMake；S3 `.bak`+事务+对账幂等
  范式＝D1 恢复安全姿态的直接先例，`database_manager.cpp:447`）。
- UX 衔接：`docs/settings-remaining-work.md` + `DesktopProfilePage.qml`「导入导出」tab（`doExport`/`doImport`/
  `askConfirm`/`FileDialog`/`clearUiCache` 既有范式，备份/恢复按钮顺势并入）。

> 本文是计划，不是代码。每个 sub-session 仍须独立走 harness（preflight → 纵切 → build/scan → harness_check）。
