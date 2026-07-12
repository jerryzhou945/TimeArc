# 统计页 · 后端数据缺口与接入计划（问题文档）

> 前置：本文是 `docs/stats-functional-replication.md` / `…-render-pipeline-replication.md`
> 的**数据侧问题清单 + 接入计划**，体例对齐 `docs/memory-lake-backend-integration-plan.md`。
> 现状：v88 统计页（`TimeArcDesign_v88.stripped.html` DOM `14243–14465` / JS `15280–15413`）
> **全部数字是写死 mock**；本文逐项判定「后端能不能给」，给不了的列为**待决问题 / 硬缺口**。
> Track：**B**。硬边界：**不**改磁盘契约、**不**加 IPC/socket/共享内存、**不**改 SQLite schema、
> **不**对原始日志做 AI（`CLAUDE.md` + `.harness/rules/07`）。
> 纪律：实现期凡与本文假设不符（尤其历史深度、字段、聚合口径），**必须** `record_error`
> 并追加到本文 §12 实测登记（数据安全法规，仿 `memory-lake-integration-issues.md`）。

---

## 0. 必须解决的问题（用户点名）

| # | 问题 | 本文结论 |
|---|---|---|
| A | 尽量获取后端能给的全部信息 | §2 + §3 全量过了一遍；可用项直接接（§3 ✅），派生项给算法（§3 🟡） |
| B | 后端没有的，写进问题文档 | §7 硬缺口 G-1..G-10 + §6 待决问题（产品决策）汇总于此 |
| C | 饼图复用首页 + 降低毛玻璃 | 渲染文档 §4.1：`DailyUsageShare` 加 `glassStrength≈0.45`；数据侧见本文 §3 饼/§7 G-3 |

## 0.1 硬性保证（验收一票否决）

| 保证 | 含义 |
|---|---|
| 只读 | 统计页零 usage/SQLite 写入；唯一写仅「记住 range」UI 私有偏好 |
| 不造假 | 缺真实来源 → 空态/中性占位，绝不写死 mock、不给假箭头、不编洞察 |
| 同款数据路径 | usage 数据只经 `UsageStatManager` 读 JSONL；分类/聚合走 `DailyCardService` 且数据由 QML 传入（db_smoke 契约：DCS 不引用 USM 符号） |
| 真实类目 | 饼/占比展示分类器真实类目（top-N+其它），不贴 v88 mock 文案 |

---

## 1. 核心原则

1. **复用 > 新增**：统计页与首页/记忆湖/月度回顾共用同一套只读聚合（USM + DCS）。
   能用现成 `*ForRange`/`foregroundSegmentsForRange`/`dailySecondsForMonth`/`memoryLakeRecap`
   就不写新 C++。
2. **派生先在 QML**：能在 UI 层由现有返回值算出的（周分桶、热力量化、distinct 计数、
   切换次数），先在 QML 算；只有「无原始切片入口」的（week range、指定年/上周窗口、导出）
   才下沉 C++。
3. **真 AI 延后**：洞察/建议/总结先本地确定性模板（允许、零风险），真 AI 是受门控的 Phase-3。
4. **历史深度未知**：YoY、上周、12 月序列、年专注都依赖 JSONL 累计时长——**代码无法验证
   目标机历史深度**，须实测（§12）。

---

## 2. 数据复用与接入架构（复用首页/记忆湖同款只读路径）

**统计页可直接调用的上下文对象（`main.cpp:131–151` setContextProperty，全局可见）：**

| 用途 | 调用 | 返回字段 | 行号示意 |
|---|---|---|---|
| 区间 app 排行（前台+音频并集） | `usageStatManager.activeSoftwareForRange(range)` | `groupKey,appId,name,path,seconds,time,category,iconColors,brandColor,siteDomain` | usage_stat_manager.cpp:39 |
| 区间总秒数 | `usageStatManager.activeSoftwareSecondsForRange(range)` | int | :45 |
| 月/年/总分钟 | `usageStatManager.{month,year,all}SoftwareMinutes`（Q_PROPERTY） | int（**无 week**） | :23–25 |
| 会话段（打开次数/最长） | `usageStatManager.foregroundSegmentsForRange(range)` | `groupKey,appName,sessionCount,longestSec,segments[]` | :55 |
| 指定自然月聚合（环比） | `usageStatManager.activeSoftwareForMonth(y,m)` | 同 active 排行 | :58 |
| 当月每天秒数 | `usageStatManager.dailySecondsForMonth(y,m)` | `[{day,seconds}]`（整月补 0） | :62 |
| 分类占比饼（真实主题分类） | `dailyCardService.memoryLakeDay(usmApps,segments).usageShare` | `[{name,seconds,percent,isOther}]` | daily_card_service.cpp:1068 |
| 月度回顾（MoM/keywords/趋势） | `dailyCardService.memoryLakeRecap(monthApps,monthSegments,lastMonthApps,dailySeries)` | `slides`（含 MoM/keywords） | daily_card_service.h:51 |
| 手动项目排行 | `projectManager.projectsForRange(range)` | `name,tag,seconds,time`（**无 week**） | DesktopStatsPage.qml:147 |
| app 图标 | `image://appicon/<exe path>` via `AppVisual.js` | OS 图标 + 首字母兜底 | app_icon_image_provider.h:7 |

**range 取值 = `day/month/year/all`，无 `week`**（`usage_stat_manager.cpp:946–962 matchesRange`，
锚定 `QDate::currentDate()`；`ProjectManager::rangeStartUnix` 同样无 week）。

**原始数据契约（一切派生最终读这里）**：service 独占写
`timearc_service.db`，UI 只读。`apps` 保存平台、显示名、图标和可执行路径；
`frontmost_sessions` 保存窗口标题、起止时间和 active/idle 秒数；
`media_sessions` 保存媒体类型、标题和起止时间。源头不含 category/tag/focus
标记或打开次数；这些仍由 UI 读模型派生。统计页通过
`UsageStatManager`/`StatsService` 的 service-DB repositories 读取这三张表。

---

## 3. 全量内容清单（逐处过一遍统计页）

> 风险图例：✅ 现成可用 · 🟡 派生（现有返回值可算）· 🧱 缺后端聚合（须新增 C++）·
> 🎨 产品/设计决策 · 🤖 AI 门控。

| 视图·元素（v88 行） | 当前=写死 | 真实来源 / 改动 | 状态 |
|---|---|---|---|
| 月·本月总使用 + 环比（14355） | 168h / +12h | `monthSoftwareMinutes` + `memoryLakeRecap` MoM | ✅ |
| 月·应用排行 Top5（14383–14391） | mock | `activeSoftwareForRange("month")` top5 + 图标 + segments 次数 | ✅ |
| 月·月度关键词（14393–14397） | mock | `memoryLakeRecap` keywords | ✅ |
| 年·应用排行（14435–14443） | mock | `activeSoftwareForRange("year")` | ✅ |
| 年·年度总使用（14412） | 1,862h | `yearSoftwareMinutes`（当年；**YoY 见 G-2**） | ✅/🧱 |
| 排行行·图标 | 首字母 | `image://appicon` + `AppVisual.js`（首字母兜底） | ✅ |
| 周·本周总使用 + 日均（14282–14290） | 42.6h/6.1h | 需 **week 切片**（按天汇总 ÷7） | 🟡/🧱 G-1 |
| 周·7 日柱（14304–14312） | mock | 逐日秒数（无任意区间逐日 API） | 🟡/🧱 G-1 |
| 周·高频应用 + N 次打开（14326–14334） | mock | `activeSoftwareForRange` + `foregroundSegmentsForRange.sessionCount`，但须 week | 🟡/🧱 G-1 |
| 周·最长连续使用 + app（14292） | 2.8h | `foregroundSegmentsForRange.longestSec`+appName，须 week | 🟡/🧱 G-1 |
| 周/年·分类占比饼 + 占比（14315/14424） | mock 文案 | 分类器 usageShare（week/year 版）+ 降玻璃饼 | 🟡/🎨 G-1/A-1 |
| 月·娱乐占比 / 创作占比（14357–14358） | 47%/31% | 类目和（游戏[+视频]/创作[+笔记]）÷ 月总 | 🟡/🎨 A-1 |
| 月·周趋势折线（14360–14370） | mock | `dailySecondsForMonth` 按周分桶（QML） | 🟡 |
| 月·热力图（14372–14379） | mock | `dailySecondsForMonth` + 等级量化（QML） | 🟡/🎨 A-2 |
| 年·12 月柱（14419–14421） | mock | 循环 `activeSoftwareForMonth(y,1..12)` 汇总 | 🟡/🧱 G-7 |
| 年·最活跃月份（14413） | 8月 | 12 月序列取 max | 🟡/🧱 G-7 |
| 年·打开应用 84 + 高频 12（14415） | mock | distinct=`activeSoftwareForRange("year")` 计数；高频=阈值计数 | 🟡/🎨 A-4 |
| 周/月/年·洞察 + 行动建议（14336–14348…） | mock 文案 | 本地确定性模板（扩 DCS / QML） | 🟡/🎨/🤖 A-3 |
| 周·切换次数（14297） | 186 | 有序记录差分（无现成聚合） | 🧱 G-4 |
| 年·年度专注（14414） | 316h | 全年逐日连续块扫描（无现成聚合） | 🧱 G-6 |
| 顶栏·期次 ‹本期›（14270–14274） | 仅 toast | 显式窗口 range API（prev/next 任意周/年） | 🧱 G-9 |
| 导出 周/月/年报（14339…） | stub JSON | 导出 API（序列化视图模型） | 🧱 G-10 |

---

## 4. 问题展开 · 分类口径（最关键决策）

v88 饼/占比写的类目是 **游戏 / 设计 / 学习 / 社交 / 其它**（周）与 **创作·设计 / 游戏 / 学习 /
社交·其它**（年）。后端分类器 `UsageStatManager::classifyActivity`（`usage_stat_manager.cpp:259–337`）
返回的是 **系统 / 视频 / 音乐 / 浏览 / 开发 / 社交 / 游戏 / 办公 / 创作 / 笔记 / 其它**（站点
category 来自 `site_catalog.h:10–116`）；另有 `DailyCardService::classifyApp`（`daily_card_service.cpp:49–74`）
6 桶兜底（游戏/视频/音乐/社交/开发/其它）。

**冲突**：① 无「设计」自动桶（最接近 = 创作 = PS/Figma/Premiere/Blender）；② 无「学习」自动桶
（学习只在 `project_manager.cpp:15` 手动项目 tag / `database_manager.cpp:181` 日历 tag 色）；
③ 视觉小说不从「游戏」拆出。**所有饼 + 娱乐/创作占比卡都阻塞于此**（A-1）。

可选解（择一，产品定）：
- **(推荐) 展示真实桶**：饼直接画分类器真实 top-N + 其它（= `DailyUsageShare` 现有做法），
  legend 文案随真实类目变。零造假、零新分类逻辑。
- **重映射**：把「创作」标为「设计」，「学习」用新关键词集（或并 笔记+办公+手动学习 apps）。
  需改分类器 → 动 `usage_stat_manager.cpp`（非冻结，但属新增分类规则，须评审一致性）。
- **改 v88 文案**：承认原型类目是占位，统计页用产品确定的最终类目集。

---

## 5. 问题展开 · 周维度（最大结构缺口）

后端**完全没有 week 概念**：`matchesRange` 只识 day/month/year/all，且都锚定「今天/本月/本年」；
唯一逐日切片 `dailySecondsForMonth` 锚定自然月。于是 v88 周视图的**每一项**（总用/日均/7 柱/
切换/分类饼/高频/最长）都缺数据入口。两条路（G-1）：

- **(轻) QML 逐日**：需要一个「任意起止的逐日 active 秒数」入口——现状没有
  （`softwareSecondsForRange` 只给固定 day/month/year/all 当前窗口）。所以纯 QML 也**做不到**
  任意一周，除非……
- **(正解) 新增 C++**：给 `UsageStatManager` 增 `dailySecondsForRange(startUnix,endUnix)`
  （或显式 `dailySecondsForWeek(year, isoWeek)`）+ 让 `activeSoftwareForRange` /
  `foregroundSegmentsForRange` 支持 `"week"`（在 `matchesRange` 加 ISO 周窗口）。改的是
  `usage_stat_manager.cpp` 本体（非冻结），但**新增方法不动磁盘契约**。这是统计页落地的**第一硬缺口**。

---

## 6. 待决问题汇总（产品 / 设计决策，须先答）

> 这些不是「写代码就能解决」，需要产品/设计先拍板（对应功能文档 GAPS A）。

1. **A-1 分类口径**：真实桶 / 重映射 / 改文案？（阻塞所有饼+占比，见 §4）
2. **A-2 热力等级阈值**：固定秒带 vs 本月分位数？影响热力观感与跨月可比性。
3. **A-3 洞察/建议来源**：周/年级本地模板放 QML 还是 DCS 新方法（注意 db_smoke 契约）？
   先上模板、AI 留 Phase-3？模板措辞与口径谁定？
4. **A-4 「打开次数」「高频应用」定义**：沿用 60s 合并间隙（`foregroundSegmentsForRange`，
   `usage_stat_manager.cpp:51–55`）当「一次打开」？「高频」阈值 = sessionCount？使用天数？
   （真 PID 启动数不可得，process_id 落盘前丢弃。）
5. **A-5 「专注」定义**：无番茄钟持久化（`TimerManager` 是无持久化手动秒表，`timer_manager.h:11–47`）。
   专注 = 活动派生连续块——间隙/最短阈值（现 `daily_card_service.cpp:21–24` 用 10min 间隙/5min
   最短）多少？哪些类目算专注（开发/办公/笔记）？年专注是否值得做（§7 G-6 成本高）？
6. **A-6 期次/导出取舍**：先诚实占位还是本期实装（需 G-9/G-10 新 C++）？导出格式（JSON/CSV/
   PDF）与落盘位置？文件命名用 TimeArc（v88 误用「Memory Lake」）。
7. **A-7 历史深度**：YoY/上周/12 月柱/年专注都依赖 JSONL 累计——目标机有多少历史？不足时
   如何降级（隐藏 YoY？标「数据不足」？）。**代码无法判定，须实测（§12）。**

---

## 7. 后端能力差距（需新增 C++ 聚合，不改 schema）

> 硬缺口 = 现有返回值**算不出**、必须新增聚合/接口。建议接口均**只读 JSONL、不动磁盘契约**。

| # | 缺口 | 用途（v88 卡） | 建议接口 / 派生 | 风险 |
|---|---|---|---|---|
| G-1 | **无 week range / 无任意区间逐日切片** | 周视图全部 | `UsageStatManager`：`matchesRange` 加 `"week"`（ISO 周）；新增 `dailySecondsForRange(startUnix,endUnix)` | 🧱 第一缺口，无 week 周视图无从谈起 |
| G-2 | **无 YoY（指定年聚合）** | 年·总使用环比 | 新增 `activeSoftwareForYear(year)` / `softwareSecondsForYear(year)`（按 `record.year()` 聚） | 依赖历史深度 |
| G-3 | **无可复用饼组件入参 + 真实分类占比按 range** | 周/年分类饼 | `DailyUsageShare` 加 `glassStrength`（渲染 §4.1）；饼数据 = `memoryLakeDay(usmApps,segments).usageShare` 的 week/year 版（QML 传对应 range 的 active+segments） | 与 A-1 耦合 |
| G-4 | **无 app 切换次数** | 周·切换次数 | 新增 `switchCountForRange(range)`：按 start 排序、相邻 activity key 不同计数（或 QML 在有序记录上算，但无记录级 QML 入口→倾向 C++） | 定义见 A-4 |
| G-5 | **热力等级量化 / 周分桶 / distinct·高频计数** | 月热力/月周趋势/年 distinct | 可全在 **QML** 由 `dailySecondsForMonth` + `activeSoftwareForRange` 派生（阈值 A-2/A-4） | 🟡 非硬缺口，列此备忘 |
| G-6 | **无年/月「专注」聚合** | 月·专注天数 / 年·专注小时 | 新增按日扫连续块的聚合（`focusSecondsForRange`/`focusDaysForMonth`），定义见 A-5 | 成本高 + 依赖历史 |
| G-7 | **无 12 月序列 / 峰值月** | 年·12 柱 / 最活跃月份 | 循环 `activeSoftwareForMonth(y,1..12)`（QML 可做但 12 次调用重）或新增 `monthlySecondsForYear(year)` | 依赖历史 |
| G-8 | **环比仅 MoM** | 周环比(WoW) | WoW 随 G-1 week range 落地（上周窗口）；YoY 随 G-2 | 与 G-1/G-2 耦合 |
| G-9 | **无任意期次窗口（prev/next）** | 顶栏期次切换 | 新增显式窗口 range（`*ForWindow(startUnix,endUnix)` 或 year+week/year+month 参数族） | 否则期次只能诚实禁用 |
| G-10 | **无导出 API** | 导出周/月/年报 | 新增 `exportReport(range)` Q_INVOKABLE（序列化视图模型→文件，UI 层组装更佳） | 格式/落盘见 A-6 |

> **G-1 是关键路径**。G-5 其实可在 QML 解决（标 🟡）。G-2/G-6/G-7/G-9 都受**历史深度**制约。

---

## 8. 分三阶段落地

> 任务用 `- [ ]`。新增 C++ 文件会动到冻结 `src/CMakeLists.txt` → 须先填变更提案（§10）。
> 改 `usage_stat_manager.cpp` / `daily_card_service.cpp` 本体不算冻结。

**阶段一（视觉 1:1 + 真实可用数据 + 诚实占位）——纯 QML，零 C++：**
- [ ] 1A `fullBleedPage` 加 stats；`DesktopStatsPage` 暗玻璃重皮（功能 §6 F-B0/M-B0）
- [ ] 1B 月/年视图接真实数据：月总+环比、月/年排行、月关键词、12 月柱（循环 monthly，G-7 临时 QML）
- [ ] 1C 分类饼复用 `DailyUsageShare`+`glassStrength`，**展示真实类目**（A-1 暂取真实桶）
- [ ] 1D 月周趋势 / 月热力 / distinct·高频 在 QML 派生（G-5）
- [ ] 1E 洞察/建议本地模板（A-3 暂用 category-keyed 模板扩展）
- [ ] 1F 周视图、切换次数、年专注、YoY、期次、导出 → **诚实占位/禁用**（不假装可用）
- [ ] 1G 空态 / 昼夜 / 响应式（min 1280×720）

**阶段二（补齐周维度 + 关键聚合）——新增 C++（评审 G-1/G-4）：**
- [ ] 2A `UsageStatManager` 加 `"week"` range + `dailySecondsForRange`（G-1）→ 周视图全活
- [ ] 2B `switchCountForRange`（G-4，定义 A-4）
- [ ] 2C 周环比 WoW（随 G-1）
- [ ] 2D 把 1B 的 12 月柱改用 `monthlySecondsForYear`（G-7，去掉 12 次调用）

**阶段三（重型 / 受历史制约 / 受门控）：**
- [ ] 3A YoY（G-2）+ 历史不足降级（A-7）
- [ ] 3B 年/月专注聚合（G-6，定义 A-5）
- [ ] 3C 期次任意窗口（G-9）+ 导出（G-10，格式 A-6）
- [ ] 3D （门控）真 AI 洞察：仅在 原始→本地摘要→隐私过滤→用户确认→AI 管线就绪后（当前零代码）

---

## 9. 数据契约 / 隐私 / 安全边界

- usage 数据**只**经 `UsageStatManager` 读 JSONL；**禁** IPC/socket/共享内存/直连 service 内部。
- 分类只用本地分类器（exe 标识 + 站点 category）；窗口标题仅本地用于浏览器视频/音乐细分，
  **不展示、不存、不送 AI**（`usage_stat_manager.cpp` classify 注释）。
- 统计页**只读**：零 usage/SQLite 写入；唯一可选写 = UI 私有「记住 range」偏好。
- 洞察/建议 = 本地确定性模板（`aiGenerated:false`）。真 AI 须走门控管线，且**绝不**喂原始日志/
  聊天/截图/音频/未授权标题（`.harness/rules/07-product-ai-cards.md` AI 硬限制；
  `docs/card-ai-development-spec.md` payload 政策）。
- 不改磁盘契约、不改 SQLite schema、不在源头加字段（统计页是消费方，不是采集方）。

---

## 10. 代码编辑法规 — 文件红线

> 依据：`.harness/CHARTER.md` §3 冻结清单 + `.harness/state/frozen-files.json` 哈希锁
> + `CLAUDE.md` 架构边界。

- 🔴 **绝不可改（冻结）**：清单见 CHARTER §3。本计划唯一可能触碰 = **新增 C++ 源**会动到冻结
  `src/CMakeLists.txt`（阶段二/三的 G-1/G-2/G-4/G-6/G-9/G-10 若拆新文件）→ **先填**
  `.harness/templates/change-proposal.md` 进 `journal/sessions/`，否则 `harness_check.py` pass2 拦。
- ⛔ **绝不可碰**：`src/service/`（守护进程/采集端，独立进程）。注意 `src/service/`（**单数** =
  守护进程，禁碰）与 `src/services/`（**复数**，多一个 s = UI 应用服务层，**可改**）。
- 🟢 **可以改**：`src/services/usage_stat_manager.cpp`/`.h`、`daily_card_service.cpp`/`.h`
  （本体非冻结，新增只读聚合方法）；`qml/desktop/pages/DesktopStatsPage.qml`；
  `qml/desktop/DesktopAppShell.qml`（fullBleedPage 加 stats）；
  `qml/desktop/memorylake/DailyUsageShare.qml`（加 glassStrength）/`MemoryLakeStyle.qml`（加 changeUp）。
- 📋 **预期不符必登记**：实测字段/历史/口径与本文不符 → `record_error.py --level <L1|L2|L3>` +
  追加本文 §12。
- 流程纪律：① 会话起 `preflight.py --track B`；② 任何 build 走 `build.py`（非裸 cmake）；
  ③ Qt/QML 跑后 `scan_qt_log.py`；④ 提交前 `harness_check.py`（exit≠0 不提交）。

---

## 11. 验收总清单

**阶段一：**
- [ ] 月/年真实数据全接（总用/排行/关键词/12 月柱/分类饼真实类目/趋势/热力/distinct）
- [ ] 饼复用 + 降玻璃（`glassStrength≈0.45`），清晰扇区
- [ ] 周/切换/年专注/YoY/期次/导出 = 诚实占位（无假数据按钮）
- [ ] 空态 + 昼夜 + min 1280×720 不破版
- [ ] 全程只读；`scan_qt_log` 无新 warning；`harness_check` exit 0

**阶段二：**
- [ ] week range + `dailySecondsForRange` 落地，周视图全活（变更提案已批）
- [ ] 切换次数真实；WoW 真实

**阶段三：**
- [ ] YoY/年专注/期次/导出按决策实装或明确不做；历史不足有降级
- [ ] （如启用）AI 洞察走完整门控管线

---

## 12. 实测登记（实现期按时间追加）

> 体例同 `docs/memory-lake-integration-issues.md`：每条
> `日期 / 位置(计划 §x 或 文件:行) / 预期 / 实际 / 影响 / 处置(改计划? 走空态? 已 record_error(Lx)?)`，
> 状态前缀 `[OPEN] / [RESOLVED] / [WONTFIX]`。开工前已知假设（待实测）：

- **[RESOLVED] H-2 week 落地路径**（2026-06-07，阶段一+G-1 落地）：按计划在
  `usage_stat_manager.cpp` 加 `matchesRange` 的 `"week"` 分支（周一为首、含两端，
  对齐 QDate::dayOfWeek）+ 新增 `dailySecondsForRange(startUnixSec,endUnixSec)`
  （镜像 `dailySecondsForMonth` 的按日并集逻辑）。无更轻入口（纯 QML 无任意区间逐日切片）。
  周窗口起止由 QML 用本地周一 00:00 计算后传入，与 `matchesRange("week")` 口径一致。
  处置：已实装，周视图全活；`activeSoftware*ForRange/foregroundSegmentsForRange("week")`
  随 matchesRange 自动支持。**未新增 .cpp/.h → 未触碰冻结 CMakeLists，无需变更提案。**
- **[RESOLVED] H-4 db_smoke 契约**（2026-06-07）：洞察/建议模板**留在 QML**（未放 DCS），
  且统计页对 DCS 的调用（memoryLakeDay/memoryLakeRecap）全部由 QML 传入 USM 数据，
  DCS 仍**零引用 USM 符号**。build.py 干净（含 db_smoke 目标），契约成立。
- **[RESOLVED] H-5 切换次数（G-4）**（2026-06-07）：实测 `foregroundSegmentsForRange`
  暴露了每 app 的 segment 级 startUnixSec，**足以在 QML 摊平+排序+相邻 groupKey 差分**
  重建全局切换序列（即 A-4 的 60s 合并口径）。故 G-4 **无需新 C++**（文档原假设「倾向 C++」
  已被实测推翻，改 QML 派生）。
- **[OPEN] H-1 历史深度**：实测目标机（开发机）当前 JSONL 仅约本周/本月一周量级数据
  （月总≈周总 82.8h；本年 96.6h、distinct 38；Jan–May 近 0）。故年 12 柱仅 6 月有显著柱、
  月周趋势因 6/1–6/7 落在单一 ISO 周而走「数据不足」降级（A-7 优雅降级生效，非 bug）。
  YoY/年专注待阶段三；历史深度仍随机器而异，保持降级策略。处置：保留诚实降级。
- **[OPEN] H-3 分类口径**：阶段一按 A-1 推荐取**真实桶**（饼/占比 = 分类器真实类目，
  娱乐=游戏+视频、创作=创作+笔记）。产品最终口径未拍板，沿用真实桶不造假。处置：待产品。
