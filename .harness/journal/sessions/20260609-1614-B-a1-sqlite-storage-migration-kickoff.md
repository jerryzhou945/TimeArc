# Session — A1 SQLite 主数据源迁移 · Kickoff（计划 + 前置变更提案）

本 session 只产出**计划文档**（不改代码、不动冻结文件）。详细计划见
`docs/a1-sqlite-storage-migration-kickoff.md`。本文＝Track B session log ＋ A1 全弧**前置变更提案**
（S4 改冻结 `CHARTER` 前据此补全签核）。

## Metadata
- Author: Claude Code (Opus 4.8)
- Track: **B (Feature)** — A1 是新能力（SQLite 升主数据源）。
- Date: 2026-06-09 16:14 (local)
- Branch: `feat/a1-sqlite-storage-migration`（基于 `dev`，PR 进 `dev`）
- Related: `docs/implementation-backlog.md §A1`、`rules/03 §4`、`tracks/B-feature.md` Playbook。

## 设计：Service 侧 / UI 侧（Track B 必填）
- **Service 侧（已实装，A1 不重写）**：`time-arc-service` 经 `usage_storage.c` 对每个完成会话**双写**
  JSONL（追加）+ SQLite（`frontmost_sessions`/`media_sessions`/`apps`，WAL，`INSERT OR IGNORE` 去重）。
  `init(&g,1,1)` 已默认启用。A1 仅在 S1 去过时注释、定 schema/路径单一权威；S5 才停 JSONL 写。
- **UI 侧（A1 主战场）**：`UsageStatManager` 当前只读 JSONL/current。A1 给它加 SQLite 读源（S2，folded
  进现有 .cpp，flag OFF）→ 一次性回填启用前 JSONL 尾巴（S3，.bak+事务+对账）→ 翻转主源+JSONL 兜底（S4）。
  保留 D5 并集 / 增量守卫 / 读层过滤 / live 快照 / 字段丰度（见 kickoff §4）。

## 现状校正（实测 2026-06-09，证据见 kickoff §0.3）
- backlog 旧述「service `write_sqlite` 是 no-op」**过时**：写侧已完整实装并在生产启用。
- DB 实存：`frontmost_sessions` 31,024 行、`media_sessions` 21,395 行，头部与 JSONL（31,443/21,662）对齐；
  DB 起点晚 ~73 min＝待回填尾巴；行差 419/267 主因合法去重 → **禁用行数相等校验**。
- `schema_migrations` 0 行（休眠）。`usage_storage.h`/`storage_context.h` 注释仍写「stubbed」需改正。

## 1. 冻结文件（本 session 触碰：无；A1 全弧规划触碰）
- 本 commit 改的全是非冻结/state：`docs/*`、`.harness/state/open-issues.md`、本 session log。**无冻结改动。**
- **A1 全弧唯一必然冻结改动＝S4**：`.harness/CHARTER.md` **I2 修订**——`timearc.db` 升为一等「主」契约文件
  （定义规范路径 + schema + reader=UI 主源），bump 版本号；据 `rules/03 §4` 写迁移说明。
- **条件性**：`src/service/shared/usage_paths.{h,c}` 仅当决定加单一 `timearc_get_usage_db_path()` 访问器才动
  （本机路径约定已实测成立，默认不加）。其余全程用「折进现有 .cpp」避开冻结 `CMakeLists`（sqlite3 已链入两端）。

## 2. Motivation
A1 是 backlog keystone（解锁 D1 导出 / D2 路径迁移，也是 README 头号 limit）。写侧已就绪但 UI 仍读 JSONL，
SQLite 历史未被消费、启用前尾巴未回填、路径/schema 双源可漂移、注释过时。不做：双源长期漂移风险、JSONL 无法退役、
导出/备份无法以 SQLite 为单一源推进。

## 3. Impact on the other process
| Side | Effect |
|------|--------|
| Producer (service) | S1 仅去过时注释 + schema 兼容断言；写行为不变（仍双写）。S5 才停 JSONL 写。 |
| Consumer (UI) | S2 加 SQLite 读源（默认 OFF）；S3 回填尾巴；S4 翻转主源 + JSONL 兜底。公开 `Q_INVOKABLE` API 不变。 |

## 4. Migration plan（详见 kickoff §2 S3 / §0.4 字段映射）
- 旧记录：JSONL 追加（含重复 + 启用前尾巴）；live `usage_current.json`。
- 新记录：SQLite `frontmost_sessions`(前台)/`media_sessions`(音频)/`apps`，唯一键 `(app_identifier,
  window_title,start,end)` 去重。
- 共存：service 持续双写；UI 回填**只导 `start < DB_min` 尾巴**（service 永不再写该段，碰撞最小），
  先 `usage_records.jsonl.bak`，事务内 `INSERT OR IGNORE`，**对账按唯一键存在性**（非行数相等），缺真实记录则
  回滚 + 保留 JSONL + 不置标志。幂等守卫＝settings 标志 `usage_jsonl_backfill_v1_done`。停服/WAL 见 rules/03 D1。

## 5. Rollback plan
- S2/S3：flag 默认 OFF + 幂等标志 → 代码 revert 即可，JSONL 仍为唯一主源，无数据损失。
- S4：翻转后若 parity/空库异常 → 关 flag 回 JSONL（数据双在，纯读源切换，代码 revert 充分）。
- JSONL 写入保留 N 版作安全网；`.bak` 可恢复回填前 JSONL。

## 6. Test plan
- 现状复现：探针脚本读 DB/JSONL 计数（已记于 §现状校正）。
- 验证：S2 parity 自检（SQLite vs JSONL 同窗口逐项一致，差异仅去重/尾巴）；S4 真机 service+UI 端到端 +
  PrintWindow 逐页抓图，week/month/year/all 数字翻转前后不变（`stats-backend-performance §5`）。
- 新测试件：`tests/db_smoke.cpp` schema-parity 断言（S1）；回填幂等二次启动不重复（S3）。

## 7. Sign-off（S4 据实勾选 · 实现 session log = `20260609-1643-B-a1-sqlite-primary-impl.md`）
- [x] `rules/03-data-contract.md` 更新为「SQLite 主源」新现实（S4，§1 表 + 文）。
- [x] `CHARTER.md` 版本号 bump v0.1→v0.2（I2 修订：timearc.db 升一等主契约 + UI 主读源）。
- [x] `state/frozen-files.json` 在冻结改动落地后重生成（`harness_check --bootstrap`，仅 CHARTER.md 变）。
- [x] `README.md §Roadmap` 同步（用户可见，A1 收尾）。
- 决策：路径约定本机/各模式实测相等 → **不加** frozen `usage_paths` db 访问器（仅 DatabaseManager 一次性不等告警）；
  唯一冻结改动＝CHARTER.md（I2+版本）。`usage_record.schema.json` 不动（JSONL/current 记录形状不变）。

## 本 session 收尾
- 产出：`docs/a1-sqlite-storage-migration-kickoff.md`（新）、`docs/README.md`(索引+1行)、
  `docs/implementation-backlog.md §A1`(校正)、`.harness/state/open-issues.md`(校正)、本 log。
- 无 build / 无 Qt 运行 / 无冻结改动 → 无 L1/L2 错误。`harness_check` 须 exit 0 后提交。
