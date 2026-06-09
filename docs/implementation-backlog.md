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
设置页剩余（**§H**）：**H1 时间格式**可随手做（P1，注意散落已验收页）；**H5 服务侧配置**须先过已填提案的签核；
**H3/H4**（强调色全局 + i18n）= 产品门控 **3E**；**H2** 依赖先有「分享图导出」特性；**H6** 受 QML 天花板、保留占位。

---

## 2. 清单（按子系统）

### A. 存储 / 数据层（keystone · 跨平台 · UI+service 共享契约）
- [ ] **A1 完成 SQLite 迁移为主数据源 + JSONL 回填** — **kickoff 已就绪：见
  [`a1-sqlite-storage-migration-kickoff.md`](a1-sqlite-storage-migration-kickoff.md)（多 session 拆分 S1–S5 + 实测证据）**。
  现状（2026-06-09 实测，**校正旧述**）：service 侧 SQLite 写入**已完整实装并在生产启用**（`init(&g,1,1)` 双写
  JSONL+SQLite，`frontmost_sessions`/`media_sessions` 实存 31k/21k 行、与 JSONL 头部对齐）——**不是 no-op**；UI 侧
  SQLite 已承载 projects/sessions/calendar/settings/memo，但**自动前台/音频读取仍走 JSONL + live JSON 快照**，无
  JSONL→SQLite 回填，路径/schema 两处独立构造（约定相等），注释过时；旧 QSettings 迁移后保留未删。剩余：UI 读侧切
  SQLite（保 D5 并集/增量守卫/读层过滤/live 快照）+ 一次性回填启用前 JSONL 尾巴（.bak+事务+按唯一键对账，**非行数
  相等**）+ 翻转主源（JSONL 兜底）+ JSONL 退役（未来）。
  Track B（大，**拆多 session**：S1 地基→S2 读源→S3 回填→S4 翻转/契约修订→S5 退役）· 平台跨 · 依赖：无（但 D1/D2
  依赖它）· **变更提案：是**（S4 改冻结 `CHARTER` I2 升 `timearc.db` 为主契约 + `rules/03` §4；`usage_paths` db
  访问器条件性）· 纵切：见 kickoff §2 · **kickoff 文档已建**。
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

### H. 设置页剩余项（settings · UI + 服务侧配置 · 实测审计见 `docs/settings-remaining-work.md`）
> 设置页已全实装并入 dev（PR #28）。以下为审计后确认的剩余项；优先级标签：
> **[P1]** 可随手做 · **[P2]** 有前置依赖 · **[门控]** 产品先拍板（3E）· **[提案]** 待签核 · **[天花板]** 受技术上限。
- [ ] **H1 [P1] 时间格式 12/24 全局接线（G-TIMEFMT）** — `time_format` 已持久化但无消费者（时钟显示仍硬编码
  24h）。剩余：日历议程 / 时间河 / 便签截止 / 今日议程等**时钟显示**读 `time_format` 走 `Qt.formatTime`（仅显示层，
  不动存储/排序的 "HH:mm" 串）。Track B · UI(calendar/memory-lake/sticky 多页) · 小-中（散落、碰已验收页须连带复核）·
  提案：否 · 纵切：先建共享 clock 格式 helper → 逐显示点接 → 抓图复核日历/记忆湖。
- [ ] **H2 [P2] 匿名分享图（G-ANON）** — `anonymize_export` 已持久化无消费者；**当前没有分享图/截图导出功能**。
  剩余：先建分享图导出能力，再在其渲染端把应用名换为类别/「应用 N」（**不可**在聚合源头改名，会误伤实时 UI）。
  Track B · UI(recap/记忆湖 分享管线) · 中 · 依赖：先有「分享图导出」特性 · 提案：否。
- [ ] **H3 [门控·3E] 强调色全局生效（G-ACCENT）** — `accent_color` 已持久化 + 本页高亮，未全局注入。剩余：
  `MemoryLakeStyle` 强调色改可注入（仿 injectedTextPrimary）+ Shell 下发。Track B · UI · 中 · **产品方另行领出（3E）**。
- [ ] **H4 [门控·3E] 界面语言全局译文（G-I18N）** — `language_mode` 已持久化（zh/en/ja）但 UI 文案全静态。剩余：
  qsTr + QTranslator 或共享 strings map 覆盖全 app。Track B · UI 全量 · **大工程** · **产品方另行领出（3E）**。
- [ ] **H5 [提案] 空闲超时 / 真停采集 / 删除历史（G-IDLE / G-TRACK / G-CLEAR）** — UI 现为软暂停 + 诚实标注；
  服务忽略 idle/track（idle 是编译期 `#define`），历史追加-only 不可删。剩余：UI→服务 磁盘配置通道（service 读
  `usage_config.json`）让 idle/track 生效 + 删历史策略。Track B · service(`src/service/windows/main.c` /
  `usage_tracker.{c,h}` 非冻结) + UI · **变更提案已填**
  `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（契约扩展 + 覆盖 A-TRACKPAUSE，**待维护者
  签核**；须服务构建/测试流水线）· 依赖：签核。
- [ ] **H6 [天花板] 磨砂实时模糊（G-BLUR）** — `blur_strength` 已持久化无真实效果；QML 无实时 backdrop blur，唯一
  近似（面板半透明）伤可读性 + 改每页玻璃令牌（面大）。结论：**保留为标注偏好**，除非接受半透明代价或换渲染路径。
  Track B · UI · 低/不做。

### M. 移动端（**超本次范围 · 低优 · 独立 arc**）
- [ ] **M1 Memory Lake / 统计 等页的移动端等价**（桌面已 done；移动端大多未接真实数据）— Track B · 跨。

---

## 3. 与既有文档关系

- 简洁版 known gaps：`.harness/state/open-issues.md`（本文是其行动化展开）。
- 顶层路线：`README.md §Roadmap`（terse `- [ ]` 列表，落地时与本文同步勾选）。
- 平台/契约规则：`.harness/rules/02-platform-boundaries.md`、`…/03-data-contract.md`、`…/06-licensing.md`、`…/07-product-ai-cards.md`。
- AI 边界与 payload 政策：`docs/card-ai-development-spec.md`、`CLAUDE.md` Product Context 硬边界。
- 既有 feature 文档范式（写 kickoff 时参照）：`docs/stats-*`、`docs/calendar-refactor-*`、`docs/memory-lake-*`、`docs/settings-*`。
- 设置页逐项剩余 / 实测审计：`docs/settings-remaining-work.md`；服务侧配置变更提案：
  `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（§H5 依赖其签核）。
