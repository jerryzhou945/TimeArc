# 统计页 · 功能复刻规范（行为 / 状态 / 复刻规则·标准·步骤）

> 配套文档：`docs/stats-render-pipeline-replication.md`（同页渲染管线）、
> `docs/stats-backend-data-gaps.md`（后端数据缺口与接入计划 = 本页的「问题文档」）。
> 设计稿真值：`MemoryLakeDesign/TimeArcDesign_v88.stripped.html`
> ——统计页 DOM `14243–14465`、CSS（暗）`10705–11370`（饼 `11137–11175`；light 覆盖
> `13056–13072 / 13547–13559`）、统计页 JS `15280–15413`、导航「统计」项 `13698`。
> 数据来源：与首页/记忆湖**同款只读路径**——`UsageStatManager`（读 service JSONL）
> + `DailyCardService`（本地确定性聚合），不新开数据通道（详见 §3、缺口文档）。
> 重构目标：`qml/desktop/pages/DesktopStatsPage.qml`（已存在 = **重皮+重构**，非绿地）。
> Track：**B（新能力 / 重皮）**。本文遵循首页/日历法规体例：
> **必须 (MUST) / 应当 (SHOULD) / 可选 (MAY)**，违反「必须」即不合格。

---

## §0 概览：统计页是什么 + 已定决策

统计页是一个**全幅暗玻璃覆盖页**（v88 `.stats-page`：`inset:18px`、`radius:26px`、
近黑竖渐变 + 双角径向辉光 + 42px 方格底纹），结构 = 左栏（品牌 + 周/月/年范围 Tab +
洞察小卡）+ 右主区（顶栏标题/期次切换/返回 + 滚动卡片网格）。右主区按范围切换
**三套视图**：周（week）/ 月（month）/ 年（year），每套是一个 12 列 `stats-grid`，
卡片含：指标卡、柱状图、**分类占比甜甜圈**、排行榜、洞察、行动建议；月视图另加
**折线趋势 + 月度热力图**，年视图用 12 月柱状图。

**v88 原型的统计 JS（`15280–15413`）是 100% mock**：所有数字写死在 DOM，JS 只做
section 显隐切换、重启 CSS 动画、导出一段 stub JSON。所以本次复刻 = 把视觉 1:1 搬到
QML 暗玻璃 + 把**全部数据接到真实后端**（能接的接、接不了的登记到缺口文档）。

**已定决策：**

- **D-FULLBLEED**：统计页走**全幅暗玻璃**，与日历/记忆湖/回顾同列——
  在 `DesktopAppShell.qml:61–62` 的 `fullBleedPage` 加入 `"stats"`，并把现有
  `DesktopStatsPage.qml` 由「奶油浅色 dashboard」重皮为 `MemoryLakeStyle` 暗玻璃
  （沿用日历页 PR#22 的零-C++ 重皮范式）。**不**新增路由：`navItems` 已含
  「统计 / stats」项（`DesktopAppShell.qml:133–134`），`currentPageSource` 已映射到
  `DesktopStatsPage.qml`（`:170`）。
- **D-REUSE-PIE**：分类占比饼**复用首页甜甜圈** `DailyUsageShare.qml`（Canvas 真实
  扇区 + 中心孔 + 图例），但**降低毛玻璃质感**（统计页用户要看清版本）：调小
  `MultiEffect.blurMax`/`opacity`、降 `GlowCircle.glowOpacity`、关呼吸光环——保留扇区、
  中心孔、外缘描边、方格（见渲染文档 §4 + §5）。
- **D-REAL-CATEGORY（不造假）**：饼/占比展示**分类器返回的真实主题分类**（top-N + 其它），
  **不**写死 v88 文案里的「游戏/设计/学习/其它」。v88 的类目是 mock；强行贴标会
  造假（违反 G5）。是否把分类器桶名重映射成 v88 措辞 = **产品决策**（GAPS §7 A1）。
- **D-LOCAL-INSIGHT**：洞察/建议/总结**先以本地确定性模板**落地（与 `memoryLakeDay`/
  `memoryLakeRecap` 同源同性，`aiGenerated:false`），**不**接真 AI（真 AI 受产品法规
  门控、当前零代码，属 Phase-3，见缺口文档 §7 + `.harness/rules/07-product-ai-cards.md`）。
- **D-READONLY**：统计页**只读**。绝不写 usage 记录、绝不碰磁盘契约/SQLite schema；
  唯一写动作仅可能是「记住上次选中的范围」这种 UI 私有偏好（可选，见 G3）。

---

## §1 QML 组件架构（重皮 · 复用优先）

```
DesktopStatsPage.qml（Item，重皮为暗玻璃；保留 nightMode 注入 + 数据刷新契约）
├─ MemoryLakeStyle { id: ml; night: nightMode }      // 新增：单一令牌源（同日历页）
├─ 背景层（仅 fullBleed 生效；外框/玻璃由 Shell 关掉）
│   ├─ Rectangle 近黑竖渐变（ml.calPageTop→calPageBottom）
│   ├─ GridTexture（42px 方格，ml.gridLine）            // 复用
│   └─ GlowCircle ×2（左上 aqua / 右上 violet 角辉）     // 复用
├─ RowLayout 顶层壳（stats-shell：250px 左栏 + 1fr 右主区）
│   ├─ 左栏 stats-side（品牌块 + 范围 Tab ×3 + 洞察小卡）
│   │   └─ RangeTab（周/月/年，复用 calendar 三视图 Tab 范式）
│   └─ 右主区 stats-main
│       ├─ 顶栏 stats-topbar（标题/副标题 + 期次‹本期›/ + 返回首页）
│       └─ stats-scroll（SilkyFlickable / ScrollView）
│           └─ StatsGrid（12 列 Grid，按 range 切 week/month/year 三套）
│               ├─ MetricCard（指标卡：值 + badge + 变化）        // 新增（薄封装）
│               ├─ BarChart（柱状图：周 7 柱 / 年 12 柱）         // 新增（Repeater 矩形）
│               ├─ DailyUsageShare（分类饼，降玻璃模式）          // 复用首页
│               ├─ LineAreaChart（月周趋势，Canvas 折线+面积）    // 新增（Canvas）
│               ├─ Heatmap（月度热力，Repeater 单元格 lv0-4）     // 新增（Repeater）
│               ├─ RankingList（高频应用：图标/名/N次打开/时长）  // 复用 AppVisual.js
│               ├─ InsightCard（洞察段落）                        // 新增
│               └─ RecommendationCard（行动建议 1-2 条）          // 新增
└─ StatsToast（底部胶囊提示，复用 calToastBg 范式）
```

**保留不动（契约）：**
- 数据刷新管线：`Connections{target:usageStatManager onUsageStatsChanged}`
  + `Connections{target:projectManager onProjectsChanged}` + 5s `Timer` + `refresh()`
  （`DesktopStatsPage.qml:44–65`、`116–124`）——**保留**，只换上层 range 维度。
- 图标取色：`AppVisual.js`（`appIconSource/appIconLabel/appColor`）+ `image://appicon`
  （`:215–225`、`:658–681`）——**保留**。
- 主题注入：`nightMode` 由 Shell `applyThemeToLoadedPage()` 注入
  （`DesktopAppShell.qml:803`）——**保留**该属性名，新增 `MemoryLakeStyle{night:nightMode}`。
- 全局上下文对象（`main.cpp:131–151` setContextProperty）：`usageStatManager` /
  `dailyCardService` / `projectManager` 全局可见，**无需注入**，直接调用。

**整体替换：** 现有奶油浅色调色板（`:13–35`）、`summaryStats/distributionStats`
两块布局（`:227–583`）、Top apps/projects 双 ListView（`:585–887`）——按 v88 网格重写。

---

## §2 功能子系统逐项规格（复刻规则 / 标准 / 步骤）

> 每节三块：**规则**（v88 的确切行为，逐字事实 + 行号）/ **标准**（必须·应当·可选）/
> **步骤**（QML 落地次序）。数据来源代号见 §3。

### §2.1 全幅入口与页壳

- **规则**：v88 `.stats-page` 由 nav「统计」点击 `open`（`15364–15367`），ESC/点其他 nav
  关闭（`15403–15413`）；`inset:18px`、`radius:26px`、近黑渐变 + 角辉 + 42px 方格
  （CSS `10705–10743`）。壳 = `grid 250px 1fr`（`10745–10754`）。
- **标准**：
  - **必须**：在 `fullBleedPage` 加 `"stats"`；进入即全幅暗玻璃（无「框中框」），
    `nightMode` 切换两套配色都正确（C9）。
  - **必须**：返回首页 = 顶栏「返回首页」按钮 → `selectedIndex = indexOfPage("memorylake")`
    （等价 v88 `closeStatsPage`）。
  - **应当**：左栏 ≤ 1200px 时折叠/隐藏（v88 媒体查询 `11354–11370`，见 §2.10 / C10）。
- **步骤**：①改 `DesktopAppShell.qml:61–62` fullBleedPage；②`DesktopStatsPage.qml` 顶部加
  `MemoryLakeStyle{id:ml;night:nightMode}` + 背景三件套；③RowLayout 250+1fr 壳。

### §2.2 范围切换（周 / 月 / 年）

- **规则**：左栏三 Tab `data-stats-range=week|month|year`（DOM `14252–14256`），点选
  切 active section + 改顶栏标题/副标题 + 左栏洞察标题/正文（JS `statsText` `15292–15311`、
  `setStatsRange` `15321–15340`），并重启该 section 动画 + toast「已切换到…」。
- **标准**：
  - **必须**：三视图互斥显隐；默认 `week`（v88 默认 active=week，`14253`）。
  - **必须**：切换时按 §3 重新拉取对应 range 的真实数据并重算派生量（不得残留上一视图）。
  - **应当**：切换有 v88 `statsSectionIn .28s`（`10940–10943`）入场动效（blur→clear）。
- **步骤**：①`property string range:"week"`；②`RangeTab` onClicked 改 range + toast；
  ③三视图用 `Loader`/`visible` 切；④`onRangeChanged` 触发数据重算（§2.3）。

### §2.3 数据装配（真实后端 → 视图模型）

- **规则**：v88 三视图数字全为 mock。本步把每张卡接到真实来源（§3 映射表）。**关键约束**：
  后端 range 只支持 `day/month/year/all`，**无 `week`**（`usage_stat_manager.cpp:946–962`
  `matchesRange`）。
- **标准**：
  - **必须（月/年大头直接可用）**：月总时长 = `usageStatManager.monthSoftwareMinutes`
    或 `activeSoftwareSecondsForRange("month")`；月环比 = `dailyCardService.memoryLakeRecap`
    的 MoM；月/年排行 = `activeSoftwareForRange("month"|"year")`；月关键词 = `memoryLakeRecap`。
  - **必须（周视图）**：周一切指标（总用/日均/7 柱/高频/最长/切换/分类）**须按天派生或新增
    week 聚合**——**不得**伪造或用「本月」冒充「本周」。后端如未提供 week，**按缺口文档
    §7 G-1 处置**（QML 端逐日扫 / 或新增 C++ week range），并把实测不符登记问题文档。
  - **必须（不造假）**：任一来源缺失 → 走空态/诚实占位（C6），**不**写死 mock 数字。
  - **应当**：QML 把 `activeSoftwareForRange` 结果 + `foregroundSegmentsForRange` 结果
    传入 `dailyCardService.memoryLakeDay(usmApps,segments)` 取 `usageShare`（饼），
    **维持 db_smoke 契约**（DCS 不引用 USM 符号，数据由 QML 传入，见 G4）。
- **步骤**：①写 `viewModel(range)` 装配函数（§3）；②周派生用 day-by-day（缺口 G-1）；
  ③派生量（切换次数/热力等级/周分桶/distinct）在 QML 算（§3 末 + 缺口 §7）。

### §2.4 指标卡（MetricCard）

- **规则**：v88 `stats-card span-3`：head（h4 标题 + p 说明 + `stats-badge`）+ `stats-metric-value`
  （大号值）+ `stats-metric-change`（升=绿 `rgba(125,255,178)`/降=粉 `.down`）。
  周：本周总使用/日均使用/最长连续使用/切换次数（DOM `14281–14300`）；
  月：本月总使用/专注天数/娱乐占比/创作占比（`14355–14358`）；
  年：年度总使用/最活跃月份/年度专注/打开应用（`14412–14415`）。
- **标准**：
  - **必须**：值/变化来自真实来源（§3）；可用项见可用矩阵——月总用(D-OK)、月/年排行衍生项可算；
    周/年/专注/切换/distinct 多为派生或缺口（缺口 §7）。
  - **必须**：`change` 升降配色按真实符号（≥0 绿 / <0 粉），不得固定。
  - **应当**：缺真实环比时 `change` 留空或标「—」，不显示假箭头（C6）。
- **步骤**：①`MetricCard{title,sub,badge,value,change,changeDown}` 薄封装；
  ②各视图按 §3 填值；③缺口项接「诚实占位」文案 + 登记问题文档。

### §2.5 柱状图（BarChart：周 7 柱 / 年 12 柱）

- **规则**：v88 `stats-bar-chart`（`11045–11095`）：`flex` 底对齐，每柱 `height:%`、
  hover 顶显 `data-value`、底标 `data-label`，入场 `statsBarGrow .68s`。周=Mon–Sun 7 柱
  （`14304–14312`），年=Jan–Dec 12 柱（`14419–14421`）。
- **标准**：
  - **必须**：柱高 = 当日/当月真实秒数 ÷ 该视图最大值（归一），label/value 真实。
  - **必须（年）**：12 月序列须真实（缺口 §7 G-7：循环 `activeSoftwareForMonth(y,1..12)`
    或 `dailySecondsForMonth` 逐月汇总；依赖 JSONL 历史深度）。
  - **必须（周）**：7 日序列来自 day-by-day 派生（缺口 §7 G-1）。
- **步骤**：①`BarChart{model:[{label,seconds}]}` Repeater 矩形 + `scaleY` 动画；
  ②周喂 7 日派生、年喂 12 月派生；③hover tip。

### §2.6 分类占比甜甜圈（复用 DailyUsageShare，降玻璃）

- **规则**：v88 `stats-pie`（`11137–11175`）= conic 扇区 + 16px inset 中心孔 + 中心
  `data-center`（总时数）+ `stats-legend` 图例点（同色霓虹）。周/年各一（`14315–14324`、
  `14424–14433`）。
- **标准**：
  - **必须**：扇区/图例 = 分类器**真实**主题占比（`dailyCardService.memoryLakeDay(...).usageShare`
    在对应 range 上的版本）；中心 = 该 range 真实总时数。展示真实类目（D-REAL-CATEGORY），
    **不**写死 v88 文案。
  - **必须**：复用 `DailyUsageShare.qml`，开「降玻璃」模式（渲染 §4/§5）：清晰扇区优先。
  - **应当**：周饼需 week range 的 usageShare（缺口 §7 G-1）；年饼用 `year` range。
  - **可选**：图例项 hover 高亮对应扇区。
- **步骤**：①给 `DailyUsageShare` 加 `clarity`/`glassStrength` 入参（或 `reducedGlass:true`）；
  ②周/年装配 `share`+`total` 传入；③缺 week usageShare 时按缺口处置。

### §2.7 月度专属：折线趋势 + 热力图

- **规则**：v88 月视图 `stats-line-chart`（SVG path line+area，`14360–14370`）+
  `stats-heatmap`（`grid 14 列`、cell `lv1-4` 亮度，`14372–14381`）。
- **标准**：
  - **必须**：折线 = 本月**周趋势**（`dailySecondsForMonth` 按 ISO 周/7 日分桶，QML 派生）；
    热力 = 本月每天真实秒数（`dailySecondsForMonth` 直供）量化成 lv0-4。
  - **必须**：热力**等级量化阈值**须确定（缺口 §7 A-2：固定秒带 vs 分位数），不得随手编。
  - **应当**：折线用 Canvas（`drawStatsLine` 描边动画等价物，见渲染 §4）。
- **步骤**：①`LineAreaChart{points}` Canvas；②`Heatmap{days:[{day,seconds}]}` + 量化函数；
  ③喂 `dailySecondsForMonth(curYear,curMonth)`。

### §2.8 高频应用排行（RankingList）

- **规则**：v88 `ranking-list`（`11235–11281`）：图标圆角块（首字母/图标）+ 名 + small
  （类目 · 「N 次打开」）+ 右侧时长。周/月/年各一（`14326–14334`、`14383–14391`、
  `14435–14443`）。
- **标准**：
  - **必须**：列表 = `activeSoftwareForRange(range)` 真实 top-N（按秒降序）；图标用
    `image://appicon`/`AppVisual.js`（首字母兜底）；时长真实。
  - **必须**：「N 次打开」= `foregroundSegmentsForRange(range)` 的 `sessionCount`
    （按 groupKey join），small 类目用 item.category。
  - **应当**：周需 week range（缺口 §7 G-1）；月/年直接可用。
- **步骤**：①`RankingList{model}`（复用现有 ListView delegate 取色逻辑）；
  ②join active + segments by groupKey；③周派生。

### §2.9 洞察 / 行动建议（InsightCard / RecommendationCard）

- **规则**：v88 `stats-insight`（段落）+ `stats-actions`（导出/生成建议按钮，`14336–14348`）
  + `recommendation-card`（编号建议 1-2 条，`14342–14348`）。月/年同构。
- **标准**：
  - **必须**：洞察/建议 = **本地确定性模板**（D-LOCAL-INSIGHT），基于真实聚合
    （top 类目/峰值时段/环比）生成，`aiGenerated:false`。复用/扩展
    `daily_card_service.cpp:1114–1162` 的 category-keyed 建议 chip 思路（但**周/年级模板
    需新写**，缺口 §7 A-3）。
  - **必须（产品边界）**：**不**接真 AI、不喂原始日志（`.harness/rules/07` §AI 硬限制）。
  - **应当**：无足够数据时给中性占位（「本周记录较少，暂不下结论」），不编故事。
- **步骤**：①`InsightCard{text}`/`RecommendationCard{items}`；②QML 端按真实聚合选模板，
  或（更稳）在 DailyCardService 增 `statsInsight(range聚合)`（缺口 §7 A-3，注意 db_smoke 契约）。

### §2.10 交互：期次切换 / 导出 / Toast / 键盘

- **规则**：v88 期次‹本期›（prev/current/next，JS `15378–15380` 仅 toast）；导出按钮
  下载 stub JSON（`15382–15400`）；toast（`15313–15319`）；ESC 关闭（`15409–15413`）。
- **标准**：
  - **必须**：toast、ESC 关闭、范围 Tab 切换 = 真实行为。
  - **应当（诚实）**：期次 prev/next 与导出**后端零实现**（缺口 §7 G-9/G-10）。二选一：
    (a) 先做**诚实禁用/占位**（按钮在，点了提示「即将支持」）；(b) 实装——需新增显式窗口
    range API + 导出 API（缺口）。**必须**：不得做成「看似能用实则假数据」的按钮。
  - **可选**：「生成建议/打开月度回顾/生成年终回顾」次级按钮——回顾按钮可路由到 recap 页。
- **步骤**：①StatsToast 组件；②ESC/返回 = 切 selectedIndex；③期次/导出按 (a) 诚实占位
  起步，实装挪到缺口 §8 阶段二/三。

---

## §3 持久化与数据模型

**现有后端只读契约（与首页/记忆湖同款，range ∈ day/month/year/all，无 week）：**

| 用途 | 调用（context property） | 返回要点 | 行号示意 |
|---|---|---|---|
| 区间 app 排行（前台+音频并集） | `usageStatManager.activeSoftwareForRange(range)` | `[{groupKey,appId,name,path,seconds,time,category,iconColors,brandColor,siteDomain}]` | usage_stat_manager.h:39 |
| 区间总秒数 | `usageStatManager.activeSoftwareSecondsForRange(range)` | int | usage_stat_manager.h:45 |
| 月/年/总分钟（Q_PROPERTY） | `usageStatManager.{month,year,all}SoftwareMinutes` | int（无 week） | usage_stat_manager.h:23–25 |
| 会话段（打开次数/最长） | `usageStatManager.foregroundSegmentsForRange(range)` | `[{groupKey,appName,sessionCount,longestSec,segments:[{startUnixSec,endUnixSec,seconds}]}]` | usage_stat_manager.h:55 |
| 指定自然月聚合（环比） | `usageStatManager.activeSoftwareForMonth(year,month)` | 同 active 排行 | usage_stat_manager.h:58 |
| 当月每天秒数序列 | `usageStatManager.dailySecondsForMonth(year,month)` | `[{day,seconds}]`（补 0 整月） | usage_stat_manager.h:62 |
| 分类占比饼（主题分类，真实） | `dailyCardService.memoryLakeDay(usmApps,segments).usageShare` | `[{name,seconds,percent,isOther}]` | daily_card_service.cpp:1068–1112 |
| 月度回顾（MoM/keywords/趋势） | `dailyCardService.memoryLakeRecap(monthApps,monthSegments,lastMonthApps,dailySeries)` | `{slides,...}` 含 MoM/keywords | daily_card_service.h:51 |
| 手动项目排行 | `projectManager.projectsForRange(range)` | `[{name,tag,seconds,time}]`（无 week） | DesktopStatsPage.qml:147 |
| app 图标 | `image://appicon/<exe path>` via `AppVisual.js` | OS 原生图标 + 首字母兜底 | app_icon_image_provider.h:7 |

**v88 卡片 → 来源 → 状态（可用矩阵，详尽版见缺口文档 §3/§7）：**

| 视图·卡片 | 真实来源 | 状态 |
|---|---|---|
| 月·总使用 + 环比 | `monthSoftwareMinutes` + `memoryLakeRecap` MoM | ✅ 可用 |
| 月/年·应用排行 | `activeSoftwareForRange("month"/"year")` | ✅ 可用 |
| 月·关键词 | `memoryLakeRecap` keywords | ✅ 可用 |
| app 图标 | `image://appicon` + AppVisual.js | ✅ 可用 |
| 周·总用/日均/7 柱/最长/高频 | `*ForRange`/`foregroundSegmentsForRange` 但**须 week 切片** | 🟡 派生（缺 week range，G-1） |
| 月·周趋势折线 | `dailySecondsForMonth` 分桶（QML） | 🟡 派生 |
| 月·热力图 | `dailySecondsForMonth` + 等级量化（QML） | 🟡 派生（阈值待定 A-2） |
| 年·峰值月/distinct/高频数/12 月柱 | 循环月聚合/计数（QML 或新 C++） | 🟡 派生（依赖历史深度，G-7） |
| 周/年·分类饼 + 占比 | 分类器 usageShare（week/year 版） | 🟡 部分（桶名映射 A-1 + week G-1 + 降玻璃饼组件） |
| 月·娱乐/创作占比 | 分类器类目和（游戏/视频；创作/笔记） | 🟡 部分（VN 不分、设计不可分 A-1） |
| 洞察/建议/年总结 | 本地模板（扩 daily_card_service） | 🟡 部分（周/年级模板需新写 A-3；真 AI 门控） |
| 周·切换次数 | 有序记录差分（新 C++/QML） | 🔴 缺（G-4） |
| 年·年度专注小时 | 全年逐日块扫描（新 C++） | 🔴 缺（G-6，依赖历史） |
| 年·YoY 环比 | 指定年聚合（新 C++） | 🔴 缺（G-2） |
| 期次 prev/next | 显式窗口 range API | 🔴 缺（G-9） |
| 导出报告 | 导出 API | 🔴 缺（G-10） |

**QML 端新算（不动磁盘契约，全在 UI 层派生；难点见缺口文档）：**
周逐日切片汇总、热力等级量化、月周分桶、distinct/high-frequency 计数、峰值月、缺失环比。

**令牌/持久化策略：** 全色/圆角/缓动取 `MemoryLakeStyle`（G1）。统计页本身**无业务持久化**
（只读）；唯一可选写 = 记住上次选中 range（UI 私有偏好，走 `settingsRepository` 或本地，G3）。

---

## §4 复刻规则总纲（全局条款 · 法规）

> 关键词：**必须 (MUST) / 应当 (SHOULD) / 可选 (MAY)**。

- **G1（token 单源，MUST）**：零内联 hex/rgba/radius/easing；全部 `MemoryLakeStyle.*`
  （night/day 两套自动）。v88 统计色已 1:1 命中既有令牌（aqua/violet/shareGold/sharePink/
  shareOther/glowCyan/gridLine/calPageTop·Bottom/easeSnappy），新增令牌列在渲染 §1。
- **G2（不越技法字典，SHOULD）**：饼/方格/角辉/玻璃片/边缘光对/圆角裁切复用
  `docs/memory-lake-art-lighting-qml-cookbook.md` 既有技法，不另起。
- **G3（持久化 UI 私有，MUST）**：统计页只读；如做「记住 range」，存 UI 私有偏好，
  不落业务库、不碰 usage 数据。
- **G4（磁盘契约边界，MUST）**：**禁** IPC/socket/共享内存/直连 service 内部；usage 数据
  只经 `UsageStatManager` 读 JSONL；分类/聚合走 `DailyCardService`，且**数据由 QML 传入**
  （db_smoke 链接 daily_card_service.cpp 但不链接 usage_stat_manager.cpp，DCS 不得引用 USM 符号）。
- **G5（不造假 / 诚实占位，MUST）**：任何卡缺真实来源 → 空态/中性占位，**不**写死 mock
  数字、**不**给假箭头、**不**编洞察故事。饼显示真实类目而非 v88 mock 文案。
- **G6（整段替换，SHOULD）**：奶油浅色旧布局整块替换为 v88 网格，不留半旧半新。
- **G7（圆角裁剪，MUST）**：方格/图表底纹用 `RoundedFrame` round-clip；`clip:true` 只裁
  矩形会在圆角戳方角（首页/日历同坑）。
- **G8（单一写路径 / 只读，MUST）**：统计页绝不写 usage/SQLite；保持唯一写路径在 service。
- **G9（保留契约，MUST）**：保留 `usageStatManager`/`projectManager` 的 `Connections`+`refresh`+
  5s `Timer` 数据管线与 `AppVisual.js` 取色；只在其上加 range 维度。
- **G10（冻结文件，MUST）**：scope 内无冻结文件。**唯一触发变更提案**的是「新增 C++ 源」
  （week range/切换次数/导出 等若落 C++ → 动到冻结 `src/CMakeLists.txt`）：须先填
  `templates/change-proposal.md` 进 `journal/sessions/`。改 `usage_stat_manager.cpp`/
  `daily_card_service.cpp` 本体不算冻结（依据 `.harness/CHARTER.md` §3 + frozen-files.json）。
- **G11（双壳 / 移动端，SHOULD）**：本次仅桌面端（`DesktopStatsPage.qml`）。移动端统计
  另有 `qml/mobile/pages/MobileHistoryPage.qml`，**超本次范围**，不在本文。

---

## §5 复刻标准 / 验收（Conformance）

> **PR 三联**：每条款 → `文件:行` → 截图/录屏证据（品红底 3× 超采样逐像素门见
> `docs/...` UI 验证笔记 / TimeArc UI build-verify 记忆）。**只读层**用 PrintWindow-by-PID
> 抓本实例（不抓用户窗口）。

| ID | 验收项 | 级别 |
|---|---|---|
| C0 | kill `TimeArc.exe` → `build.py` 干净（exit 0），启动无新 QML warning（`scan_qt_log`） | 必须 |
| C1 | nav「统计」进入 = 全幅暗玻璃（fullBleedPage 含 stats），无框中框 | 必须 |
| C2 | 周/月/年三视图互斥切换，默认 week，切换重算真实数据 | 必须 |
| C3 | 分类饼复用 DailyUsageShare、降玻璃（清晰扇区），显示**真实**类目占比 | 必须 |
| C4 | 柱/折线/热力均由真实聚合驱动；周 7 柱、年 12 柱、月热力等级化 | 必须 |
| C5 | 高频应用 = 真实 top-N + 真实图标 + 真实「N 次打开」+ 真实时长 | 必须 |
| C6 | 任一来源缺失走空态/诚实占位，无 mock 数字、无假箭头 | 必须 |
| C7 | 洞察/建议 = 本地确定性模板（aiGenerated:false），不接真 AI、不喂原始日志 | 必须 |
| C8 | 期次 prev/next 与导出：诚实占位或真实实装，杜绝「假数据按钮」 | 必须 |
| C9 | night/day 两套配色都正确（令牌单源） | 必须 |
| C10 | min 1280×720 与最大化均不破版；≤1200 左栏折叠（v88 媒体查询对齐） | 应当 |
| C11 | 统计页全程只读，零 usage/SQLite 写入 | 必须 |
| C12 | 实测与本文/缺口文档假设不符项，均已 `record_error` + 登记 `stats-backend-data-gaps`/issues | 必须 |

---

## §6 复刻方式步骤（F-B 批次，与渲染 M-B 咬合）

> 收尾每批：kill `TimeArc.exe` → `build.py` → 启动 → `scan_qt_log`
> →（撑爆 INDEX.md 行预算时 `git checkout HEAD -- .harness/journal/INDEX.md errors.jsonl`
> + 删 pass5 点名 orphan）→ `record_error.py`（任何 L1/L2/L3）→ `harness_check.py`（冻结 sha256 门）。

- **F-B0 页壳 + 全幅入口**：fullBleedPage 加 stats；DesktopStatsPage 暗玻璃重皮骨架
  （MemoryLakeStyle + 背景 + 250+1fr 壳 + 顶栏/返回）。（咬合 M-B0）
- **F-B1 数据层**：写 `viewModel(range)` 装配 + range 助手 + 周 day-by-day 派生 + 派生工具
  （切换次数/热力量化/周分桶/distinct）。先用月/年真实数据通路打通。（咬合 M-B1）
- **F-B2 指标卡**：MetricCard ×（4 周 / 4 月 / 4 年），接 §3 来源 + 升降配色 + 占位。（咬合 M-B2）
- **F-B3 图表**：BarChart（周/年）+ DailyUsageShare 降玻璃饼（周/年）+ LineAreaChart（月）
  + Heatmap（月）。（咬合 M-B3）
- **F-B4 排行 + 图例**：RankingList join active+segments；饼图例真实类目。（咬合 M-B4）
- **F-B5 洞察 / 建议**：InsightCard/RecommendationCard 本地模板（周/年级新模板）。（咬合 M-B5）
- **F-B6 交互**：范围 Tab + toast + ESC/返回 + 期次/导出**诚实占位**。（咬合 M-B6）
- **F-B7 空态 / 响应式 / 昼夜**：空态、≤1200 折叠、min 1280×720、night/day 校验。（咬合 M-B7）
- **F-B8（可选 · 阶段二/三）**：实装 week range / 切换次数 / 期次窗口 / 导出 / YoY / 年专注
  ——**须新增 C++**，走 G10 变更提案 + 缺口文档 §8。（咬合 M-B8）

---

## §7 GAPS / 待补充

> 分两类：**A=需产品/设计决策**；**B=v88 稿件本身的 bug/不一致（复刻时顺手修）**。
> 后端数据缺口（须新增聚合/接口的硬缺口）完整列在 `docs/stats-backend-data-gaps.md` §7（G-1..G-10）。

**A 类（产品 / 设计决策）：**
- **A1 分类口径**：v88 饼写「游戏/设计/学习/其它」，但分类器是 系统/视频/音乐/浏览/开发/
  社交/游戏/办公/创作/笔记/其它（无「设计」「学习」自动桶；学习仅手动项目 tag）。
  决策：①**展示真实桶**（推荐，不造假）；②把「创作」改标为「设计」并为「学习」造新关键词集；
  ③改 v88 文案。**所有饼/占比卡阻塞于此**。
- **A2 热力等级阈值**：lv0-4 用「固定秒带」还是「本月分位数」？影响热力观感一致性。
- **A3 洞察/建议模板**：周/年级本地模板由谁写、放哪（QML 还是 DailyCardService 新方法，
  注意 db_smoke 契约）？是否先上模板、AI 留 Phase-3？
- **A4 「打开次数」定义**：沿用 `foregroundSegmentsForRange` 的 60s 合并间隙（60s 内回切不算
  新「打开」），还是更严的启动计数（真 PID 启动数不可得——process_id 落盘前被丢弃）？
- **A5 期次/导出取舍**：先诚实占位还是本期实装（需新 C++）？导出格式/落盘位置？
- **A6 「专注」定义**：无番茄钟持久化（TimerManager 是无持久化手动秒表）。专注 = 活动派生
  连续块（间隙/最短时长阈值 + 哪些类目算专注：开发/办公/笔记？）须定义。

**B 类（v88 稿件 bug / 不一致）：**
- **B1**：周饼 legend 占比 35+26+21+18=100% 但年饼 34+28+21+17=100%——稿件数字自洽，
  复刻时**以真实占比为准**，不照搬。
- **B2**：v88 导出文件名/标题混用「Memory Lake」（`15386/15395`）而 app 名为 TimeArc——
  复刻导出（若实装）用 TimeArc 命名。
- **B3**：期次‹本期›按钮 v88 只弹 toast 不改数据——复刻**不得**沿袭这种假交互（见 C8）。

---

## §8 产品边界核对（charter）

- 统计页**只展示时间上下文**（应用使用时长/类目/趋势），**不**触碰聊天内容、截图/OCR、
  原始音频、浏览器历史/URL、原始日志上的 AI（`CLAUDE.md` 硬边界 + `.harness/rules/07`）。
- 分类只用本地确定性分类器（exe 标识 + 站点目录 category；窗口标题仅本地用于浏览器
  视频/音乐细分，不展示/不存/不送 AI）。
- 洞察/建议 = 本地模板；真 AI 须走 原始→本地摘要→隐私过滤→用户确认→AI 管线（当前零代码）。
- 最小可运行纵切：先把「真实数据 + 视觉 1:1 + 诚实占位」打通；week/切换/导出/YoY/年专注
  等硬缺口分阶段（缺口 §8），不为补全而提前堆 C++。

---

## §9 与既有文档关系

- **配套**：`docs/stats-render-pipeline-replication.md`（渲染管线 / CSS→QML / 降玻璃饼）；
  `docs/stats-backend-data-gaps.md`（后端缺口与接入计划 = 问题文档，含 G-1..G-10 + 分阶段）。
- **范式来源**：`docs/calendar-refactor-functional-replication.md`（全幅暗玻璃重皮 + 三视图 Tab
  范式）、`docs/memory-lake-memo-functional-replication.md`（三块规格体例）、
  `docs/memory-lake-backend-integration-plan.md` + `docs/memory-lake-integration-issues.md`
  （计划 + 问题登记两文档范式）。
- **复用组件**：`qml/desktop/memorylake/DailyUsageShare.qml`（饼）、`GridTexture.qml`、
  `GlowCircle.qml`、`RoundedFrame.qml`、`MemoryLakeStyle.qml`（令牌）、
  `qml/desktop/components/AppVisual.js`（图标取色）。
- **重构目标**：`qml/desktop/pages/DesktopStatsPage.qml`；入口 `qml/desktop/DesktopAppShell.qml`
  （`fullBleedPage` 加 stats）。
- **收尾建议**：把本三文档登进 `CLAUDE.md` 的 Product Context 与 `.harness/rules/04` 索引
  （仿日历/备忘文档的登记惯例）。
