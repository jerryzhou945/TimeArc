# Session — harness-vs-superpowers-study + docs-index

## Metadata
- Author: Claude Code (Opus 4.8, 1M)
- Track: B (Feature — 产品/工程文档)
- Date: 2026-06-09 03:35 (local)
- Branch: `docs/harness-study-and-reorg`（off `dev`）；目标 PR base = dev（新 PR，非 #32）。
- Goal: (1) 产出"TimeArc `.harness` vs. Superpowers 插件"架构对照学习；(2) 为平铺杂乱的
  `docs/` 加一个分类导航索引。

## 产出（仅 3 个新文件，零现有文件改动）
- `docs/agent-harness-vs-superpowers.md`（新建）：定位 / 两体系结构 / 11 维对照表 /
  5 个不可叠加冲突点 / 借思想不借框架的 4 个吸收点 / 给大范围工作的 6 条 harness 提醒。
- `docs/README.md`（新建）：分类导航索引（全局/工程·产品·记忆湖·日历·设置·统计·适配·
  superpowers 工件说明），文件保持平铺、不搬动。
- 本 session 记录。

## 决策
- **不引入 Superpowers 插件**：`.harness` 已是权威且覆盖同职责；插件 worktree/TDD 默认流与
  冻结文件 / track / disk contract 冲突；插件按用户本地装、不入库，合作方用它不约束本仓。
  可借鉴项（brainstorm-to-spec / 系统化调试四阶段 / subagent review / 任务拆分）以"服从 harness、
  产物仍是 rule/checklist"方式吸收，NOT 实装于本 PR。
- `docs/superpowers/`（plans/ + specs/）是合作方 Superpowers 工件、非插件本体 → 保留不动。
- **docs 整理选"只加索引"而非子目录搬动**：扫描发现按子目录搬会打断 **~80 处** `docs/xxx.md`
  引用——含 **~21 处 QML/C++/JS 源码注释**（18 个源文件）、4 处合作方 `superpowers/` 工件、
  `.harness/state/open-issues.md`、~50 处文档互链。搬动会污染源码 blank/blame 且动到合作方文件，
  得不偿失；故仅加 `docs/README.md` 索引，零引用破坏。子目录方案的搬动已在本分支撤销（reset）。

## Track-B 清单适用性
- 本 session 为 **docs-only**，无代码、不跨 UI/service 接缝 → "双段设计/两侧编译/smoke" 均 N/A。
- 无 frozen 文件改动 → 无需变更提案（CLAUDE.md/README/rules 等本轮**未改**，均还原平铺）。

## 验证
- `preflight.py --track B` → exit 0。提交前跑 `harness_check.py`（7-pass）须 exit 0：
  pass1 行预算（本记录 < 100 行）、pass2 frozen hash（未动冻结文件）、pass6 文件名 slug。
- 无 build / 无 Qt 运行 → 无 `build.py` / `scan_qt_log` / `record_error` 触发。

## 环境备注（L3 级观察，供后续 agent 参考）
- 文件类工具(Read/Write/Edit)与 shell(Bash/PowerShell)曾出现两套互不相通的 FS 视图：写到
  `.claude/worktrees/settings-impl/` 子路径的文件 shell/git 看不到；写到真实仓库根
  `F:/Git Proj/TimeArc/...` 路径则 git 可见。本 PR 全程用真实仓库路径 + 真实 `dev` 分支操作。
- 真实仓库无 `settings-impl-wt` 分支；设置工作在 `feat/settings-page-dark-glass`。
- 工具搜索（Grep/Bash grep/PowerShell）在 `.claude/worktrees/...` 隐藏路径下检索易空命中，
  须改用真实仓库绝对路径 + 禁沙箱 shell 才可靠。
