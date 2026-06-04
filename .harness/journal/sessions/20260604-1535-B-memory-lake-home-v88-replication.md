# 20260604-1535 · Track B · 记忆湖首页 v88 美术复刻（排版 + 光照 + 板块背景）

## 一句话目标
按 `MemoryLakeDesign/TimeArcDesign_v88.html` 首页**完整复刻**：今日结论移回中栏（卡片只占下半），
并补齐用户点名的「光照模糊玻璃」质感——今日事项**笔记本方格 + 蓝色霓虹**、今日软件使用占比**立体霓虹甜甜圈**。

## Service / UI 双侧
- **Service side**: 无变更。纯 UI 美术 + 布局复刻，不碰服务进程 / 磁盘契约 / schema。
- **UI side**: 仅改 QML 美术层 + 中栏布局。维持只读数据路径（usageStatManager → dailyCardService.memoryLakeDay），
  **不引入 Mock**（G10）；占比洞察文案由真实最高占比切片派生（事实标签，非造假）。

## 研究（workflow wxre1voau，4 agents/Explore）
精确抽取 v88 有效最终值：①中栏 `.main-panel`（grid auto+minmax(0,1fr)；briefing max-h240 折叠态；
cards-zone 1fr）②`.today-items-compact::before`（radial 88%20% glowCyan.10 + 24px 方格，opacity.45）
③`.daily-pie-chart`（conic 5 段 + box-shadow 0 0 32px aqua.12 霓虹 + 雕刻中心孔 + 呼吸 .daily-pie-ring）
④`.time-tree`（轴/节点/涟漪，仅翻面态可见，本轮未改）。

## 改动文件（均非 frozen）
- **新增** `GridTexture.qml`（复用「笔记本方格」Canvas 静态纹理；已登记 qml/CMakeLists.txt + README）。
- `MemoryLakeStyle.qml`：+令牌 glowCyan/#8EDFFF、nodeCyan、cardsZoneBg、gridLine、donutHoleTop/Bottom（G1 单源）。
- `TodayConclusionCard.qml`：重做为 v88 `.today-briefing` 宽卡（双角径向辉光 + 28px 方格 + score 盒 + chips）。
- `CalendarSyncList.qml`：玻璃底 + 左上 aqua/右上**蓝色霓虹**径向 + 24px 方格 + 霓虹点 + v88 圆角行（渐变勾选框）。
- `DailyUsageShare.qml`：真实占比 Canvas 扇区 + MultiEffect 彩色霓虹外晕 + 呼吸光环 + 雕刻暗孔 + 霓虹图例点 + 洞察胶囊。
- `DesktopMemoryLakePage.qml`：中栏 = briefing（上，翻面折叠）+ cardsZone 暗箱（下，翻面上移填满）；
  左栏移除今日结论→排行扩容；右栏占比卡高度 226→298。
- `CardCarousel.qml`：lane 由「避让左右面板的 308/width-318」改为整卡区 0/width；wheel-tip 移回卡区左上角。

## 布局关键（设计稿一致）
中栏 .main-panel 两行：briefing(auto≤240) + cards(1fr)。卡片 460 固定、垂直居中；翻面 616 高卡靠
briefing 折叠腾出的整高容纳（与 v88 `.cards-hovering/.force-card-expanded` 折叠同义）。

## 验收（qml.exe + grabToImage，夜/昼双态）
- 夜：briefing 暗玻璃 + score 盒 + chips；今日事项**方格 + 蓝霓虹**清晰、渐变勾选框 + ✓；
  甜甜圈**彩色霓虹外晕 + 呼吸环 + 暗孔 + 霓虹图例点 + 洞察**——立体霓虹达成。
- 昼：三板块浅玻璃可读、霓虹按 glowStrength .45 收敛、甜甜圈外晕夜开昼关（gs>0.6 gate）。G9 双主题通过。
- 真机 TimeArc.exe（Qt bin 入 PATH）存活 5s+ 加载首页，**零 WARNING/CRITICAL**（harness-qt.log 未生成 = 零告警）。
- build.py ×2 干净；harness_check 干净（GridTexture 新文件已补 README，track 纪律过）。

## 有意取舍
- 右栏构成沿用上轮 flip-driven（不翻面=今日事项+占比；翻面=时间图），未改 v88「三块常驻+重排」结构（避免回退既有交付）。
- 今日事项时间列不杜撰：savedTodos 仅 text/done，按真实字段渲染（行=勾选框+文本），不补假时间。
- 甜甜圈外晕用 MultiEffect 模糊真实扇区（非硬编码 conic），保 G10 真实占比；夜开昼弱守 §8 模糊预算。
- 卡牌轮盘/MemoryCard 翻面逻辑标杆未动（不回退）。

## 二轮修复（用户反馈：毛玻璃 / 角落色块 / 中栏包裹板 / 阴影）
- **中栏包裹板**：中栏改用 GlassPanel 包裹（与左右栏同款），内含今日结论 + 卡区暗箱（设计稿三栏皆有大板块）。
- **去硬阴影**：GlassPanel 默认 `dropShadow:false`（删掉底部偏移暗带）+ 补磨砂顶沿柔光；Shell 侧栏（menubar）阴影 fullBleed 时关。
- **毛玻璃**：今日结论改极淡白霜膜 + 顶沿柔光（均匀磨砂），不再暗块平涂。
- **角落色块（两次反馈）**：根因 `clip:true` 只裁矩形包围盒，方格/辉光在圆角处戳出方角（[[timearc-ui-build-verify]] 已记 RoundedFrame）。
  三卡的方格/底光统一裹进 **RoundedFrame** round-clip；今日结论/占比**撤掉四角径向光斑**，今日事项改一团**居中均匀蓝霓虹**+小霓虹点。
- **昼态对比**：今日事项行字 / 占比图例字改用 textPrimary/Secondary 令牌（原硬编码近白字在浅底不可读）。
- 复验：build 干净、真机零告警、夜/昼双态四角干净无突出色块。
