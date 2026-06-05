# 20260604-0725 · Track B · Memory Lake 首页 + 月度回顾 美术复刻

## 一句话目标
把记忆湖**首页**与**月度回顾**两块从「阶段 A 排版底子」提升到「完整美术复刻」，
对齐 v88 设计稿有效最终值，严格走 Cookbook 配方与首页法规。

## Service side / UI side（track B 要求）
- **Service side**: 无变更。本会话是纯 UI 美术复刻，不触碰服务进程、磁盘契约、schema。
- **UI side**: 仅改 QML 美术层（令牌/玻璃/灯光/排版/动效）。维持现有只读数据路径
  （`usageStatManager` → `dailyCardService.memoryLakeDay/Recap`），**不引入 Mock**（G10）。
  因此本会话无 service/UI 双侧跨缝设计——属 UI-only art feature，已在此显式记录。

## 预期改动文件
MemoryLakeStyle / GlassPanel / AmbientBackground / DesktopAppShell / DesktopMemoryLakePage /
CardCarousel / RecapOverlay / RecapSlide（+ 实际新增 FrostCard）——均非 frozen。详见下「结果」。

## 不碰（明确）
- 任何 frozen 文件（CMakeLists / C 头 / schema / charter）。
- 设置/日历/统计/备忘页、Win11 外壳、MemoryCard.qml 高保真逻辑（不回退）。

## 需更新的 rule 文件
- 预计无（rules/04 UI 约定不变；纯美术不改 UI 契约）。若新增令牌命名约定再补。

## 验收
- 法规每条【必须】→ 实现位置 → 截图三联。
- 杀 TimeArc.exe → qml.exe + grabToImage 出图；边缘光/圆角/辉光走 magenta 3× 超采样逐像素门。
- night + day 双主题；有数据 + 空态。实时高斯模糊层全局 ≤3。

## 手动 smoke
启动 App → 记忆湖首页（看四角青/紫角落光、active 导航发光点、用户卡斜染、中央湖光+水位线+进度点）→
菜单底部「记忆湖」→ 月度回顾自动播放（shell 入场、极光 wave、slide 错峰、进度条、看完解锁目录）。

## 结果（DONE）

**改动文件**（均非 frozen）：MemoryLakeStyle / GlassPanel / AmbientBackground(未改，角落光改放 Shell 窗口级) /
DesktopAppShell / DesktopMemoryLakePage / CardCarousel / TodayConclusionCard / DailyUsageShare /
CalendarSyncList / RecapOverlay / RecapSlide + 新增 FrostCard（已登记 qml/CMakeLists.txt）。

**首页（法规逐条）**：
- G2/BG1-6：蓝黑深度坡 bg0–3 + 左上 aqua/右上 violet 角落辅光对（Shell 窗口级，gate fullBleedPage）；
  app 色晕染压到 ambientImageOpacity(.34)、blob 上移角落、veil→近黑薄膜。非记忆湖页不受影响。
- NAV2/3：渐变 logo（aqua→violet）+ active 发光 aqua 点（叠 2 层低透圆）；sidebar 30→28；mlNav* 收敛 mlStyle。
- L1-7/R2-4/X1-3：FrostCard（霜膜+边缘光对+斜染）用于用户卡/总览/主题/排行/时间图容器；总时数 900+负字距+tnum；
  kicker 大写正字距 eyebrow；甜甜圈分类色 aqua/violet/gold/pink/slate + 中心总时数 MultiEffect 发光(夜)；
  GlassPanel 补更亮底沿；事项/占比卡补边缘光对。
- C1-5/C8：中央列上照光 GlowCircle + 64% 水位线（限定中央列）+ 进度点胶囊（active 32px 青胶囊+外发光+内高光+横扫）+
  悬停展开 scale1.012+一次扫光 + hover-hint toast；wheel-tip 收敛 pillScrim。MemoryCard 未动（标杆）。
- X4：三缓动令牌 easeSoft/Snappy/Hero 入 MemoryLakeStyle，CardCarousel 轨道已引用。

**月度回顾（Cookbook+设计稿最终值）**：shell 边缘光对（Floating 档）；scrim/shell/stage/side 收敛 recap* 令牌，
stage/side .40(base)→**.20(v25 最终)**；极光 wave 色令牌化（aqua.08/violet.12/white.08）；glow-ring 入场已在；
slide-title **weight 760 + letter-spacing -2.2 + line-height 1.02**；pill/mode-note→pillScrim；
down 色/票根 kraft 色令牌化。recapRise 错峰 + 6 slide 变体 + 英雄缓动均已在。

**验证**：build.py ×2 干净；真机启动 home 运行期 **零新增 QML 告警**（含 easeSoft bezier 绑定、tnum、MultiEffect 发光）；
回顾覆盖层经 qml.exe + grabToImage 出图确认（入场 + 看完解锁目录两态）。夜/昼双主题各出图核验：
夜=蓝黑+青/紫四角、昼=暖坡+瓷光、发光夜开昼关。magenta 3× 超采样核验边缘光对/圆角无漏边（FrostCard/GlassPanel
原生圆角无 FBO 漏边；MemoryCard 遮罩未动）。harness_check 干净。

**有意偏离/取舍**（已记 record_error）：
- 发光文字未用 Qt5Compat.Glow（该模块不在 frozen 顶层 CMakeLists、未部署）→ 改 QtQuick.Effects.MultiEffect 等效夜开昼关。
- NAV4 记忆湖入口「首发光 + NEW」（应当）未做：需持久化「首次启动」标志，留待后续。
- 角落辐射光用 GlowCircle 近似（QML 渐变无辐射）；135° 斜染用竖直近似（卡尺度差异可忽略）。
- 实时高斯模糊层：Shell 2 角落光 + 2 app blob（静态缓存）+ 回顾 bgSrc/glow-ring；
  均为静态缓存模糊，未引入随帧刷新的重模糊，符合 ≤3 实时模糊预算精神。

## 对抗式一致性复审（多 agent workflow，23 agents / 19 raw → 9 confirmed / 10 dismissed）

复审证实 lane 几何、左栏高度公式、只读数据路径、cross-id 引用均无 bug；空 slides 优雅降级；
一位 reviewer 深读后**驳回**了 G8「模糊超预算」——所有 GlowCircle/MultiEffect 的 source 都是
静态 layer（无动画），Qt 场景图只算一次缓存，每帧真正刷新的模糊 ≤2（app 切换时 blob 450ms +
选中卡翻面时底灯），符合「模糊层不随每帧刷新」。仍据此做了**净化**：

9 条确认项已全部修复：
1. 【perf】删除 `AmbientBackground` 居中 GlowCircle（与 Shell 角落光 + 中央上照湖光重复）—— 净减一层 FBO 模糊。
2-4. 【X1】右栏英文 kicker「Daily Usage Share」「Calendar Sync」补大写+正字距；甜甜圈中心总时数补负字距 -1。
5. 【回顾】stage/side 描边 `cardBorder(.065)` → `panelBorder(.075)`（v88 .summary-stage/.side 最终值）。
6-9. 【G1】回顾 trend 折线描边色令牌化（aqua/violet/pink，并随之调暗）；封面/海报媒体暗罩 → 新增 `mediaScrim` 令牌；
     trend 卡底 → `recapStage`；票根行底 → 新增 `ticketRow` 令牌。

复审后 build.py 干净、真机 home 运行期零新增告警；回顾 trend slide 经 qml.exe + grabToImage 确认
（Canvas `addColorStop` 接受 color 令牌、折线以调暗后的三色渐变绘制，trend 卡 .20 inset 读感正确）。

## 用户反馈修复（三项，均 qml.exe 出图核验）

1. **「扫光范围比卡片大很多」**：根因是悬停时的 `cardLakeExpandScan` 横扫整条中央列（≫卡片），
   读作莫名其妙的大扫光。**移除该扫光**（悬停反馈保留整块 scale 1.012 + 顶部 hover-hint toast）；
   并把中央「上照湖光」从 laneWidth*0.95 收敛到 *0.72（卡尺度），不再横跨整列。
2. **「发光质感不好 / 一层一层（banding）」**：根因是 `GlowCircle` 用「实心圆 + MultiEffect 高斯模糊」——
   中心是平的实心盘、只有边缘模糊（读作带毛边的硬盘），大半径模糊还出现一圈圈 banding。
   **重写 `GlowCircle` 为 Canvas 径向渐变**（中心最亮→边缘透明，平滑无 banding、尺寸精确、纹理缓存、
   无 FBO、无新模块依赖）。受益：角落 aqua/violet 辅光对、中央湖光、回顾 glow-ring 全部变平滑柔光；
   径向比平盘淡得快，角落/glow-ring 不透明度相应上调（aqua .16→.22 / violet .135→.18 / ring .18→.26）。
   出图确认：单 GlowCircle = 平滑柔光球；四角 = 柔和青/紫；湖光 = 卡尺度柔光。
   （MemoryCard 选中底灯仍用其自带 MultiEffect：翻面逐帧动画走 GPU 模糊比逐帧重绘 Canvas 更稳，属 showpiece 不回退。）
3. **「几乎每个界面底下有一条超界线条」**：根因是边缘光对的 1px 直线 `anchors.margins:1` 满宽铺到圆角拐角，
   直线段戳出圆角外成「超界线条」。**所有边缘光对（GlassPanel / FrostCard / DailyUsageShare / CalendarSyncList /
   TodayConclusionCard / RecapOverlay shell）左右内缩 = 圆角半径**，只覆盖直边段，拐角干净。出图确认两卡底沿不再越界。

修后 build.py 干净；真机 home 运行期零新增 QML 告警（含 Canvas GlowCircle）。
