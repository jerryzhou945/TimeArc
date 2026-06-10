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

优先级直觉：**A1 是地基**，S1–S4 已落地并合并（SQLite 升 UI 主历史读源 + 回填 + 翻转，`CHARTER` v0.2）——**D1/D2（导出-备份 / DB 路径迁移）已解锁**，A1 仅剩 **S5**（退役 JSONL 写入，未来发版）；**B1**（Windows 用户会话自启 Route A）亦已实装合并、Route B 暂缓；
**E\*** 最大最敏感、门控；**C/F** 按平台/发版节奏。
设置页剩余（**§H**）：**H1 时间格式**可随手做（P1，注意散落已验收页）；**H5 服务侧配置**须先过已填提案的签核；
**H3/H4**（强调色全局 + i18n）= 产品门控 **3E**；**H2** 依赖先有「分享图导出」特性；**H6** 受 QML 天花板、保留占位。

---

## 2. 清单（按子系统）

### A. 存储 / 数据层（keystone · 跨平台 · UI+service 共享契约）
- [~] **A1 SQLite 升主数据源 + JSONL 回填 — S1–S4 已完成（`CHARTER` v0.2）**；见
  [`a1-sqlite-storage-migration-kickoff.md`](a1-sqlite-storage-migration-kickoff.md) + 实现 log
  `.harness/journal/sessions/20260609-1643-B-a1-sqlite-primary-impl.md`。
  - [x] **S1** 对齐去过时：去 stub 注释 + `db_smoke` schema-parity 断言（仅 UI DDL）+ DatabaseManager 路径不等告警。
  - [x] **S2** UsageStatManager 加 SQLite 读源（folded、flag）+ 双读 parity 自检（保 D5/增量守卫/读层过滤/live）。
  - [x] **S3** 一次性回填全部 JSONL（`.bak`+事务+**按唯一键对账非行数**+幂等 `usage_jsonl_backfill_v1_done`；stage-all 不靠 start 阈值，防乱序音频漏）。
  - [x] **S4** 翻转主源 SQLite（JSONL 兜底）+ `CHARTER` I2 修订（timearc.db 升一等主契约）+ 版本 v0.1→v0.2 + `rules/03`。
  - [ ] **S5（本轮不做）** 退役 JSONL 写入 + 移除 UI JSONL 读路径 + 最终 `rules/03` 修订 +（可选）删遗留 QSettings。
  实测：回填后 SQLite==JSONL（week/month/year/all 全 diff 0、记录 53108==53108）。Track B · 平台跨 · `usage_paths` db 访问器未加。
- [ ] **A2 跨天手动 session 按天拆分/分摊**
  现状：靠重叠区间查询保留，未按天 split/prorate。Track B · UI(`project_manager`) · 中 · 提案：否。

### B. Windows 服务硬化（**Windows 专属** · service 侧 C）
- [x] **B1 注册为真正的 Windows 服务（SCM）· Route A 已实装（S1+S2）** — **kickoff：见
  [`b1-windows-service-scm-kickoff.md`](b1-windows-service-scm-kickoff.md)（Session 0 隔离陷阱 + 产品路线决策门 +
  S0/S1/S2 与 Route B SB1–SB3 范围卡）。决策（2026-06-09，维护者拍板）：先走 Route A。已实装（PR #37）：
  S1 生命周期动词（install/uninstall/start/stop/status）+ 用户会话登录自启（schtasks，HKCU Run 退路）+ `Local\TimeArcStop`
  停采集通道；S2 设置页「开机自动在后台采集」开关 + 文档同步；本机真机验收全绿（InteractiveToken 任务、优雅停、干净卸载）。Route B 仍暂缓。**
  实装前现状（已被本 PR 取代，见上）：`src/service/windows/service/win_service.c:3-16` 曾是三个 TODO stub（全 `return -1`）、前台 console exe，由 UI
  `src/main.cpp::startUsageService`（`startDetached`）在**用户会话**里拉起。
  **关键校正**：「真正的 SCM 服务」若按朴素 `CreateService`+LocalSystem 实现会落 **Session 0**，使前台/空闲/音频/媒体
  采集全空、数据写错 profile（采集全链路依赖 per-session API + 用户 env，见 kickoff §0.3）——**真不变量是「tracker 必须
  跑在交互式用户会话」**。**已选 Route A（用户会话登录自启，无管理员、零冻结改动）**为 MVP；Route B（SCM session-broker
  真服务）门控、需管理员 + 链 `advapi32/wtsapi32/userenv`（动冻结 `src/service/CMakeLists.txt`）+ 修订 CHARTER I1，暂缓。
  Track B · Windows · 自包含、可与 A1 并行（不碰 I2 数据契约）· 提案：Route A 否 / Route B 是 · 纵切：见 kickoff §2
  （动词面 install/start/stop/uninstall/status 为稳定 CLI 契约）。
- [ ] **B2 `write_json_string` 加 UTF-8 校验**（`usage_storage.c:140-175` 仅做 JSON 转义、未校验输入字节是否为合法 UTF-8 序列；**源内并无 TODO 注释**——旧述「usage_storage.c TODO」不实，全仓唯一 "UTF-8" 字样即本条；跨平台同步前必须）
  Track A/C · Windows/shared · 小 · 可随任意 service session 捎带。
- [ ] **B3（可选低优）Windows `rename` 非原子覆盖**（`usage_storage.c` 现先 `remove`）——转 SQLite WAL 时再 revisit。

### C. 跨平台服务（**非 Windows**）
- [ ] **C1 macOS tracker 主循环接线**
  现状：`TimeArcService.swift` 是空 `RunLoop.run()`；`AppEnv.swift` 采样原语就绪；参照
  `windows/.../usage_tracker.c` 契约。Track B · macOS · 大。
- [ ] **C2 Linux 服务从零实现**
  现状：`src/service/linux/main.c` 0 字节。需 X11 + Wayland 前台采样、idle 检测、PipeWire/PulseAudio
  音频、单实例守卫。Track B · Linux · 大。

### D. 数据运维（UI · 跨平台 · 依赖 **A1-S1**：库文件已落地、服务已 dual-write SQLite；**不依赖** UI 读侧翻转 S2/S4）
- [x] **D1 导出 / 备份 / 恢复（SQLite 数据）— S1+S2 实装（PR #40）** — Track B · 依赖 A1-S1 · 中 · 提案：否（不碰 I2）。`DatabaseManager::backupDatabase`（`VACUUM INTO` 一致快照）+ `inspectBackup`（只读校验：完整性 + 三契约表 + 计数/时间区间）+ `restoreDatabase`（停服协调 + `.pre-restore.bak` 回滚 + 换库 + emit databaseRestored 重启提示），设置页「数据库备份与恢复」卡 + `db_smoke` 往返/坏文件用例。S3 保留/自动备份未做。见 [`d1-export-backup-restore-kickoff.md`](d1-export-backup-restore-kickoff.md)。
- [ ] **D2 用户可选数据库路径的安全迁移流** — Track B · 依赖 A1-S1（库路径现写死 `AppDataLocation/timearc.db`，无 setter/迁移；若含「迁移后全程改读新路径」则与 S4 的 `usage_paths` db 访问器同一冻结点耦合）· 中（仅当 user-selectable 数据位置成需求）。

### E. AI / Daily Cards 隐私管线（**产品门控** · 跨平台 · 须产品先拍板）
> 已实现（C++）：六种本地确定性卡（`build*Card`：mainline/top_apps/focus_block/entertainment/contrast/random_flip，`aiGenerated:false`）+ 活动分段器（`segmentFocusBlocks`/`taskBlocks`）+ 关键词分类器（`classifyApp`）。**注**：`getTodayCards()` / `DesktopDailyCardView.qml` **未接进任何 QML（零调用 / 零实例化，死路径）**；实际上线 UI 走记忆湖路径 `memoryLakeDay`/`memoryLakeRecap`（复用同一分类器 + 分段器）。以下为剩余、且受 CLAUDE.md AI 硬边界门控。
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
- [ ] **G1 用户偏好外置为可编辑配置 + 接 Parson**（Parson 已 vendored 且已链接进 app/service 目标、但 src 零调用）— Track B · 小-中 · 备注：设置页约 30 项偏好走 SQLite `settings` 表（`SettingsRepository`），是 SQLite KV、**非人类可编辑磁盘文本、不经 Parson，不满足本项**（本项指人类可编辑磁盘配置文件 + Parson 解析）；与 **H5** 服务侧 `usage_config.json` 提案范畴相邻（H5 是服务 idle/track 运行配置、复用 `SettingsRepository` 非 Parson），宜交叉引用。
- [ ] **G2 富化本地 memo 管理**（仅本地/离线，**不得**描述为 AI chat）+ memo 延期项（§A #11–14：
  番茄钟声音 / 工作-休息循环 / 环形进度环 / 键盘快捷切工具）— Track B · 小。
  〔修正：原列「conic-aura shader」已移除——它不属 §A #11–14，且 conic 光环（`PomodoroCompleteOverlay.qml`）+ 运行 aura 辉光（`PomodoroWidget.qml:205`）均已用 Canvas/动画实装、故意不用 shader。〕
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
- [ ] **M1 Memory Lake / 统计 等页的移动端等价**（桌面 `DesktopStatsPage`/`DesktopMemoryLakePage` 已 done 且接只读真实后端；移动端 `qml/mobile/pages/` 仅 Home/Stats/History/Settings 四页、**全部字面 mock、零 backend manager**（`MobileAppShell` 仅注入 `mobileTheme`），且**无记忆湖移动页**——须从零新建）— Track B · 跨。

---

## 3. 与既有文档关系

- 简洁版 known gaps：`.harness/state/open-issues.md`（本文是其行动化展开）。
- 顶层路线：`README.md §Roadmap`（terse `- [ ]` 列表，落地时与本文同步勾选）。
- 平台/契约规则：`.harness/rules/02-platform-boundaries.md`、`…/03-data-contract.md`、`…/06-licensing.md`、`…/07-product-ai-cards.md`。
- AI 边界与 payload 政策：`docs/card-ai-development-spec.md`、`CLAUDE.md` Product Context 硬边界。
- 既有 feature 文档范式（写 kickoff 时参照）：`docs/stats-*`、`docs/calendar-refactor-*`、`docs/memory-lake-*`、`docs/settings-*`。
- 设置页逐项剩余 / 实测审计：`docs/settings-remaining-work.md`；服务侧配置变更提案：
  `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（§H5 依赖其签核）。
