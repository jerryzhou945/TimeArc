# Session — 2026-06-03 13:14 · Track B · memory-lake-backend-plan

## Goal
记忆湖前端（1:1 复刻）已完工，全部内容来自写死的 `MemoryLakeMock.js`。
本会话**只产计划文档**：逐处过完整个记忆湖，列出后端接入需替换/更改的全部内容，
并按优先级排序。重点覆盖用户点名的三块：图片替换、描述通用化、月度回顾防牛头不对马嘴。

## What I did (docs only, no code/schema change)
- 新增 `docs/memory-lake-backend-integration-plan.md`：
  - §3 全量内容清单（左/中/右栏 + 氛围大背景 + 回顾 11 屏），每处标 来源/改动/风险。
  - §4 图片替换策略（appicon 小图标 + 类别通用艺术图大图，复用 `resources/memorylake/hotspring_*` 等）。
  - §5 文案通用化（type/mood/analysis 本地确定性模板，引用类别+可度量模式）。
  - §6 月度回顾防错配（独立月级数据集、主角版式数据驱动分配、断言守卫、趋势接真值）。
  - §7 后端能力差距（现成 vs 需新增聚合：按天序列/环比/类别占比/时段峰值/按 APP 会话派生/文案模板）。
  - §8 优先级分阶段 P0–P3 + 验收。推荐新增只读 `MemoryLakeService` 集中模型与语言逻辑。
- 交叉链接：`docs/memory-lake-implementation-plan.md` Phase E 行、`.harness/state/open-issues.md` 指向新文档。

## Inputs read
AGENTS / .harness/AGENTS / rule 07 / implementation-plan / fidelity-gaps / open-issues；
QML：DesktopMemoryLakePage、MemoryLakeMock.js、DetailPanel、MemoryCard、TimeRiver、
UsageRankList、RecapOverlay、RecapSlide、DesktopAppShell 背景层。
后端能力经子代理勘查：usageStatManager / frontmostRepository / dailyCardService /
statsService / AppIconImageProvider 的真实签名与返回字段、classifyApp 类别、缺失聚合。

## Verify
- `preflight.py --track B`：clean。
- `harness_check.py`：我改动的部分全过（line-budget / frozen hashes 不受影响）。
  唯一 drift = 既有未跟踪文件 `qml/desktop/memorylake/_cardtest.qml`（**非本会话产生**，未处理）。
- 无构建/运行（纯文档），无 record_error 触发。

## Addendum — 用户追加三条保证（同会话）
读了 `DesktopHomePage.qml` / `DesktopDailyCardView.qml` / `src/CMakeLists.txt` / `main.cpp` 后补进新文档：
- 保证1 复用首页只读路径（`usageStatManager.activeSoftwareForRange` 等）+ 首页图标法
  （`appColor` 底块 + `image://appicon` 小图标）；图标≤256px，故大封面走「生成式封面」、大背景走「色彩晕染」（§2.1/2.2/§4 重写）。
- 保证2 安全：新代码只组合现有只读管理器，不自开文件/库/盘（§2.3/§9）。
- 保证3 文件红线（§10 新增）：关键发现 **`src/CMakeLists.txt` 冻结 + 显式源清单 → 新增 .cpp/.h 须变更提案**；
  故优先扩 `usage_stat_manager.*`/`daily_card_service.*`。`src/service/`(守护进程,禁碰) vs `src/services/`(UI,可改)。

## Addendum 2 — 精修审校 + 数据安全法规（同会话）
对照 `usage_stat_manager.h` 复核后修正计划：统一 `activeSoftwareForRange`（与首页一致，注明与
`softwareForRange` 等价）；图片策略全文统一为「生成式封面/色彩晕染」（去掉残留"类别图"说法，§3/§4/§7 对齐）；
补 `path` vs `appIconPath` 字段差异、时间河流节点与轴共用同一时间窗、文案模板归位到现有
`daily_card_service.*`（非新建 MemoryLakeService）。修一处真实逻辑漏洞：氛围大背景从 Image 双图淡入
改 appColor 渐变需调 shell 背景层为双色淡入（原"逻辑不动"过于乐观）。删掉文末游离 ``` 代码围栏。
- **新增法规**（§1.6 + §10）：实现期凡与计划假设不符必须登记，绝不用假数据顶替；未解决走空态。
- **新建** `docs/memory-lake-integration-issues.md`：本次实现专属 issue 文档，预置 A1–A7 待验证假设。

## Addendum 3 — 拆成两阶段（同会话）
§8 由 P0–P3 改为**两阶段严格分开**：阶段一只做记忆湖本体（日视图三栏+大背景，全用现成只读数据，
可独立交付，期间不碰 Recap）；阶段二再单独做 Monthly Recap（依赖 §7 缺失月度聚合，自然后置）。
§6 标签「最高优先」→「阶段二核心」；§7 缺口按阶段归属标注（5+6/7日→阶段一；1/2/4+3月→阶段二）；
§11 验收按两阶段拆分；§0 指引同步。

## Follow-ups (not done this session)
- 实施 Phase E 本身（见新文档 P0–P3）。
- 既有 `_cardtest.qml` 去留：要么登记进 `qml/CMakeLists.txt` 并说明，要么删除（留给实现轮）。
