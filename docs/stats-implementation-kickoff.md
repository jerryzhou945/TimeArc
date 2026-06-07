# 统计页 · 实现启动 Prompt（一次性落地）

> 用途：把下方 fenced 块**整段粘贴**给新一轮 Claude Code / Codex 会话，即可一次性实现 v88
> 「统计」页（视觉 1:1 + 接真实后端 + 诚实占位）。它把三份规范文档设为权威、把关键决策的默认值
> 钉死、并用「只扩现有 C++ 文件、不新建源文件」的技巧绕开冻结 `src/CMakeLists.txt` 的变更提案，
> 让三阶段能连着做完。
>
> 配套：`docs/stats-functional-replication.md` / `docs/stats-render-pipeline-replication.md` /
> `docs/stats-backend-data-gaps.md`（权威规范，prompt 内已引用）。Track **B**。

````text
你在 TimeArc 仓库（Qt6/QML，Windows，路径含空格 F:\Git Proj\TimeArc）实现 v88「统计」页。
这是一次完整落地（视觉 1:1 + 接真实后端 + 诚实占位），三份文档是权威规范，先读再动手。

== 必走的 harness（每步非零退出即停）==
1. python .harness/tools/preflight.py --track B   # 写 session log 到它打印的路径
2. 任何 build 走 python .harness/tools/build.py（禁裸 cmake）；先 kill TimeArc.exe（exe 锁）
3. Qt/QML 跑后 python .harness/tools/scan_qt_log.py
4. 任何 L1/L2/L3 错误 python .harness/tools/record_error.py --level <Lx> --track B --topic <slug> --summary "..."
5. 提交前 python .harness/tools/harness_check.py（exit≠0 不提交）；收尾若撑爆 INDEX.md：
   git checkout HEAD -- .harness/journal/INDEX.md .harness/journal/errors.jsonl + 删 pass5 点名 orphan

== 权威规范（先全文读）==
- docs/stats-functional-replication.md      行为/数据/复刻规则·标准(C0–C12)·步骤(F-B)
- docs/stats-render-pipeline-replication.md  CSS→QML/降玻璃甜甜圈/诚实天花板
- docs/stats-backend-data-gaps.md            后端缺口 G-1..G-10 / 待决问题 A / 三阶段 / 实测登记
- 设计稿真值 MemoryLakeDesign/TimeArcDesign_v88.stripped.html：DOM 14243–14465、CSS 10705–11370、JS 15280–15413

== 已钉死的默认决策（直接照做，无需再问）==
- A-1 分类口径：饼/占比**展示分类器真实类目**（top-4 + 其它），不贴 v88 mock 文案「游戏/设计/学习」。
- A-2 热力等级：按当月最大单日秒数分 5 级（0 / ≤25% / ≤50% / ≤75% / >75% → lv0-4），QML 量化。
- A-3 洞察/建议：本地确定性模板（aiGenerated:false），扩 daily_card_service.cpp:1114-1162 的 category-keyed 思路；**不接真 AI、不喂原始日志**。
- A-4 打开次数=foregroundSegmentsForRange 的 60s 合并间隙；高频应用=使用天数≥3 的 app 计数。
- A-5 专注=活动派生连续块（间隙 10min / 最短 5min，复用 segmentFocusBlocks），专注类目=开发/办公/笔记。
- A-6 期次/导出：先做（见阶段三）；导出 JSON 命名 timearc-<range>-stats.json（v88 误用 Memory Lake，改 TimeArc）。
- A-7 历史不足：YoY/上周/12 月柱/年专注数据不够时**优雅降级**（隐藏或标「数据不足」），不造假。
- G-1 周维度：在**现有** usage_stat_manager.{h,cpp} 内加 dailySecondsForRange(startUnix,endUnix) +
  matchesRange 支持 "week"（ISO 周、周一为首，对齐 v88/日历）。

== 文件红线 ==
🟢 可改：qml/desktop/pages/DesktopStatsPage.qml（重皮目标）、qml/desktop/DesktopAppShell.qml
   （fullBleedPage 加 "stats"，:61-62）、qml/desktop/memorylake/DailyUsageShare.qml（加 glassStrength）、
   MemoryLakeStyle.qml（加 changeUp 令牌）、src/services/usage_stat_manager.{h,cpp}、daily_card_service.{h,cpp}。
⛔ 禁碰：src/service/（单数=守护进程）。注意与 src/services/（复数,可改）只差一个 s。
🔴 关键技巧：**所有新后端聚合都加成现有文件的方法，不要新建 .cpp/.h**——否则动到冻结 src/CMakeLists.txt
   需先填 .harness/templates/change-proposal.md。保持 db_smoke 契约：DailyCardService 不引用 UsageStatManager
   符号（数据由 QML 传入）。统计页全程**只读**（零 usage/SQLite 写入）。零内联 hex（全 MemoryLakeStyle 令牌, G1）。

== 后端 API 速查（context property，全局可见；range=day/month/year/all，week 由 G-1 新增）==
usageStatManager.activeSoftwareForRange(range) → [{groupKey,name,path,seconds,time,category,iconColors,...}]
usageStatManager.activeSoftwareSecondsForRange(range) / {month,year,all}SoftwareMinutes
usageStatManager.foregroundSegmentsForRange(range) → [{groupKey,appName,sessionCount,longestSec,segments[]}]
usageStatManager.activeSoftwareForMonth(y,m) / dailySecondsForMonth(y,m)→[{day,seconds}]
dailyCardService.memoryLakeDay(usmApps,segments).usageShare → 真实分类占比 [{name,seconds,percent,isOther}]
dailyCardService.memoryLakeRecap(monthApps,monthSegments,lastMonthApps,dailySeries) → MoM/keywords/trend
projectManager.projectsForRange(range)；图标 image://appicon/<exe path> via components/AppVisual.js
保留 DesktopStatsPage 现有数据管线：Connections(usageStatManager/projectManager) + 5s Timer + refresh()。

== 饼图（用户硬要求）==
DailyUsageShare.qml 加 property real glassStrength:1.0；首页默认 1.0，统计页传 ~0.45：
把 (2)MultiEffect 外晕 blurMax 28→~12 & opacity .85→~.38、(1)(6)GlowCircle glowOpacity ×glassStrength、
(3)呼吸光环 visible: glassStrength>0.6（统计页关）、(7)中心字发光 blurMax 18→~8；扇区/中心孔/外缘/图例不动。

== 新令牌 ==
MemoryLakeStyle.changeUp = "rgba(125,255,178,.78)"（指标升幅绿）；热力/柱/折线色用 Qt.rgba(ml.<base>,alpha) 派生。

== 落地顺序（按文档 F-B / M-B 咬合，每批走收尾 ritual）==
阶段一(纯 QML)：① fullBleedPage 加 stats + DesktopStatsPage 暗玻璃重皮(MemoryLakeStyle+背景+250/1fr 壳+顶栏)
  ② 月/年真实数据(总用/环比/排行/关键词/12 月柱循环 monthly) ③ 降玻璃真实分类饼 ④ QML 派生热力/周趋势/distinct
  ⑤ 本地模板洞察/建议 ⑥ 范围 Tab/toast/ESC/返回 ⑦ 空态/昼夜/响应式(min 1280×720, ≤1200 左栏折叠)
阶段二(扩现有 C++)：G-1 week range + dailySecondsForRange → 周视图全活；switchCountForRange(切换次数)；WoW 环比
阶段三：activeSoftwareForYear(YoY)；focus 聚合(月专注天数/年专注小时)；期次任意窗口(prev/next)；exportReport

== 验收 ==
对照 C0–C12（功能 §5）。抓图用 PrintWindow-by-PID 抓**本实例**（min 1280×720 + 最大化），
品红底 3× 超采样逐像素门**只对不透明层**（玻璃/辉光层用普通截图会误判）。
实测与文档假设不符（尤其 G-1 路径、历史深度、分类口径）→ record_error + 追加 docs/stats-backend-data-gaps.md §12。
````
