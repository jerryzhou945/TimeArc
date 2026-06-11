# H5 · 服务侧配置通道（空闲超时 / 真停采集 / 删除历史）· 实现 Kickoff

> 用途：把 `docs/implementation-backlog.md §H5` 从「待办」展开成**带依赖、可逐 session 落地**的执行计划。
> H5 让设置页里现为「软暂停 + 受限标注」的 **空闲超时 / 真停采集** 真正生效，并就 **删除历史** 拍板。
>
> **体例**参照 `docs/d2-database-path-migration-kickoff.md` / `docs/d1-export-backup-restore-kickoff.md`。
> **配套权威**：已填变更提案 `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`
> （**待维护者签核**）；`.harness/rules/03-data-contract.md`（磁盘契约）；`CHARTER` I1（两进程只经磁盘、无 IPC）。
>
> **状态：未起（门控）。** 下一步是**送签上面那份提案**——签核后才落代码。本文是计划，不是代码。

---

## 0. 现状校正（H5 的起点 —— D2 已把地基铺好）

- 设置页持久化 `idle_timeout`（分钟串 "5/10/15/30"）+ `track_running`（bool）进 SQLite `settings` 表，但
  **服务侧只用编译期 `#define`**：`usage_tracker.h:7 TIMEARC_USAGE_IDLE_THRESHOLD_MS=60000`；`track_running` 仅 UI 软暂停
  （读层过滤），**service 照常采集写盘**。两项 UI 现挂「受限」标注（诚实 G6）。
- **删除历史**：`usage_records.jsonl` 追加-only（`rules/03` D1）+ SQLite，应用内无删除；现「清空缓存」只清 UI 私有派生。
- **D2 已建好 H5 需要的全部通道原语**（这是 H5 现在低成本的原因）：
  - 固定 `usage_config.json`（usage dir）+ service 用 **vendored Parson** 读它（`usage_storage.c::read_config_db_path`
    已示范 `json_parse_file`，Parson 已链、无 CMake 改动）；
  - UI 侧 `usage_config.json` 的**原子 RMW 写**（D2 `DatabaseManager::writeDbPathPointer`：QSaveFile + 保留其他键）；
  - **服务生命周期控制**（D2 `SettingsRepository::stopBackgroundCollection` / `isBackgroundCollectionRunning`，复用
    `runServiceVerb` 调 `--stop`/`--start`/`--status`）——让 UI 能「写配置 → 重启采集令其立即生效」。
- **关键事实**：`TimeArcUsageTrackerConfig`（`usage_tracker.h`，**非冻结**）**已含 `idle_threshold_ms`**，main.c 现用
  `#define` 填它再传给 `timearc_usage_tracker_run`。所以 idle 接线＝改 main.c 读 config 填这个字段，**tracker 一行不用动**。

---

## 1. 范围与落地顺序（依赖图）

```
（签核提案）──> S1 service 读 config 应用 idle/track ──> S2 UI 写 config + 接线 + 重启生效 + 去「受限」标注
                                                       └─> S3 删除历史(G-CLEAR) 决策（默认暂缓，除非产品要 purge 工具）
```

门控：**S1 在提案签核前不能落代码**（扩展契约方向 UI→service + 覆盖 A-TRACKPAUSE）。服务构建/测试流水线已被 **D2 去风险**
（本机可 `build.py` 编出 + 跑真 `time-arc-service.exe` E2E）。

---

## 2. 子 session 拆分（逐张范围卡）

### S1 — service 读 usage_config.json 应用 idle/track（服务侧 · Track B · 门控）
**目标**：service 启动时读 `usage_config.json` 的 `idle_threshold_ms` + `track_enabled`，缺失则回退编译期默认（向后兼容）。
- 读取：在 `usage_storage.c` 加一个**非 static 的共享读取器**（如 `int timearc_read_service_config(int64_t* idle_ms, int* track_enabled)`，
  一次 `json_parse_file` 取两键；缺/坏→不改出参，调用方保留默认）。**复用 D2 的 Parson 路子，零 CMake 改动、零新 TU**
  （新增 .c/.h 会动冻结 `src/service/CMakeLists.txt`——禁止）。
- idle：`main.c` 读 `idle_threshold_ms` 填进已有的 `TimeArcUsageTrackerConfig.idle_threshold_ms`（tracker 不动）。
- track：给 `TimeArcUsageTrackerConfig` **加字段 `int track_enabled`**（`usage_tracker.h` 非冻结），`track_enabled=0` 时
  tracker 主循环**跳过持久化**（不写 history；live 快照按需——建议也停，"真停"语义）。startup-read（重启生效），与 idle 一致。
- 文件红线：🟢 `usage_storage.c`、`src/service/windows/main.c`、`usage_tracker.{c,h}`（**全非冻结**）。
- 验收（service smoke，真二进制）：写 `{idle_threshold_ms:300000, track_enabled:false}` → 跑 service → (a) idle 用 300s
  （建议加一行 stderr 回显应用值便于验）、(b) 暂停期间**无新记录**（前后比 jsonl/db 行数不增）、(c) 缺文件→默认。

### S2 — UI 写 config + 接线 + 重启生效 + 去「受限」标注（主非冻结 · Track B）
**目标**：设置页的「空闲超过」选单 + 「追踪正在运行的应用」开关在持久化 SQLite 的同时，**写进 `usage_config.json`** 让服务读到，
并提供「应用并重启采集」让其立即生效；真生效后摘掉对应「受限」标注。
- 写：`SettingsRepository` 加 `writeServiceConfig(idleMs, trackEnabled)`（**RMW** usage_config.json，**保留 D2 的 `db_path` 键**；
  QSaveFile 原子写——与 D2 writer 互不覆盖键）。UI 把分钟→ms 换算（"5"→300000）。
- 接线：`idle_timeout` 选单 onActivated / `track_running` 开关 onToggled → 既 `_setStr/_setBool`（SQLite）又
  `settingsRepository.writeServiceConfig(...)`。
- 立即生效（D2 红利）：提供「应用并重启采集」＝`stopBackgroundCollection()` 后 `--start`（经 `runServiceVerb`），让新 config 即时生效；
  否则提示「下次启动采集生效」。**注意**：track 关→服务停采集；务必文案讲清，避免用户以为只是 UI 暂停。
- 标注：idle/track 真生效后去掉「受限」「（仅 UI）」字样；仍受限的（若有）保留诚实标注（G6）。
- 文件红线：🟢 `settings_repository.{cpp,h}`、`qml/desktop/pages/DesktopProfilePage.qml`。
- 验收：真机往返——设置 idle=5min/关闭追踪 → 应用并重启 → 真 service 读到（idle 生效、暂停期无新记录）；抓设置页「追踪与应用」卡。

### S3 — 删除历史（G-CLEAR）· **决策卡（默认本轮不写码）**
- `usage_records.jsonl` + SQLite 是 append-only（I2/D1）。**真删**须二选一：**(A)** `CHARTER §2` 修订定义删除/轮转策略（冻结改动 + 迁移说明）；
  **(B)** 停服 + 外部 purge/迁移工具（一次性、可复用 D1 停服原语 + D2 `--stop`）。
- **建议：暂缓**，保持 A-CLEAR（仅清 UI 私有缓存）+ 诚实标注，**除非产品明确要 purge 工具**。**禁止** JSONL 原地重写（毁 append-only + 增量读者）。
- 产出：本卡是**决策点**，不是默认实现项；产品拍板要 purge 才另开 session（届时碰 I2 → 走变更提案 + CHARTER 修订）。

---

## 3. 冻结边界与变更提案

- **非冻结（可直接改）**：`usage_storage.c`、`main.c`、`usage_tracker.{c,h}`、`settings_repository.{cpp,h}`、`DesktopProfilePage.qml`。
- **务必折进现有 TU**：新增 service `.c/.h` → 动冻结 `src/service/CMakeLists.txt` → 禁止（提案明确）。
- **变更提案**：H5 的 `20260609-0150-B-service-config-proposal.md` **已填、待签核**——它扩展磁盘契约（新增 UI→service 方向）
  且覆盖产品决策 A-TRACKPAUSE，故须签核。S3(A)（删除策略碰 I2）若做须**另填** CHARTER 修订提案。

## 4. 必须保留的不变量
1. **I1 两进程一磁盘**：配置走磁盘 `usage_config.json`，**不引 IPC/socket/shm**，UI 不链 service 内部。
2. **fail-safe 默认**：config 缺/坏/键缺 → service 用编译期默认（＝今天行为，向后兼容）；绝不假成功（G6）。
3. **键共存**：`usage_config.json` 同时承载 D2 `db_path` 与 H5 `idle_threshold_ms`/`track_enabled`——两侧写都须 **RMW 保留对方键**。
4. **append-only**：H5 不删既有记录；`track_enabled=false` 只**暂停新采集**，不回溯删除。
5. **startup-read 一致**：idle/track 启动时读、重启生效；UI「应用并重启采集」是即时生效的唯一受支持路径。

## 5. 风险登记
- **静默停采集**：`track_enabled=false` 让服务真的不再记录——UI 文案与「受限→真停」标注切换务必讲清，否则用户以为只是 UI 暂停。
- **单位错位**：UI `idle_timeout` 是**分钟**、服务要 **ms**；换算错→空闲判定离谱。S1/S2 各加断言/默认夹取。
- **键互覆盖**：H5 writer 漏保 `db_path`（或 D2 writer 漏保 H5 键）→ 迁移/配置互毁。两 writer 都走 RMW + 测试覆盖「写一键不丢另一键」。
- **服务流水线**：service 是独立 C 进程，UI loop 验不了——须真二进制 smoke（D2 已示范可行）。
- **删除历史诱惑**：别为 G-CLEAR 走 JSONL 原地重写；要真删必过契约修订或 purge 工具。

## 6. 验收口径
- **service smoke（真二进制）**：idle 配置生效 / 暂停期无新记录 / 缺 config → 默认。
- **UI 往返**：设置 → 写 config → 应用并重启 → 真 service 读到；`db_path` 与 idle/track 同文件互不丢键（加 db_smoke / 手测）。
- **抓图**：PrintWindow-by-PID 抓「追踪与应用」卡（min 1280×720 + 最大化）；`scan_qt_log` 干净。
- **harness**：`harness_check.py` exit 0；冻结改动（若 S3(A)）配套提案 + 哈希更新；L1/L2/L3 走 `record_error.py`。

## 7. 与既有文档 / PR 的关系
- backlog 行动项：`docs/implementation-backlog.md §H5`（本文是其展开）+ `§G1`（Parson 接线，D2 已部分兑现：service 已用 Parson）。
- 通道/原语先例：**D2** `docs/d2-database-path-migration-kickoff.md` + `database_manager.cpp`（`usage_config.json` RMW writer、Parson reader、
  `SettingsRepository` 服务控制）——H5 直接复用。
- 服务配置提案（H5 指针的家）：`.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（**待签核**）。
- 契约与边界：`.harness/CHARTER.md`（I1/I2、§3 冻结表、§4 修订）、`.harness/rules/03-data-contract.md`、设置页审计 `docs/settings-remaining-work.md`。

> 受**提案签核**门控。签核后建议顺序：S1（服务读+应用）→ S2（UI 写+接线+重启生效+去「受限」）→ S3 仅在产品要 purge 时另起。
