# D2 · 用户可选数据库路径 + 安全迁移流 · 实现启动（Kickoff / 多 session 拆分）

> 用途：把 `docs/implementation-backlog.md` §D2（数据运维）从「散落待办」展开成**带依赖、可逐 session 落地**的
> 执行计划。D2 是 Track **B**、跨进程（UI + service）、**碰 I2 数据契约（须变更提案 + CHARTER 修订）**、且
> **依赖服务侧配置通道（与 H5 同源，待签核）+ 服务构建/测试流水线**。本文先钉死**真实现状**，再给拆分、文件红线、
> 提案/门控边界、必须保留的不变量、风险与验收口径。
>
> **体例**参照 `docs/a1-sqlite-storage-migration-kickoff.md` / `docs/d1-export-backup-restore-kickoff.md`。
> **配套权威**：`.harness/CHARTER.md` §2（**I2 数据契约：db 路径是明文不变量**）+ §3 冻结表 + §4 修订流程；
> `.harness/rules/03-data-contract.md`（D1 迁移须停服 + 产备份）；
> H5 服务配置提案 `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（`usage_config.json`
> UI→service 通道，**待维护者签核**）；D1 kickoff `docs/d1-export-backup-restore-kickoff.md`（迁移原语先例）。
>
> 维护：完成一个 sub-session → 勾掉下表 + 移进 session log，并同步 `README.md §Roadmap` /
> `docs/implementation-backlog.md §D2`。

---

## 0. 现状校正（这是 D2 的起点）

### 0.1 DB 路径在**两处非冻结代码各自硬编码计算**（约定相等，无 setter/迁移）
- service：`make_db_path`（`src/service/windows/storage/usage_storage.c:59`）从 `getenv("APPDATA")`（退路
  `LOCALAPPDATA`）拼 `%APPDATA%\TimeArc\TimeArc\timearc.db`，建目录，**无任何 override hook**，结果存进
  `context->db_path`（`:556` 初始化时调用，`:272` 打开库）。
- UI：`DatabaseManager::databasePath()`（`src/services/database_manager.cpp:84`）= `QStandardPaths::AppDataLocation`
  + `timearc.db`。
- 两处**独立构造、靠约定相等**；A1 已加一次性分裂告警 `warnIfDbPathDivergesFromService`（`database_manager.cpp:34`）。
- **路径写死、用户不能选；无 setter、无迁移流。** 这正是 D2。

### 0.2 db 路径代码**非冻结**，但路径**值是 I2 明文不变量**
- frozen `usage_paths.{h,c}` 只暴露 usage dir / `usage_records.jsonl` / `usage_current.json` 三个访问器，
  **不含 db 路径**——所以 db 路径代码（make_db_path / databasePath）都在**非冻结**文件里。
- **但** `CHARTER` **I2** 明文把 db 路径记为契约：「SQLite path: `%APPDATA%\TimeArc\TimeArc\timearc.db`（service
  `make_db_path` 与 UI `QStandardPaths::AppDataLocation` 独立构造但相同）」。把它改成**可重定向**＝改 I2 文档不变量
  → **须 CHARTER amendment**（`CHARTER` §4：I2 触动须迁移计划 + bump 版本）。**这是 D2 与 D1 的关键差异**（D1 不碰 I2）。

### 0.3 D1 已产出可复用的迁移原语（D2 的机械层直接借用）
- 停服协调（无 in-app 一键停 → 引导用户用设置页「开机自动在后台采集」开关停；service 持库锁时诚实失败）；
- `VACUUM INTO` 一致快照 / 整库 copy；`-wal`/`-shm` 旁文件清理；`inspectBackup`（完整性 + 三契约表断言 + 计数/区间）；
- `*.pre-restore.bak` 先备份 + 失败回滚（`database_manager.cpp:735` 起 D1 三方法）。

### 0.4 真正的难点：**让两个进程都持久读到新路径**（决定 D2 的形态）
- db 路径是**计算**出来的、不是存储的。要支持用户选址，须有一个**固定位置、独立于可移动 db** 的「指针」——
  指针**不能放进会被移动的 db**（鸡生蛋）。
- 固定家＝ usage 目录（`%LOCALAPPDATA%\TimeArc\usage\`，由 frozen `usage_paths` 定、**不随 db 移动**）。最自然的
  载体＝ **H5 提议的 `usage_config.json` 服务配置通道**（UI→service 磁盘配置，提案已填、**待签核**）。D2 给它加一个
  `db_path` 键，UI 与 service **同源读取**；absent → 默认约定路径（向后兼容）。
- 推论：**D2 耦合 H5 的服务配置通道 + 必须有服务构建/测试流水线**（C 进程，UI 的 qml loop 验不了）。

---

## 1. D2 范围与落地顺序（依赖图）

```
S1 跨进程 DB 路径指针(契约扩展; 须 CHARTER I2 修订 + 提案 + 服务侧读) ──> S2 UI 迁移流(选址→停服→搬库→换指针→重启→回滚) ──> S3 预设/还原默认/网络盘守卫(未来)
```

依赖与门控：
- **A1-S1**（库已存在）✅；**D1 迁移原语** ✅（复用）。
- **H5 服务配置通道**（同一 `usage_config.json`，提案 `…20260609-0150-B-service-config-proposal.md` **待签核**）——
  D2-S1 的指针落在该通道，宜**合并/交叉引用同一份服务配置提案**。
- **CHARTER I2 修订 + 服务构建/测试流水线** —— S1 的硬门。

> **门控提醒**：D2-S1 在 CHARTER I2 修订签核 + 服务配置通道签核 + 服务可构建前**不能落代码**。本 kickoff 之后的
> **下一个具体动作不是写代码，而是填/合并变更提案送签**（可与 H5 提案合并为一份「服务配置通道 + db 重定向」）。

---

## 2. 多 session 拆分（逐张范围卡）

### S1 — 跨进程 DB 路径指针（契约扩展 · **须提案 + CHARTER I2 修订** · 服务侧 · Track B · 门控）
**目标**：建立一个两进程同源读取的 db 路径指针，缺失即回退默认（fail-safe），不引入 IPC、不破单实例。
- 指针：在 `usage_config.json`（usage dir，固定）加 `db_path`（绝对路径，可空/可缺）。
- service：`make_db_path` 改为**先读 config `db_path`**——非空且父目录可建/可写则用之，否则回退现约定路径
  （非冻结：改 `usage_storage.c` + `main.c` 读 config；若 H5 已落 config 读取则**共用同一读取**）。
- UI：`DatabaseManager::databasePath()` 同样**先读 config `db_path`**，否则 `QStandardPaths` 默认。两侧**同源**。
- **CHARTER I2 修订**（frozen `CHARTER.md`）：把「db 路径固定 `%APPDATA%…`」改为「**默认** `%APPDATA%…`，**可经
  `usage_config.json` 的 `db_path` 重定向；两进程同源读取该指针**」+ 迁移说明 + bump 版本。
- 文件红线：🟢 `usage_storage.c`、`src/service/windows/main.c`、`database_manager.{cpp,h}`。
  🔶 **冻结：`CHARTER.md`（I2 修订，须提案 + `frozen-files.json` 重生成）**。
- 变更提案：**是**（扩展契约 + 改 I2；与 H5 同源，宜合并）。门控：维护者签核 + 服务构建/测试。
- 验收：写 config `db_path` 指向新目录 → 重启 service + UI → 两者都读写**新库**；缺失 → 默认；坏/不可写路径 →
  回退默认 + 告警（**不 split-brain、不空库假象**）；服务 smoke 覆盖「config 读 db_path」。

### S2 — UI 迁移流（复用 D1 原语 · 主要非冻结 · Track B）
**目标**：从设置页一键把整库安全搬到用户所选目录，**先搬+校验新库 → 再切指针 → 后删旧库**，全程可回滚。
- 设置页（`DesktopProfilePage.qml`，并入「导入导出」或新「数据位置」卡）：选目录（folder dialog）→ 校验可写 +
  剩余空间（`QStorageInfo`）→ **要求先停后台采集**（同 D1 限制：无 in-app 一键停，引导用开关停；service 持锁则诚实失败）→
  `inspectBackup` 式校验现库 → 把现库 checkpoint 后整库落到新目录（`VACUUM INTO` 新位置 / 或 copy db+`-wal`/`-shm`）→
  **原子更新 config `db_path` 指针** → UI 重开新库 + 提示重启（让 service 重读指针）。
- **回滚/原子序**：新库写成并 `inspectBackup` 通过**之前**保留旧库；切指针失败/校验不过 → 回退旧指针 + 旧库；
  全程诚实失败（G6），**永不在切换中两边皆失**。成功且校验后才删旧库。
- 文件红线：🟢 `database_manager.{cpp,h}`、`DesktopProfilePage.qml`（指针写入复用 S1 的 config writer）。
- 变更提案：S1 已覆盖（S2 是 UI 消费侧）。
- 验收：**往返迁移**真机（默认 → 自定义 → 还原默认），真 service + 真 UI 两进程都跟随、数字不丢；坏路径 fail-safe。

### S3 — 预设 / 还原默认 / 盘符守卫（未来 · 本轮不做）
- 路径预设、一键「还原默认位置」、网络/可移动盘迁移后消失时 fail-safe 回退默认 + 告警、OneDrive 重定向守卫、
  剩余空间预警。列为后续。

---

## 3. 冻结文件与变更提案边界

**非冻结（可直接改）**：`src/service/windows/storage/usage_storage.c`（`make_db_path`）、
`src/service/windows/main.c`（读 config）、`src/services/database_manager.{cpp,h}`、
`qml/desktop/pages/DesktopProfilePage.qml`。

**冻结 / 须提案**：
- **`CHARTER.md`（I2 修订）—— D2 唯一必然的冻结改动**（与 D1 关键差异：D1 不碰 I2，D2 碰）。须先填
  `.harness/templates/change-proposal.md` 进 `journal/sessions/` + 重生成 `state/frozen-files.json` + bump 版本。
- **可选**：若决定加单一路径权威 `timearc_get_usage_db_path()` 进 frozen `usage_paths.{h,c}`（A1-S4 当时评估后
  **决定不加**）→ 那也是冻结改动；D2 默认**不加**，走非冻结 make_db_path/databasePath 各自读 config 指针。
- **耦合 H5**：`usage_config.json` 通道与 H5 提案同源，**宜把 D2 的 `db_path` 合并进同一份服务配置提案**送签，
  避免两份相邻提案。

**关键事实**：**须 SERVICE 构建/测试流水线**（C 进程；UI 的 qml 构建 loop 验不了 service 读 config）。

---

## 4. 必须保留的不变量

1. **I1 两进程一磁盘**：路径指针走**磁盘 config**，**不得引入 IPC/socket/shm**，不得从 UI 链 service 内部代码。
2. **I2 同源读取**：db 路径指针是新契约元素；UI 与 service **读同一份 `usage_config.json` 的同一键**，
   **永不各算各的**（否则 split-brain：一进程写新库、另一进程写旧库）。
3. **指针独立于可移动 db**：指针固定在 usage dir，**绝不**存进会被移动的 db（鸡生蛋）。
4. **fail-safe 默认**：指针缺失 / 解析失败 / 目标不可达 → 回退默认约定路径 + 告警，**绝不空库假象、绝不假成功（G6）**。
5. **原子切换 + 回滚**：先搬 + 校验新库 → 再切指针 → 后删旧库；任一步失败回退旧指针 + 旧库。
6. **单实例守卫（I1 named mutex）跨路径仍成立**：换库不改单服务保证。

---

## 5. 风险登记

- **split-brain（最严重）**：UI 读新库、service 仍写旧库 → 数据分裂。务必两进程**同源读指针** + 迁移**须停服** +
  **重启两端**；S1 的 fail-safe 与 S2 的原子序是主防线。
- **部分搬迁 / 中途崩溃**：原子指针切换 + 保留旧库直到新库 `inspectBackup` 通过。
- **网络/可移动盘迁移后消失**：fail-safe 回退默认 + 告警（S3 强化）。
- **指针损坏 / 手改 config**：解析失败回退默认路径。
- **服务侧改动需重建 + 测试**：service 是独立 C 进程，UI loop 验不了 → 须服务流水线（门）。
- **签核耦合**：D2-S1 依赖服务配置通道签核（与 H5 同源）+ CHARTER I2 修订签核；未签则 S1 不能落。
- **路径身份回归**：沿用 A1 的 `:34` 分裂告警，迁移后两进程路径仍须一致校验。

---

## 6. 验收口径（贯穿各 session）

- **真机端到端（含真 service）**：往返迁移（默认 ↔ 自定义 ↔ 还原默认），两进程都读写新库、数字不丢；坏/不可写路径
  fail-safe 回退默认 + 告警；缺失 config → 默认（向后兼容）。**须服务构建/测试流水线**。
- **服务 smoke**：覆盖「config 读 `db_path`」（非空用之 / 缺失回退 / 坏值回退）。
- **抓图**：PrintWindow-by-PID 抓设置页数据位置卡（min 1280×720 + 最大化）。
- **harness**：收尾 `python .harness/tools/harness_check.py` exit 0；**冻结改动（CHARTER I2）须配套提案 + 哈希更新**；
  任何 L1/L2/L3 走 `record_error.py`。

---

## 7. 与既有文档 / playbook 的关系

- backlog 行动项：`docs/implementation-backlog.md §D. D2`（本文是其展开；§D2 现状据本文校正、状态置 `[~]`）。
- 迁移原语先例：`docs/d1-export-backup-restore-kickoff.md` + `database_manager.cpp:735`（停服/copy/sidecar/inspect/
  pre-restore.bak 回滚，D2 机械层直接复用）。
- 路径身份与冻结访问器评估：`docs/a1-sqlite-storage-migration-kickoff.md`（§3 `usage_paths` db 访问器**当时决定不加**；
  `database_manager.cpp:34` 分裂告警）。
- **服务配置通道（D2-S1 指针的家）**：`.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`
  （H5：`usage_config.json` UI→service 磁盘通道，**待签核**；D2 的 `db_path` 宜合并进同一提案）。
- 契约与修订流程：`.harness/CHARTER.md`（I2 db 路径不变量、§3 冻结表、§4 修订须迁移计划 + bump 版本）、
  `.harness/rules/03-data-contract.md`（D1 迁移须停服 + 产备份）。

> 本文是计划，不是代码。D2-S1 受**契约修订 + 服务配置通道签核 + 服务构建流水线**门控；下一步是**送签变更提案**，
> 而非直接实现。每个 sub-session 仍须独立走 harness（preflight → 纵切 → build/scan → harness_check）。
