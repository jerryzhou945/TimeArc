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
小修(B2/G1/G4) ───────(低风险, 任意时候捎带)
E1→E2→E3→E4 AI/隐私 arc ─(门控, 须产品拍板; 串行多 session)
C1 macOS / C2 Linux ──(独立平台 arc, 视目标平台启动)
F1 动态 Qt ──> F2 许可证页 ─(临近发版里程碑)
G2/G3 打磨 ───────────(随手)
```

优先级直觉：**A1 是地基**，S1–S5 已完成（SQLite 回填、翻转与旧历史流退役，`CHARTER` v0.9）——**D1/D2（导出-备份 / DB 路径迁移）已解锁**；**B1**（Windows 用户会话自启 Route A）亦已实装合并、Route B 暂缓；
**E\*** 最大最敏感、门控；**C/F** 按平台/发版节奏。
设置页剩余（**§H**）：**H1 时间格式**可随手做（P1，注意散落已验收页）；**H5 服务侧配置 S1+S2 已实装**（idle/真停，PR #42；S3 删历史暂缓）；
**H3/H4**（强调色全局 + i18n）= 产品门控 **3E**；**H2** 依赖先有「分享图导出」特性；**H6** 受 QML 天花板、保留占位。

---

## 2. 清单（按子系统）

- [ ] **X1 跨端账号与选择性使用时长同步（E1-E9）** — 中国大陆首发，
  设计与进度见 `cross-device-sync-progress.md`；下一项为 E1 CloudBase Auth
  与基础设施。

### Alpha. 桌面 alpha 功能修复（非移动端 / 非 AI）
- [x] **P0 首页右侧今日事项可勾选完成** — 2026-06-13 已实装：点击 checkbox 可切换 `done` 并写回 `CalendarManager.savedTodos`。commit `53acc61`。
- [x] **P1 常见应用名称大众化** — 2026-06-13 已覆盖 Apex Legends、NVIDIA Container、Service Host / Windows system process 命名与 group key；2026-06-14 继续补齐 WeChat→微信、JianyingPro/CapCut→剪映专业版。commits `bddadd1`, `5c8e939`。
- [x] **P1 原生应用图标正常居中显示** — 2026-06-14 已回退 `AppIconImageProvider` 的透明边距裁剪路径，恢复 Qt 原生 app icon pixmap；QML 固定图标槽继续负责居中与等比显示。本轮继续让找不到真实系统图标的 app 回退到首字图标，避免记忆湖/统计页出现透明“缺图标”。commits `f023587`。
- [x] **P1 桌面 12/24 小时显示接线** — 见 H1。commits `c3317fb`、`7dfad9c`。
- [x] **P1 JSON 字符串 UTF-8 校验** — 见 B2。commit `74cc033`。

### A. 存储 / 数据层（keystone · 跨平台 · UI+service 共享契约）
- [x] **A1 SQLite 历史迁移 — S1–S5 已完成（`CHARTER` v0.9）**；见
  [`a1-sqlite-storage-migration-kickoff.md`](a1-sqlite-storage-migration-kickoff.md) + 实现 log
  `.harness/journal/sessions/20260609-1643-B-a1-sqlite-primary-impl.md`。
  - [x] **S1** 对齐去过时：去 stub 注释 + `db_smoke` schema-parity 断言（仅 UI DDL）+ DatabaseManager 路径不等告警。
  - [x] **S2** UsageStatManager 加 SQLite 读源（folded、flag）+ 双读 parity 自检（保 D5/增量守卫/读层过滤）。
  - [x] **S3** 一次性回填全部 JSONL（`.bak`+事务+**按唯一键对账非行数**+幂等 `usage_jsonl_backfill_v1_done`；stage-all 不靠 start 阈值，防乱序音频漏）。
  - [x] **S4** 翻转主源 SQLite（JSONL 兜底）+ `CHARTER` I2 修订（timearc.db 升一等主契约）+ 版本 v0.1→v0.2 + `rules/03`。
  - [x] **S5** 退役旧历史流写入和 UI fallback/parity 读路径，完成 `rules/03` / Charter 最终修订；旧文件不自动删除。
  - [x] **契约清理**（`CHARTER` v0.10）：删除已无消费者的聚合 session 头和说明文档，统一以 `data_bridge.h` 与 SQLite 三表为契约。
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
- [x] **B2 `write_json_string` 加 UTF-8 校验** — 2026-06-13 已实装：JSON 字符串输出保留合法 UTF-8，非法字节写为 `\ufffd`，控制字符/引号/反斜杠继续按 JSON 规则转义；不改 SQLite 写入和磁盘契约。
  Track B · Windows/shared · 小 · commit `74cc033`。
- [x] **B3 Windows JSON 覆盖路径已退役**——自动使用历史已统一为 SQLite
  WAL，旧 `usage_storage.c` 随 Windows 存储适配层一并删除。

### C. 跨平台服务（**非 Windows**）
- [~] **C1 macOS tracker 主循环接线**
  2026-06-19 已补 Swift helper 的 foreground 写入、`usage_config.json`
  配置读取（`idle_threshold_ms` / `track_enabled`）、单实例文件锁、媒体
  assertion -> `source=audio` session 写入、SIGTERM/SIGINT flush；同日继续补
  LaunchAgent verbs（install/uninstall/start/stop/status）和 UI macOS helper
  auto-start 路径探测。剩余：Mac-host 编译与权限 smoke、db_path 实机确认、
  Accessibility UX、Qt deploy、签名/公证/DMG 包装链路；helper 已固定随 UI
  放入 `TimeArc.app/Contents/MacOS`。Track B · macOS · 大。
- [ ] **C2 Linux 服务从零实现**
  现状：`src/service/linux/main.c` 0 字节。需 X11 + Wayland 前台采样、idle 检测、PipeWire/PulseAudio
  音频、单实例守卫。Track B · Linux · 大。

### D. 数据运维（UI · 跨平台 · 依赖 **A1-S1**：库文件已落地、服务已 dual-write SQLite；**不依赖** UI 读侧翻转 S2/S4）
- [x] **D1 导出 / 备份 / 恢复（SQLite 数据）— S1+S2 实装（PR #40）** — Track B · 依赖 A1-S1 · 中 · 提案：否（不碰 I2）。`DatabaseManager::backupDatabase`（`VACUUM INTO` 一致快照）+ `inspectBackup`（只读校验：完整性 + 三契约表 + 计数/时间区间）+ `restoreDatabase`（停服协调 + `.pre-restore.bak` 回滚 + 换库 + emit databaseRestored 重启提示），设置页「数据库备份与恢复」卡 + `db_smoke` 往返/坏文件用例。S3 保留/自动备份未做。见 [`d1-export-backup-restore-kickoff.md`](d1-export-backup-restore-kickoff.md)。
- [x] **D2 用户可选数据库路径的安全迁移流 — S1+S2 实装（PR #41，`CHARTER` I2 → v0.3）** — Track B · 依赖 A1-S1 + **D1 迁移原语** · 中 · **提案：是（碰 I2，已签核 `20260610-1705`）**。**S1 跨进程指针**：`usage_config.json` 加 `db_path` 键，service `make_db_path`（vendored Parson，无 CMake 改动）与 UI `databasePath()`（QJsonDocument）**同源读取** + 等价校验（非空 + 父目录可建/可写）+ 缺失/坏值/不可写父目录回退默认 + 一次性告警（fail-safe，不 split-brain）。**S2 UI 迁移流**：`relocateDatabaseTo` / `restoreDefaultDatabaseLocation`（`VACUUM INTO` 新库 → `inspectBackup` 校验 → 锁探旧库 → 原子 RMW 写指针（保 H5 键）→ 重开 → 任一步回滚），设置页「数据库位置」卡 + FolderDialog + 还原默认。验证：`db_smoke`（S1 三态 + S2 往返）+ 真 service E2E（`make_db_path` 读指针建库）+ 真 UI 抓图。S3（预设/盘符守卫）未做。见 [`d2-database-path-migration-kickoff.md`](d2-database-path-migration-kickoff.md)。

### E. AI / Daily Cards 隐私管线（**产品门控** · 跨平台 · 须产品先拍板）
> 已实现（C++）：六种本地确定性卡（`build*Card`：mainline/top_apps/focus_block/entertainment/contrast/random_flip，`aiGenerated:false`）+ 活动分段器（`segmentFocusBlocks`/`taskBlocks`）。**注**：`getTodayCards()` / `DesktopDailyCardView.qml` **未接进任何 QML（零调用 / 零实例化，死路径）**；实际上线 UI 走记忆湖路径 `memoryLakeDay`/`memoryLakeRecap`（复用本地分段与分类能力）。以下为剩余、且受 CLAUDE.md AI 硬边界门控。
- [ ] **E1 敏感应用隐私过滤器** — Track B · 门控 · 进 AI 前的前置。
- [ ] **E2 用户可编辑类目**（覆盖/扩展分类器桶）— Track B。
- [ ] **E3 卡片持久化** — Track B。
- [ ] **E4 「确认摘要后过 AI」管线**（原始→本地摘要→隐私过滤→用户确认→AI；当前**零代码**）—
  Track B · **强门控** · 多 session · **必须先写 spec + 产品签字**（见 `docs/card-ai-development-spec.md`、`.harness/rules/07`）。

### F. 发布 / 许可（build/release · 跨平台 · 临近发版）
- [x] **F1 release 构建动态链接 Qt**（满足 LGPL/GPL 组合姿态）— Track B · Route A · 提案：否（未动冻结 `CMakeLists`）。
  已实装（**PR #43**）：S1 `tools/verify-linkage.ps1`（objdump 断言 Qt6*.dll 动态、无静态 Qt + shared-libs 部署）
  + 去过时文档（open-issues / rules/06 §1 / README）；S2 许可文本 `resources/licenses/`；S3 `tools/package-release.ps1`
  （windeployqt + 随包 Qt/MinGW DLL + LICENSE + licenses/ + NOTICE.txt relink 声明 + 嵌 S1 断言 + zip；断面机
  剥离 PATH 解压即跑已验证）。2026-07-27 补项目自有资源的 in-tree 安装：
  桌面 GUI 大图按背景/站点图标/月度回顾拆为三个外置 RCC，Windows 包装强制携带；
  macOS UI/helper 同置 `Contents/MacOS`。Qt runtime 部署仍由平台 deploy 工具完成。
- [x] **F2 in-app 第三方许可证页面**（surfacing 所有 third-party 文本，`rules/06` §4）— Track B。
  已实装（**PR #43**）：设置→导入导出→「关于与开源许可」卡（Qt/SQLite/Parson/TimeArc 名+版本+许可+链接方式），
  「查看全文」读 `resources/licenses/` qrc 内嵌文本、离线可达。详见 `docs/f2-in-app-licenses-page-kickoff.md`。

### G. 配置 / 打磨 / 杂项
- [x] **G1 用户偏好外置为可编辑配置 + 接 Parson（alpha 口径收束）** — 2026-06-14 决策：alpha 不引入第二套人类可编辑 JSON 偏好文件；约 30 项用户偏好继续以 SQLite `settings` 表（`SettingsRepository`）为唯一 UI 偏好源，避免与 H5/D2 的 `usage_config.json` 控制文件形成双写。设置页移除可见「导出设置 JSON」入口，仅保留导入设置与复制配置摘要；`doExport()` 功能函数暂保留为内部/诊断能力。后续若要真正 Parson 外置配置，应另开提案并定义与 SQLite KV 的同步边界。
  2026-06-14 本轮补齐深色全幅页导航图标一致性：新增 `recap_white.svg`，底部「记忆湖」入口与其他导航项一样在夜间/全幅深色页使用白色图标。
- [ ] **G2 富化本地 memo 管理**（仅本地/离线，**不得**描述为 AI chat）+ memo 延期项（§A #11–14：
  番茄钟声音 / 工作-休息循环 / 环形进度环 / 键盘快捷切工具）— Track B · 小。
  〔修正：原列「conic-aura shader」已移除——它不属 §A #11–14，且 conic 光环（`PomodoroCompleteOverlay.qml`）+ 运行 aura 辉光（`PomodoroWidget.qml:205`）均已用 Canvas/动画实装、故意不用 shader。〕
- [ ] **G3 Win11 snap-layouts fly-out**（原生 `WM_NCCALCSIZE`/`WM_NCHITTEST` pass，frameless Step 2 延期）—
  Track B · Windows · 见 agent memory `timearc-frameless-window`。
- [~] **G4 分类器长尾关键词覆盖**（冷门 app 仍落「其他」，open-issues A4）— Track B/A · 小-中 · 提案：否。
  2026-06-13 alpha 修复已覆盖截图中的 `r5apex_dx12` → Apex Legends、`nvcontainer` → NVIDIA Container、`svchost` → Service Host，并补入 Apex/NVIDIA/Windows 系统进程的 group key 与分类；2026-06-14 继续补 QQ/TIM/QQ 截图助手显示名与 group key，聚合项新增 `homeRankVisible`，记忆湖首页排行过滤 QQ 截图、Windows/NVIDIA helper 等低信号项，但设置页应用管理保留全量列表。更广泛长尾仍保留为后续渐进覆盖。
  2026-06-14 本轮曾继续收窄设置页应用管理：`allApps()` 输出聚合 `seconds` 与 `settingsVisible`，默认按高频到低频展示大众化应用/站点，并收起 `pid:*`、`.dll`、Windows helper、QQ 截图、NVIDIA helper 等低信号项；搜索仍覆盖全量记录，便于需要时找回并调整显隐。

  2026-06-14 C 修复：浏览器承载的主流网站现在在通用浏览器 adapter 之前拆分；Chrome/Edge 前台记录只要窗口标题命中站点目录，就计入 `site:*`（例如 `site:douyin`、`site:xiaohongshu`），不再聚合进 `app:google-chrome` 或 `app:microsoft-edge`。
  2026-06-14 本轮更新：设置页应用管理改为展示全部聚合项，不再默认过滤 `settingsVisible=false`；排序口径为高频项按时长降序，低于 60 秒的低频项按显示名 A-Z/本地字典序排列。图标链路同时加固：原生 app 图标候选从 `path` 扩展到原始 `appId`，Image 加载失败时在首页、统计、记忆湖、报告与应用管理中回退到首字图标。
  2026-06-14 图标资源更新：主流网站优先使用官网 metadata/PWA manifest 暴露的高像素 PNG（新增/替换小红书、爱奇艺、AcFun、Netflix、支付宝等），其余官网仅提供 favicon 的站点保留本地 favicon 兜底；详见 `docs/site-icon-assets.md`。
### H. 设置页剩余项（settings · UI + 服务侧配置 · 实测审计见 `docs/settings-remaining-work.md`）
> 设置页已全实装并入 dev（PR #28）。以下为审计后确认的剩余项；优先级标签：
> **[P1]** 可随手做 · **[P2]** 有前置依赖 · **[门控]** 产品先拍板（3E）· **[提案]** 待签核 · **[天花板]** 受技术上限。
- [x] **H1 [P1] 时间格式 12/24 全局接线（G-TIMEFMT）** — 2026-06-13 已实装桌面显示层：日历月/周/今日议程、右侧议程、创建弹层已选时间、记忆湖今日事项、时间河、便签截止时间读取 `time_format` 并走 `Qt.formatTime/Qt.formatDateTime`；存储/排序仍保留 `"HH:mm"` 串。
  Track B · UI(calendar/memory-lake/sticky 多页) · 提案：否 · commits `c3317fb`、`7dfad9c`。
- [ ] **H2 [P2] 匿名分享图（G-ANON）** — `anonymize_export` 已持久化无消费者；**当前没有分享图/截图导出功能**。
  剩余：先建分享图导出能力，再在其渲染端把应用名换为类别/「应用 N」（**不可**在聚合源头改名，会误伤实时 UI）。
  Track B · UI(recap/记忆湖 分享管线) · 中 · 依赖：先有「分享图导出」特性 · 提案：否。
- [ ] **H3 [门控·3E] 强调色全局生效（G-ACCENT）** — `accent_color` 已持久化 + 本页高亮，未全局注入。剩余：
  `MemoryLakeStyle` 强调色改可注入（仿 injectedTextPrimary）+ Shell 下发。Track B · UI · 中 · **产品方另行领出（3E）**。
- [ ] **H4 [门控·3E] 界面语言全局译文（G-I18N）** — `language_mode` 已持久化（zh/en/ja）但 UI 文案全静态。剩余：
  qsTr + QTranslator 或共享 strings map 覆盖全 app。Track B · UI 全量 · **大工程** · **产品方另行领出（3E）**。
- [x] **H5 [S1+S2 已实装·PR #42] 空闲超时 / 真停采集（G-IDLE / G-TRACK）** — UI→服务 磁盘配置通道已落地：service 启动读
  `usage_config.json` 的 `idle_threshold_ms`+`track_enabled`（`timearc_read_service_config`，缺/坏→编译期默认，向后兼容），
  idle 接进 `TimeArcUsageTrackerConfig`、`track_enabled=false` 让服务**真停采集并退出**（`--status running=no`，绝不删历史）；
  UI `DatabaseManager::writeServiceConfig`（与 D2 db_path 共用原子 RMW `mergeUsageConfig`，互保键）+ 设置页「应用并重启采集」
  即时生效，去掉「受限」标注。验证：服务真二进制 smoke（idle 生效 / 暂停期无新记录 / 缺 config→默认）+ `db_smoke` 双向保键。
  提案 `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（维护者签核，CHARTER v0.3 channel 复用）。
  **S3 删除历史（G-CLEAR）暂缓**（append-only；要 purge 须 CHARTER 修订或外部停服工具，非本轮）。计划见
  [`h5-service-config-channel-kickoff.md`](h5-service-config-channel-kickoff.md)。
- [ ] **H6 [天花板] 磨砂实时模糊（G-BLUR）** — `blur_strength` 已持久化无真实效果；QML 无实时 backdrop blur，唯一
  近似（面板半透明）伤可读性 + 改每页玻璃令牌（面大）。结论：**保留为标注偏好**，除非接受半透明代价或换渲染路径。
  Track B · UI · 低/不做。

### M. 移动端（独立 arc）
- [x] **M1 Memory Lake / 统计 / 首页 / 设置的移动端等价** — 2026-07-19
  已完成 QML 四页实装：真实 Android 使用聚合、单卡翻转、周/月/年/总统计详情、
  真实应用图标、全局壁纸与玻璃层、记忆湖、原创 Canvas 月报、卡牌/月报分享和设置。
  设计与验证见
  [`mobile-qml-time-album-implementation-report.md`](mobile-qml-time-album-implementation-report.md)。
  剩余仅为 Android 多 ROM 的相册 URI、FileProvider 分享和安全区设备验收。Track B · 跨。

---

## 3. 与既有文档关系

- 简洁版 known gaps：`.harness/state/open-issues.md`（本文是其行动化展开）。
- 顶层路线：`README.md §Roadmap`（terse `- [ ]` 列表，落地时与本文同步勾选）。
- 平台/契约规则：`.harness/rules/02-platform-boundaries.md`、`…/03-data-contract.md`、`…/06-licensing.md`、`…/07-product-ai-cards.md`。
- AI 边界与 payload 政策：`docs/card-ai-development-spec.md`、`CLAUDE.md` Product Context 硬边界。
- 既有 feature 文档范式（写 kickoff 时参照）：`docs/stats-*`、`docs/calendar-refactor-*`、`docs/memory-lake-*`、`docs/settings-*`。
- 设置页逐项剩余 / 实测审计：`docs/settings-remaining-work.md`；服务侧配置变更提案：
  `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（§H5 依赖其签核）。
