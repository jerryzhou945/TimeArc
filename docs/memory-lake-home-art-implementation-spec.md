# Memory Lake 首页 · 美术复刻实施规范（法规）

> 本规范定义 **首页（记忆湖）在 QML 中达到「对 v88 设计稿完整美术复刻」** 的强制目标与验收口径。
> **技术怎么做，一律不在此重复**——全部指向技术底座 `docs/memory-lake-art-lighting-qml-cookbook.md`（下称 **Cookbook**）。
> 本规范只规定「**必须做到什么 + 怎么验收**」。

---

## 0. 目的 · 范围 · 规范性

**目的**
把首页从当前「阶段 A（三栏静态排版 + 灯光底子 + 主题）」提升到「**阶段 B：完整美术复刻**」，
使其在科技感、光照、质感三轴上与 `MemoryLakeDesign/TimeArcDesign_v88.html` 的 `#memoryWindow` 内部对齐。

**范围（首页视图 = 三个文件协同渲染）**

| 区域 | 承载文件 | 本规范章节 |
|---|---|---|
| 氛围背景层 | `qml/desktop/DesktopAppShell.qml`（背景 Item） | §2.1 |
| 左导航轨 | `qml/desktop/DesktopAppShell.qml`（sidebar） | §2.2 |
| 左内容栏 | `qml/desktop/pages/DesktopMemoryLakePage.qml` | §2.3 |
| 中央卡牌湖 | `qml/desktop/memorylake/CardCarousel.qml` + `MemoryCard.qml` | §2.4 |
| 右数据栏 | `qml/desktop/pages/DesktopMemoryLakePage.qml` | §2.5 |
| 跨区（排版/动效/玻璃） | 全部 | §2.6 |

**明确不含（豁免，见 §5）**：设置 / 日历 / 统计 / 备忘 / 月度回顾（已独立成页）；Win11 测试外壳（`.desktop/.taskbar`）；
设计稿窗口内的 `.titlebar` mica（真实 App 用原生窗口框，非内容美术）。

**技术底座（"技术栈"）**
本规范全部技法引用 Cookbook。条款里 `→ §x.y` 即指 Cookbook 对应章节。Cookbook 里没有的新做法，本规范不引入。

**规范性关键词**
- **【必须】** = 验收硬条件，不达标即本规范不通过。
- **【应当】** = 强烈建议，偏离须在 PR 说明理由。
- **【可选】** = 锦上添花，不影响验收。

**基准值约定**
所有 CSS 基准 = 设计稿**有效最终值**（已穿过 `!important` / V-block 覆盖层），与 Cookbook 一致。**禁止照搬 base 行的高饱和原值**（→ §1 把霓虹调暗）。

**现状基线（写入本规范时的事实，供差距核对）**
- `DesktopMemoryLakePage.qml` 自述「阶段 A」；左栏内联卡片硬编码 `radius 19/22`、内联 `Gradient`，**未收敛到令牌**。
- `CardCarousel.qml` 的 `zone` 为 `color:"transparent"; border.width:0`，**已移除 `.cards-zone` 湖框与中线**（注释：全幅化后中线横贯整屏割裂画面）。无进度点、无悬停展开、无 hover-hint。
- `DesktopAppShell.qml` 夜晚底色是**紫灰**渐变（`#2D3148→#3B4160`、`#4E5578…`），**非**蓝黑深度坡；ML 氛围 = 当前 APP `appColor` 的 A/B 交叉淡入 + 两团模糊圆 + 水面压色，**无 aqua/violet 角落辅光对**。
- 导航轨 `sidebar` `radius 30`、项 `radius 18`（SVG 图标 + 标题 + 副标题），选中 = 填色 + 边框，**无发光 active 点**；logo 为实心 accent「T」**非** aqua→violet 渐变；**无**记忆湖首发光/NEW 徽标。
- 右栏 `homeRight`(CalendarSyncList+DailyUsageShare) / `lockedRight`(TimeRiver) + `rightSectionSwap` 弹性入场 **已较好复刻**。
- `MemoryCard.qml`（翻面 + 底灯守恒 + 圆角遮罩）**已高保真**，作为标杆。

---

## 1. 总纲条款（全局，适用所有区域）

- **G1 令牌单一事实源【必须】** 所有颜色 / 圆角 / 阴影 / 强调值取自 `MemoryLakeStyle`（按需先补全 token，→ §2）。
  **禁止散落硬编码 hex / rgba / radius**。现状 `DesktopMemoryLakePage` 的 `radius 19/22`、内联 `Gradient{aqua→violet}`、
  `Qt.rgba(1,1,1,0.32)` 等**必须收敛**到 `ml.*`。
- **G2 蓝黑深度坡【必须】** 首页底色调是蓝黑深度坡 `#05070D → #090D16 → #0D1320 → #121A2A`（→ §2 / §4.1），
  **不是**当前紫灰。这是当前最大的美术偏差，**优先级最高**。
- **G3 三色分工 + 把霓虹调暗【必须】** aqua 主导（时间语义）、violet 次要、pink 仅渐变/分组/饼图；发光用最终低 alpha 值，
  静止克制、交互才醒（→ §1）。
- **G4 边缘光对【必须】** 每个抬升面 = 顶沿 1px 内高光 + **更亮底沿 border**（`--ml-border-strong`），两条 1px Rectangle 实现（→ §3.5）。
- **G5 圆角坡 + 同心嵌套【必须】** 统一 `lg28 / md22 / sm16`，控件 8–14，胶囊/点 999；**内层圆角 < 父层**（→ §5.7）。
- **G6 排版规范【必须】** 重字重坡（`760` 半粗 / `900` 英雄数字）、大数字负字距、时长/计数 `tabular-nums`、kicker 大写正字距（→ §5.5）。
- **G7 动效缓动令牌化【必须】** 仅三条曲线：柔落 `[0.2,0.8,0.2,1,1,1]`、弹入 `[0.18,0.9,0.2,1,1,1]`、英雄 `[0.16,0.9,0.2,1,1,1]`；
  过冲用关键帧中间值而非曲线（→ §6.1）。
- **G8 性能预算【必须】** 实时高斯模糊层全局 ≤ 3；`layer.enabled`(FBO) 仅给会翻面的选中卡 + 必须圆角裁切的容器；
  小辉光叠 2 层低透圆，不挂 MultiEffect（→ §8）。
- **G9 双主题对等【必须】** `night/day` 全量走一遍：阴影黑↔蓝灰、accent aqua↔teal、`text-shadow→none`、`glowStrength`（→ §2）。
- **G10 真实数据 / 空态【必须】** 维持现有只读数据路径（`usageStatManager` → `dailyCardService.memoryLakeDay`），
  **不得**为了好看引入 Mock；空态保持现有保守提示（不显假卡）。

---

## 2. 区域规范

### 2.1 氛围背景层（`DesktopAppShell.qml` 背景 Item）

**目标**：把首页底子从「紫灰图叠色」换成 Cookbook §3.2 的四层环境光叠层，建立蓝黑+双角辅光的「记忆湖」光场。

| # | 条款 | 基准 / Cookbook |
|---|---|---|
| BG1【必须】 | 夜晚底色改为蓝黑深度坡竖直渐变 `#05070D → #0D1320 → #121A2A`，替换当前 `#2D3148/#3B4160/#4E5578` 紫灰 | §3.2 层①③ / §4.1 |
| BG2【必须】 | 新增**角落辅光对**：左上 aqua `rgba(159,231,238,.065)→t 28%`、右上 violet `rgba(155,139,255,.055)→t 30%`；用 `GlowCircle`，圆心落在窗角外只透 1/4 | §3.3 路 A |
| BG3【应当】 | 保留「当前 APP 色彩晕染」作为层②（app-bg 等价），但 alpha 压到 `ambientImageOpacity`(夜.34/昼.22) 量级，**不得**盖过蓝黑底；现有 A/B 交叉淡入 450ms 保留 | §3.2 层② |
| BG4【应当】 | 现有两团模糊 blob 重定位为「角落辅光」的色彩注入（左上偏 aqua、右上偏 violet），而非当前对角 0.2/0.8 摆放 | §3.3 / §3.6 |
| BG5【必须】 | 顶层薄霜veil（统一压暗/磨光）保留，但用近黑薄膜 `rgba(2,4,8,.12)` 量级，不得把色调压灰 | §3.2 层④ |
| BG6【必须】 | 实时背景模糊不可得，沿用叠色近似；模糊 blob 计入 §8 的 ≤3 预算 | §3.8 / §8 |

**验收**：夜晚首页主视觉应读作**深蓝黑水面 + 左上青、右上紫两点冷光**，而非紫灰雾。截图取四角，左上像素应偏 aqua、右上偏 violet。

### 2.2 左导航轨（`DesktopAppShell.qml` sidebar）

**目标**：对齐设计稿 `.timearc-nav` 的「玻璃轨 + active 三重信号 + 渐变 logo + 记忆湖首发光」。

| # | 条款 | 基准 / Cookbook |
|---|---|---|
| NAV1【必须】 | 导航项圆角收敛到 `ml.radiusInner`(16) 量级（现 18 可保留），sidebar 外框 `radius 30→` 对齐容器坡（24–28） | §5.7 / G5 |
| NAV2【必须】 | **active 三重信号**：aqua 染底 `accentSoft(.075–.13)` + aqua 边 `accentSoftBorder(.17–.22)` + **右侧 5px 发光 aqua 点**（叠 2 层低透圆做 `0 0 14px aqua .65` 辉光） | §5.6「active 三重信号」/ §3.6 |
| NAV3【必须】 | Logo 方块 `radius 14` 填 **aqua→violet 145° 渐变**（替换当前实心 `appAccentWarm`），中心暗墨「T」weight 900 | §5.6「品牌渐变方块」/ 配方 #4 |
| NAV4【应当】 | 「记忆湖 / Memory Recap」底部入口支持**首发光**：aqua 环 + 光晕呼吸 1.8s + NEW 徽标，点击后一次性熄灭（gate 在「首次启动」标志后） | §3.6 / §6.4 |
| NAV5【应当】 | 功能图标【可选】从 SVG 维持即可；若改 Unicode 字形须保证清晰度（建议仍用矢量 SVG） | §5.6 |
| NAV6【必须】 | 选中/悬停/默认三态颜色全部取自 `ml`（夜 `mlNav*` 已是此意，需补 active 发光点的 token） | G1 / G9 |

**验收**：选中项必带一枚会发光的 aqua 圆点；logo 是青→紫渐变而非单色；首次进入时记忆湖入口有呼吸光 + NEW。

### 2.3 左内容栏（`DesktopMemoryLakePage.qml` 左 `GlassPanel`）

**目标**：把内联卡片升级为 Cookbook §5.1 的 tier-2 霜膜卡 + accent 斜染 + 边缘光对，并令牌化。

| # | 条款 | 基准 / Cookbook |
|---|---|---|
| L1【必须】 | 全部内联 `radius 19/22` → `ml.radiusCard`(18)/`ml.radiusInner`(16)，**内 < 外**；删除内联 hex/rgba | G1 / G5 |
| L2【必须】 | 用户卡（`.profile` 等价）叠 **135° aqua→violet 斜染** `linear(135°, aqua .08, violet .045)` 于 `cardBg` 之上；头像方块加**顶沿内高光** `inset 0 1px 白 .2`（一条 1px Rectangle） | 配方 #3 / §3.5 |
| L3【必须】 | 「使用总览」卡（`.overview` 等价）叠 **顶向下 aqua 染** `linear(180°, aqua .08, 白 .025)`；总时数大字 weight 900 + 负字距 + `tabular-nums` | 配方 #3 / §5.5 / G6 |
| L4【必须】 | 「今日主题」「使用总览」「用户卡」「排行容器」四个 tier-2 卡统一加**边缘光对**（顶沿 .035 + 更亮底沿）；静止**无投影**（嵌入读感） | §3.4 Resting / §3.5 |
| L5【必须】 | kicker（"使用总览"/"今日主题"）改为**大写 + 正字距** eyebrow，色 `aqua` 或 `textTertiary` | §5.5「eyebrow」 |
| L6【应当】 | `UsageRankList` 行内进度条用 **90° aqua→violet** 填充于 `trackBg`（配方 #5，原生线性即可）；hover 行联动卡牌预览（现已连 `onHoverCard`，保留） | 配方 #5 / §4.2 |
| L7【应当】 | `TodayConclusionCard` 沿用，但其内部卡片同样遵 L1/L4 | §5.1 |

**验收**：用户卡有可见的青→紫斜向冷光膜；总时数为重磅等宽数字；四张卡有「顶亮底更亮」的玻璃下唇，且嵌在左栏里不漂浮。

### 2.4 中央卡牌湖（`CardCarousel.qml` + `MemoryCard.qml`）

**目标**：在保留「暗水面铺满全 App」架构的前提下，**把设计稿 `.cards-zone` 的光线索作为居中 overlay 恢复**，并补齐进度点/悬停展开。`MemoryCard` 维持标杆，不回退。

> **架构裁决**：现状刻意把湖框去掉、改全幅背景（合理，"暗色水面铺满整窗"）。但设计稿的「湖」气质来自**居中的光**，不是边框。
> 因此**不恢复整框、也不恢复全宽中线**（全宽会割裂画面，现状注释已证实），而是把光线索**限定在中央列区域**（左 300 与右 310 面板之间）。

| # | 条款 | 基准 / Cookbook |
|---|---|---|
| C1【必须】 | 中央列区域新增**下中上照光**：`radial 50% 68% aqua .055 → t 34%`（`GlowCircle` 置于中央列底部，**不得**外溢到左右面板背后） | §4.4 / §3.3 |
| C2【必须】 | **水位线**：一条 aqua 渐变 1px 线 `linear(90°, t, aqua .12, t)` 置于约 64% 高度，**宽度限定在中央列**（左右各内缩，避免横贯整屏） | §4.4 |
| C3【必须】 | 恢复**底部进度点胶囊**（`cardProgressPill`）：N 个点对应 N 张卡，active 点morph成 32px 青色胶囊 + 外发光 + 内高光 + 横扫高光 1.4s | §6 卡堆「progress-dot」/ §3.6 |
| C4【应当】 | **悬停展开湖**：指针进入卡区时中央列轻微 `scale 1.012` + 一道 aqua 横扫 shimmer（`cardLakeExpandScan`，translateX 一次），离开复位；gate 在 §8 预算内 | §6.2 / §6.4 |
| C5【应当】 | **hover-hint toast**：展开时顶部居中淡入一枚带发光 aqua 点的 frosted 胶囊提示；现 `wheel-tip` 保留为左上滚轮提示，二者不冲突 | 卡堆「card-hover-hint」 |
| C6【必须】 | `MemoryCard` 维持现有高保真（Flipable + 底灯 `|cosθ|` 收束 + aqua→violet 折射 + 圆角遮罩 `maskThresholdMin .5`），**不得**为重构而回退 | §6.6 / §5.7 |
| C7【必须】 | 轨道居中滑动维持 `Behavior on x` 柔落 `[0.2,0.8,0.2,1,1,1]`（现已是）；非选中卡景深 `opacity .42 / scale .88`（现已是） | §6.2 / §4.4 |
| C8【必须】 | 锁定（翻面）态提示色用 `ml.lock*`（现已是）；wheel-tip 的 `Qt.rgba(0,0,0,…)` 内联值收敛到 token | G1 |

**验收**：静止时中央能读出「从下方升起的青色湖光 + 一条横向水位线」，底部有可点的进度点胶囊（active 为发光青胶囊）；
悬停卡区有一次青色扫光；翻面卡的底灯随转动收束变紫。

### 2.5 右数据栏（`DesktopMemoryLakePage.qml` 右 `GlassPanel`）

**目标**：保持已较好的 `rightSectionSwap` 结构，仅补质感/排版一致性。

| # | 条款 | 基准 / Cookbook |
|---|---|---|
| R1【必须】 | `homeRight`(事项+占比) / `lockedRight`(时间图) 切换的弹性入场维持现状（升-过冲 1.008-落定），确认缓动用 `[0.18,0.9,0.2,1,1,1]`（现已是） | §6.1 / §6.2 |
| R2【必须】 | `DailyUsageShare` 甜甜圈维持 Canvas `destination-out` 挖心（现已是）；扇区色用分类色 aqua/violet/gold/pink/slate；中心总时数加 aqua `Glow` + `tabular-nums` | §4.3 / §3.7 |
| R3【必须】 | `TimeRiver` 时间轴维持 3 停 transparent→aqua→transparent 线性渐变（现已是）；节点辉光维持叠 2 层低透圆（现已是）；颜色令牌化 | §3.6 / §4.2 |
| R4【必须】 | 右栏内层卡（事项/占比/时间图容器）同样遵 L1/L4（圆角 18 + 边缘光对 + 无投影嵌入） | §3.4 / §3.5 |
| R5【应当】 | `lockedRight` 出现时给时间图一道 aqua 聚焦扫光（`timeTreeFocusScan`，一次） | §6.6 |

**验收**：切卡/翻面时右栏「升起-轻过冲-落定」；甜甜圈中心数字发青光且等宽；右栏卡与左栏卡质感一致。

### 2.6 跨区规范（排版 / 玻璃 / 动效一致性）

| # | 条款 | Cookbook |
|---|---|---|
| X1【必须】 | 全首页排版按 G6：所有"大数字"(总时数/计数) weight 900 + 负字距 + `tabular-nums`；所有 kicker 大写 + 正字距；正文 weight 760/Medium | §5.5 |
| X2【必须】 | 全首页玻璃面材质统一：tier-1 大框（左右 `GlassPanel`）= 半透 + 边缘光对 + 抬升投影；tier-2 内卡 = 霜膜 + 边缘光对 + 无投影 | §5.1 / §3.4 |
| X3【必须】 | `GlassPanel` 补**更亮底沿** border（现仅顶沿高光），即 §3.5 的第二条 1px Rectangle | §3.5 |
| X4【应当】 | 把三条缓动曲线沉淀为 `MemoryLakeStyle`（或一个 `MotionTokens`）只读属性，全首页引用，杜绝散落 bezier 数组 | §6.1 / G7 |
| X5【必须】 | 发光文字（甜甜圈中心、active 数字）用 `Qt5Compat.GraphicalEffects` `Glow`，**夜晚开 / 白天关**（G9） | §3.7 |

---

## 3. 验收（Conformance）

**3.1 逐条 checklist**
本规范每一条【必须】= 一个验收点。PR 须附「条款 → 实现位置（文件:行）→ 截图」三联表，所有【必须】项勾选方可合入。

**3.2 截图门（沿用项目既有方法，见 MEMORY「TimeArc UI build/verify」）**
- 构建前【必须】先杀 `TimeArc.exe`（exe 锁）。
- 用 `qml.exe + grabToImage` 快循环出图。
- 边缘光 / 圆角漏边 / 辉光强度【必须】用 **magenta 背景 3× 超采样 + 逐像素门** 核验（普通截图会假阳性）。
- 关键对照图：① 夜晚四角色相（BG2）；② active 导航发光点（NAV2）；③ 用户卡斜染（L2）；④ 中央湖光+水位线+进度点（C1–C3）；
  ⑤ 翻面底灯变紫（C6）；⑥ 甜甜圈中心发光等宽数字（R2）。

**3.3 数据 / 主题 / 空态【必须】**
- 真实只读数据路径不变（G10）；有数据 / 空态两版都出图。
- `night` 与 `day` 两主题都验收（G9）：白天阴影蓝灰、accent teal、无 text-shadow。

**3.4 性能【必须】**
- 实时高斯模糊层 ≤ 3（G8）；用帧率/GPU 占用粗验，悬停展开扫光不得掉帧。

---

## 4. 实施顺序（建议 batch，每步可独立验收）

1. **令牌补全**（G1/G2）：`MemoryLakeStyle` 补深度坡 `bg0–3` + 阴影 token + active 发光点 token + 三缓动（X4）。→ Cookbook §2
2. **背景换底**（§2.1）：蓝黑深度坡 + 角落 aqua/violet 辅光对。**先做，收益最大**。
3. **导航轨**（§2.2）：渐变 logo + active 发光点（+ 记忆湖首发光）。
4. **内层卡质感**（§2.3 + §2.5 + X2/X3）：tier-2 霜膜 + accent 斜染 + 边缘光对 + 令牌化，左右栏一起过。
5. **中央湖光线索**（§2.4 C1–C5）：上照光 + 水位线 + 进度点 + 悬停展开（限定中央列）。
6. **排版统一**（X1）：重字重 + 负字距 + tabular-nums + 大写 eyebrow。
7. **双主题回归**（G9）：white/day 全量复核。

---

## 5. 明确豁免（不复刻 / 已知妥协）

- **实时 backdrop 模糊**：QML 无逐元素 backdrop-filter，沿用叠色近似（`panelBg` α≈0.94）。详见 `memory-lake-fidelity-gaps.md` 🔴1。
- **同时多重 + inset 阴影**：`MultiEffect` 单外阴影、无 inset；多层光晕用叠圆拼。🔴3。
- **mix-blend-mode: screen**：首页基本不涉及（极光/电路在回顾/番茄钟），如需用近黑底低透亮层近似。🔴2 / Cookbook §5.4。
- **Win11 测试外壳 / 设计稿内 `.titlebar` mica**：不复刻（真实 App 用原生窗口框）。
- **月度回顾 deck**：已独立为 `DesktopMonthlyRecapPage`，不在首页范围。

---

## 6. 与其它文档的关系

- **技术怎么做** → `docs/memory-lake-art-lighting-qml-cookbook.md`（本规范的技术栈底座，逐条 `→ §x.y` 引用）。
- **能复刻到几分 / 哪些做不到** → `docs/memory-lake-fidelity-gaps.md`（🔴🟡🟢 差距与妥协）。
- **本规范** = 首页这一具体目标的**规范性验收口径**（必须做到什么）。三者：差距表定边界，Cookbook 给方法，本法规定目标。

---

*本规范聚焦"首页必须达到的美术标准与验收"；落地任一条款时，先翻 Cookbook 对应章节取配方，再对 `memory-lake-fidelity-gaps.md` 确认天花板。*
