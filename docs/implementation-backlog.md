# TimeArc · 未完成事项实现清单（Implementation Backlog）

> 用途：把 `README.md` §Roadmap、Desktop P1 "important limits"、`.harness/state/open-issues.md`
> 里散落的未完成项，整理成**可执行的实现 backlog**——每项标注：现状 / 剩余 / Track /
> 子系统 / 平台 / 依赖 / 是否需**变更提案** / 最小纵切建议。`open-issues.md` 是简洁版「known
> gaps」；本文是带依赖与执行顺序的**行动清单**。
>
> **维护**：完成一项 → 勾掉 + 移进 session log，并同步 `README.md §Roadmap` 与 `open-issues.md`。
> 体例参考已有 feature kickoff（如 `docs/stats-implementation-kickoff.md`）。

---

## 0. 怎么用这份清单（给下一个 session / agent）

1. **一个 session 一条 track**（harness 规矩：A 稳定 / B 功能 / C 调试；混 track 会被
   `harness_check` pass 7 拦）。从下面挑**一项**，走**最小可运行纵切**（CLAUDE.md 硬规则）。
2. **大项先写 kickoff/spec 文档**再实现（仿 stats / calendar / memo 文档范式），再开实现 session。
3. **碰冻结磁盘契约 / 新增 .cpp/.h（动冻结 `src/CMakeLists.txt`）→ 先填**
   `.harness/templates/change-proposal.md` 进 `journal/sessions/`，否则 `harness_check` pass 2 拦。
   改 `usage_stat_manager.{h,cpp}` / `daily_card_service.{h,cpp}` 本体、改 `qml/` 不算冻结。
4. **AI 相关项受产品门控**（CLAUDE.md 硬边界：不对原始日志做 AI；管线 = 原始→本地摘要→隐私
   过滤→用户确认→AI）——**不得提前**，须产品先拍板。
5. **"Windows" 不是切分轴**：真正 Windows 专属的只有 §B；大头（存储/导出/AI/配置/许可）是
   跨平台 UI/数据/产品工作。

---

## 1. 建议落地顺序（依赖图）

```
A1 存储迁移(keystone) ──┬──> D1 导出/备份 ──> D2 DB 路径迁移
                        └──(更顺)
B1 Windows SCM ───────(独立, 可并行)
小修(B2/E5/G1) ───────(低风险, 任意时候捎带)
E1→E2→E3→E4 AI/隐私 arc ─(门控, 须产品拍板; 串行多 session)
C1 macOS / C2 Linux ──(独立平台 arc, 视目标平台启动)
F1 动态 Qt ──> F2 许可证页 ─(临近发版里程碑)
G2/G3 打磨 ───────────(随手)
```

优先级直觉：**A1 是地基**（解锁 D1/D2，也是 README 头号 "important limit"）；**B1** 自包含可并行；
**E\*** 最大最敏感、门控；**C/F** 按平台/发版节奏。

---

## 2. 清单（按子系统）

### A. 存储 / 数据层（keystone · 跨平台 · UI+service 共享契约）
- [ ] **A1 完成 SQLite 迁移为主数据源 + JSONL 回填**
  现状：service 侧 `timearc_storage_init_sqlite` / `write_sqlite` 是 no-op；UI 侧 SQLite 已承载
  projects/sessions/calendar/settings/memo，但**自动前台/音频使用仍走 JSONL + live JSON 快照**，
  且旧 QSettings 迁移后保留未删。剩余：让自动 usage 也以 SQLite 为主源 + 一次性 JSONL→SQLite
  回填/迁移器 + JSONL 退役为历史/可选。
  Track B（大，**拆多 session**）· 平台跨 · 依赖：无（但 D1/D2 依赖它）·
  **变更提案：是**（碰冻结磁盘契约 `rules/03` §4、`usage_record.*`/`data_bridge.h`/`usage_paths.*`）·
  纵切：先「读旧 + 双写校验」→ 再切主源 → 再退役 JSONL · **建议 kickoff 文档**。
- [ ] **A2 跨天手动 session 按天拆分/分摊**
  现状：靠重叠区间查询保留，未按天 split/prorate。Track B · UI(`project_manager`) · 中 · 提案：否。

### B. Windows 服务硬化（**Windows 专属** · service 侧 C）
- [ ] **B1 注册为真正的 Windows 服务（SCM）**
  现状：`src/service/windows/service/win_service.c` 三个 TODO stub；当前是前台 console exe。
  Track B · Windows · 自包含、不阻塞 UI · 提案：若新增源/动 service CMake 则需 · 纵切：先 install/
  start/stop 三动作打通。
- [ ] **B2 `write_json_string` 加 UTF-8 校验**（`usage_storage.c` TODO；跨平台同步前必须）
  Track A/C · Windows/shared · 小 · 可随任意 service session 捎带。
- [ ] **B3（可选低优）Windows `rename` 非原子覆盖**（`usage_storage.c` 现先 `remove`）——转 SQLite WAL 时再 revisit。

### C. 跨平台服务（**非 Windows**）
- [ ] **C1 macOS tracker 主循环接线**
  现状：`TimeArcService.swift` 是空 `RunLoop.run()`；`AppEnv.swift` 采样原语就绪；参照
  `windows/.../usage_tracker.c` 契约。Track B · macOS · 大。
- [ ] **C2 Linux 服务从零实现**
  现状：`src/service/linux/main.c` 0 字节。需 X11 + Wayland 前台采样、idle 检测、PipeWire/PulseAudio
  音频、单实例守卫。Track B · Linux · 大。

### D. 数据运维（UI · 跨平台 · 依赖 A1）
- [ ] **D1 导出 / 备份 / 恢复（SQLite 数据）** — Track B · 依赖 A1 · 中。
- [ ] **D2 用户可选数据库路径的安全迁移流** — Track B · 依赖 A1 · 中（仅当 user-selectable 数据位置成需求）。

### E. AI / Daily Cards 隐私管线（**产品门控** · 跨平台 · 须产品先拍板）
> 已 ship：六种本地确定性卡 + 活动分段器 + 关键词分类器（`aiGenerated:false`）。以下为剩余、且受 CLAUDE.md AI 硬边界门控。
- [ ] **E1 敏感应用隐私过滤器** — Track B · 门控 · 进 AI 前的前置。
- [ ] **E2 用户可编辑类目**（覆盖/扩展分类器桶）— Track B。
- [ ] **E3 卡片持久化** — Track B。
- [ ] **E4 「确认摘要后过 AI」管线**（原始→本地摘要→隐私过滤→用户确认→AI；当前**零代码**）—
  Track B · **强门控** · 多 session · **必须先写 spec + 产品签字**（见 `docs/card-ai-development-spec.md`、`.harness/rules/07`）。
- [ ] **E5 分类器长尾关键词覆盖**（冷门 app 仍落「其他」，open-issues A4）— Track B/A · 小-中 · 提案：否。

### F. 发布 / 许可（build/release · 跨平台 · 临近发版）
- [ ] **F1 release 构建动态链接 Qt**（满足 LGPL/GPL 组合姿态）— Track B · 提案：可能动冻结 `CMakeLists`。
- [ ] **F2 in-app 第三方许可证页面**（surfacing 所有 third-party 文本，`rules/06` §4）— Track B。

### G. 配置 / 打磨 / 杂项
- [ ] **G1 用户偏好外置为可编辑配置 + 接 Parson**（Parson 已 vendored 未用）— Track B · 小-中。
- [ ] **G2 富化本地 memo 管理**（仅本地/离线，**不得**描述为 AI chat）+ memo 延期项（§A #11–14：
  番茄钟声音/工休循环/进度环、键盘切工具、conic-aura shader）— Track B · 小。
- [ ] **G3 Win11 snap-layouts fly-out**（原生 `WM_NCCALCSIZE`/`WM_NCHITTEST` pass，frameless Step 2 延期）—
  Track B · Windows · 见 agent memory `timearc-frameless-window`。

### M. 移动端（**超本次范围 · 低优 · 独立 arc**）
- [ ] **M1 Memory Lake / 统计 等页的移动端等价**（桌面已 done；移动端大多未接真实数据）— Track B · 跨。

---

## 3. 与既有文档关系

- 简洁版 known gaps：`.harness/state/open-issues.md`（本文是其行动化展开）。
- 顶层路线：`README.md §Roadmap`（terse `- [ ]` 列表，落地时与本文同步勾选）。
- 平台/契约规则：`.harness/rules/02-platform-boundaries.md`、`…/03-data-contract.md`、`…/06-licensing.md`、`…/07-product-ai-cards.md`。
- AI 边界与 payload 政策：`docs/card-ai-development-spec.md`、`CLAUDE.md` Product Context 硬边界。
- 既有 feature 文档范式（写 kickoff 时参照）：`docs/stats-*`、`docs/calendar-refactor-*`、`docs/memory-lake-*`。
