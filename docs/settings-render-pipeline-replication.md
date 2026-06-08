# 设置页 · 渲染管线复刻规范（美术 / 光照 / 纹理 / 玻璃 / 控件配方）

> 配套文档：`docs/settings-functional-replication.md`（同页功能/行为/状态法规）、
> `docs/settings-implementation-issues.md`（技术难点 / 后端缺口 / 待决策 = 本页问题文档）。
> 设计稿真值：`MemoryLakeDesign/TimeArcDesign_v88.html`
> ——设置页 DOM `13897–14165`、CSS（暗）`8194–8830`（+ 共享类：`prototype-status` `11608–11621`、
> `workflow-map/step` `11689–11716`、`theme-mode-control/theme-switch/theme-chip` `12313–12418`）、
> 设置页 JS `17824–18008`、白天模式 JS `18678–18740`、light 覆盖块 `12420–13500`、
> 导航「设置」项已存在于 `DesktopAppShell.qml:135`。
> 重构目标：现「设置」路由当前指向 `qml/desktop/pages/DesktopProfilePage.qml`
> （奶油浅色简版，仅外观/语言/资料/概览/数据位置 5 段）——本次将其**重皮+扩建**为
> 全幅暗玻璃 5 标签页（或新建 `DesktopSettingsPage.qml` 并改 `:171` 路由，见功能文 §1）。
> 令牌单一事实源：`qml/desktop/memorylake/MemoryLakeStyle.qml`（夜=设计稿 1:1，昼=派生浅瓷）。
> Track：**B（新能力 / 重皮）**。体例沿用统计/日历法规：
> **必须 (MUST) / 应当 (SHOULD) / 可选 (MAY)**，违反「必须」即不合格。

---

## §0 概览：设置页的视觉是什么 + 已定决策

设置页是一个**全幅暗玻璃覆盖页**，与记忆湖/日历/统计/回顾同列。整页结构 =
**左导航面板（238px）** + **右主区（1fr）**：

- 左面板：品牌标题块（kicker「Control Center」+ 标题「设置」+ 说明 + 原型数据提示条）→
  5 个标签按钮（通用 / 追踪与应用 / 隐私与数据 / 备忘与番茄钟 / 导入导出）→
  底部页脚（4 步工作流图「首页/日历/统计/回顾」 + 本地数据同步点）。
- 右主区：顶栏（动态标题 + 动态描述 + 搜索框 + 返回按钮）→ 可滚动区，内含 5 个
  分区（section），每个分区是一个 2 列卡片网格（`settings-grid`），卡片含磨砂玻璃底 +
  图标徽章 + 设置行（开关 / 下拉 / 输入框 / 滑块 / 强调色点 / 指标条 / 按钮 / 快捷键格）。

v88 原型的设置 JS（`17824–18008`）**几乎全是前端态**：开关只 toggle class + 弹 toast，
强调色只改 CSS 变量，磨砂滑块只改 `backdrop-filter`，导入导出读写 `localStorage`。所以本次
复刻 = **把视觉 1:1 搬到 QML 暗玻璃** + **把能落地的设置接到真实后端**（`SettingsRepository`
UI 私有 KV / 各 manager），接不了的登记到问题文档。

### 已定决策（美术侧，D-* 与功能文共享编号空间）

- **D-FULLBLEED**：设置页走全幅暗玻璃，与日历/统计同列。在 `DesktopAppShell.qml:61–62`
  的 `fullBleedPage` 加入 `"settings"`；在 `:296` 的栅格纹 `visible` 加入
  `selectedPage === "settings"`（让 42px 蓝图格纹也铺到设置页）。**不**新增路由：
  `navItems` 已含「设置 / Settings」项（`:135`），`currentPageSource` 已映射（`:171`）。
- **D-REUSE-BG**：整页背景三件套（蓝黑深度坡竖渐变 + 左上 aqua / 右上 violet 角辉
  `GlowCircle` + 42px `GridTexture` 羽化遮罩）**由 Shell 统一绘制**（已存在），设置页本体
  **不**重绘背景——与统计/日历页同范式（Shell 关外框/玻璃，页只画内容）。
- **D-REUSE-GLASS**：所有玻璃面板/卡片复用 `GlassPanel.qml`（panelBg + 顶沿内高光 +
  底沿强边）；角辉复用 `GlowCircle.qml`；格纹复用 `GridTexture.qml`；需要真圆角裁切
  渐变/图标的复用 `RoundedFrame.qml`。**杜绝**散落 hex/rgba，一律取 `MemoryLakeStyle` 令牌。
- **D-REUSE-CAL-TOKENS**：设置页 CSS 与日历页**高度同源**（`rgba(255,255,255,.045)` 玻璃面、
  `rgba(0,0,0,.16)` 下沉输入、`rgba(142,223,255,.12)` aqua 描边、ghost 按钮、toast）。
  故**直接复用** `MemoryLakeStyle` 既有日历令牌（`calPanelBg` / `calSunkBg` / `calInputBorder` /
  `calGhostBg/Hover/Border` / `calGlyph` / `calToastBg` / `calBtnInk` / `calDangerWash` /
  `calPageTop/Bottom`），**不新增**重复令牌（见 §9 映射表）。仅设置页独有的少量量值
  （如 `theme-switch` 66×34、`switch` 48×28、accent 渐变）按 §7 配方落地。
- **D-THEME=NIGHTMODE**：v88 的「暗玻璃 ⟺ 白天浅瓷」二态，**映射到** TimeArc 既有
  `nightMode`（驱动 `MemoryLakeStyle.night`）。通用页「白天模式色调」开关 = `!nightMode`，
  勾选即 `nightModeToggled(false)`。设置页本体在两态下都正确渲染（夜=暗霓虹、昼=浅瓷），
  对齐 v88 `.settings-page` 与 `body.light-mode .settings-page`（见 §8）。沿用现
  `DesktopProfilePage` 已实装的 `nightModeToggled` 契约（Shell `:822–830` 已连）。
- **D-NO-BACKDROP-BLUR**：QML 无 CSS 实时背景模糊（见 `docs/memory-lake-fidelity-gaps.md` 🔴1），
  玻璃质感用叠色近似。故 v88「背景磨砂强度」滑块**无真实背景模糊可调**——其渲染落地为
  调玻璃叠色不透明度的近似量（或登记为装饰性无效，见问题文档 §G 与 §8.3）。

---

## §1 设计稿真值索引（行号锚点）

| 区块 | DOM | CSS（暗） | light 覆盖 | JS |
|---|---|---|---|---|
| 整页 `.settings-page` | 13897 | 8196–8236 | 12437/12462/12767 | open/close 17851–17885 |
| 壳 `.settings-shell` | 13898 | 8238–8247 | — | — |
| 左面板 `.settings-nav-panel` | 13899 | 8249–8260 | 12484/12794 | — |
| 标题块/kicker | 13900 | 8262–8292 | 12860 | — |
| 原型提示 `.prototype-status` | 13904 | 11608–11621 | 13022/13463 | 15474 |
| 标签 `.settings-tab` | 13911 | 8294–8341 | 12907/12933/12947 | tab 切换 17887–17899 |
| 页脚/工作流图/同步点 | 13918 | 8343–8367 + 11689–11716 | 12613/13027 | — |
| 顶栏 `.settings-topbar` | 13931 | 8376–8429 | 12795 | 标题/描述 17835–17841 |
| 搜索框 `.settings-search` | 13936 | 8401–8414 | 12954/12587 | 搜索 17927–17934 |
| 分区/入场 `.settings-section` | 13941 | 8437–8449 | — | — |
| 卡网格/卡片 | 13942 | 8451–8513 | 12483/12552 | — |
| 设置行/标签 `.setting-row` | 13967 | 8515–8542 | 12889 | — |
| 开关 `.switch` | 13969 | 8544–8575 | — | 17901–17906 |
| 下拉/输入 `.setting-select/input` | 13984 | 8577–8592 | 12952 | — |
| 强调色 `.accent-dot` | 13949 | 8594–8620 | — | 17908–17916 |
| 主题开关 `.theme-switch` + chip | 13964 | 12372–12418 | 13010–13021 | 18678–18740 |
| 磨砂滑块 `.range-control` | 13973 | 8589–8592 | — | 17918–17925 |
| 指标条 `.metric-strip/.settings-metric` | 14066 | 8622–8648 | — | — |
| 应用清单 `.app-manage-*` | 14030 | 8650–8689 | — | — |
| 按钮 `.settings-btn` 主/危 | 14070 | 8691–8726 | — | 导出/导入/复制/重置 17936–18002 |
| 快捷键 `.shortcut-*/.kbd` | 14111 | 8728–8763 | — | — |
| 存储条 `.storage-bar` | 14065 | 8765–8780 | — | — |
| toast `.settings-toast` | 14164 | 8782–8806 | — | 17843–17849 |
| 响应式 ≤1100px | — | 8812–8829 | — | — |

---

## §2 整页背景与外框（由 Shell 提供，页本体不重绘）

**v88 `.settings-page`（8196–8236）**：`inset:18px`、`radius:26px`、
近黑竖渐变 `linear-gradient(180deg, rgba(20,24,34,.93), rgba(8,11,18,.92))` + 双角径向辉光
（左上 aqua .10 / 右上 violet .10）+ 1px 白描边 .11 + 巨投影 + `backdrop-filter:blur(30px)`；
`::before` = 42px 白发丝方格纹（`background-size:42px 42px`，opacity .24）。

**QML 落地（MUST）**：复用 Shell 既有全幅背景层（`DesktopAppShell.qml:261–328`）：

1. **蓝黑深度坡竖渐变**：`Rectangle` gradient `ml.bg0 → ml.bg2 → ml.bg3`（夜
   `#05070D→#0D1320→#121A2A`；昼暖坡）。对齐 v88 `rgba(20,24,34,.93)→rgba(8,11,18,.92)`
   的近黑底（D-NO-BACKDROP-BLUR：不透明深坡替代 backdrop）。
2. **角辉对**：左上 `GlowCircle{ glowColor: ml.aqua; glowOpacity: ml.glowStrength*0.22 }`、
   右上 `GlowCircle{ glowColor: ml.violet; glowOpacity: ml.glowStrength*0.18 }`（已存在）。
   对齐 v88 `radial 12% 0% aqua .10 / 88% 16% violet .10`。
3. **42px 蓝图格纹**：`GridTexture{ cell:42; lineColor: ml.gridLine; textureOpacity:0.95 }`
   + 羽化白圆角矩形 `MultiEffect` 遮罩（边缘渐隐不硬切，窗口 DWM 圆角再裁四角）。
   **MUST** 在 `:296` 把 `visible` 条件扩为含 `"settings"`，否则设置页无格纹（与日历/统计不一致）。

**外框（MUST）**：`fullBleedPage===true` 时 Shell 关掉内容区外框 + 玻璃 + 偏移投影
（`:765 / :785 / :775`），让暗水面铺满全 App。设置页 `Item{ anchors.fill:parent }` 根
直接画 §3 壳布局，**不画** `inset:18px` 外框（那是 Shell 内容区 margin 已给的）。

**入场动画（SHOULD）**：v88 `.settings-page.open` = `opacity 0→1 (.24s ease)` +
`transform translateY(18px) scale(.985) → 0/1 (.30s cubic-bezier(.18,.9,.2,1))`。在
QML 中本页由 Shell `Loader` 切入；如需复刻覆盖式入场，给根 `Item` 加
`opacity`/`scale`/`y` 的 `NumberAnimation`（缓动取 `ml.easeSnappy`）。
**坑（来自统计页记忆 timearc-stats-page）**：入场动画**禁止** `opacity:0 + onCompleted.start`
配 `running:false`，否则整页隐形；必须 `running:true` 自启。

---

## §3 壳布局（settings-shell：238 + 1fr）

```
DesktopSettingsPage（Item，全幅；保留 nightMode 注入 + nightModeToggled 信号契约）
├─ MemoryLakeStyle { id: ml; night: nightMode }          // 单一令牌源（同日历/统计）
├─ RowLayout/GridLayout（238px 左面板 + 1fr 右主区，gap 18）
│   ├─ 左导航面板 GlassPanel（§4）
│   └─ 右主区 ColumnLayout（顶栏 §5 + 滚动区 §6/§7）
└─ Settings Toast（§7.12，页内绝对定位底部居中）
```

- **MUST** 壳为 2 列：左 `Layout.preferredWidth: 238`，右 `Layout.fillWidth`，`spacing: 18`，
  整体 `padding: 18`（对齐 `.settings-shell` 8238–8247）。
- **MUST** 响应式：窗口内容宽 ≤ ~1100（对齐 v88 媒体查询 8812）时左面板隐藏、
  卡网格塌成 1 列、`wide` 卡不再跨列。最小验证宽 1280×720（记忆 timearc-ui-build-verify：
  全幅页 MUST 在最小尺寸 PrintWindow 验证）——1280 减侧栏 232 减边距后右主区接近阈值，
  必须实测两列是否要降一列。

---

## §4 左导航面板（settings-nav-panel）

**容器**：`GlassPanel{ style: ml }`，`radius: 22`（v88 8251），`padding:16`，竖向 Column gap 14。
背景 `rgba(255,255,255,.045)` → `ml.calPanelBg`；边 `rgba(255,255,255,.08)` → `ml.panelBorder`。

### 4.1 标题块（settings-title-block 8262–8292）
- 圆角 18 内卡，底 = `radial(8% 0% aqua .16) + rgba(0,0,0,.18)`：QML 用 `Rectangle{ color: ml.calSunkBg }`
  叠一颗低透 `GlowCircle{ glowColor: ml.aqua; glowOpacity: 0.16 }` 于左上角；边 aqua .12 = `ml.calInputBorder`。
- **kicker**「Control Center」：`ml.aqua`，`font.pixelSize:11`（**MUST int**，见 §10 坑），
  `font.weight: Font.Black`（850→Black），字母大写 + letterSpacing .7。
- **h2**「设置」：25px、`ml.textPrimary`、letterSpacing -.8。
- **p** 说明：11px、`ml.textSecondary`（`rgba(235,245,255,.45)`）。

### 4.2 原型提示条（prototype-status 11608–11621）
琥珀玻璃条：底 `rgba(255,230,163,.075)`、边 `.13`、字 `rgba(255,238,190,.76)`。
**QML**：`Rectangle{ radius:16; color: Qt.rgba(1,0.90,0.64,0.075); border.color: Qt.rgba(1,0.90,0.64,0.13) }`
（琥珀色非既有令牌；可新增 `ml.protoAmberBg/Border/Text` 或就地常量，见 §9 备注）。
**功能注（与功能文一致）**：本条文案需从「原型/localStorage」改写为「真实本地数据 + 系统权限」
口径（见功能文 §2 与问题文档 §C）。

### 4.3 标签列（settings-tab 8294–8341）
- 5 个 `height:45`、`radius:15`、`grid 28px+1fr`、左对齐。图标在 28×28 圆角 10 的
  `rgba(255,255,255,.06)` 小块内（`ml` 无此令牌，用就地 `Qt.rgba(1,1,1,0.06)`）。
- 文案字 13px weight 780（→Font.DemiBold）。
- **三态（MUST）**：默认字 `rgba(235,245,255,.58)`；hover 底 `rgba(255,255,255,.055)` + 字提亮；
  **active** 底 `rgba(142,223,255,.12)`=`ml.accentSoft`、边 `rgba(142,223,255,.22)`=`ml.accentSoftBorder`、
  字 `.94`、顶沿内高光。复用日历视图 Tab 的三态配方（同 CSS 家族）。
- 图标字形：v88 用 emoji/符号（✦ ◉ ◆ ◇ ⇅）。**MAY** 改用 `resources/icons/*.svg`
  统一描线风（与侧栏导航一致）；若保符号则用 `Text` 居中。

### 4.4 页脚（settings-nav-footer 8343–8367 + workflow-map 11689–11716）
- `margin-top:auto` 顶到底；圆角 17 内卡 `rgba(0,0,0,.18)` = `ml.calSunkBg`。
- **工作流图**：4 行 `workflow-step`（min-h 38、圆角 14、`grid 68px+1fr`），左标题 `ml.aqua`
  系（`rgba(159,231,238,.82)`）11px、右说明 `ml.textSecondary` 11px。文案：首页/日历/统计/回顾。
- **同步点 settings-sync-dot**：7px aqua 圆 + `box-shadow 0 0 15px aqua .65` 柔晕（用叠层低透圆
  仿，参考侧栏 active 发光点配方 `DesktopAppShell.qml:533–551`）+ 文案「本地数据已保护 / 最后同步：刚刚」。

---

## §5 右主区顶栏（settings-topbar 8376–8429）

`min-h:82`、`radius:22`、`grid 1fr 280px auto`、对齐玻璃面（`ml.calPanelBg` + `ml.panelBorder`）。

- **左**：`h3` 动态标题（22px，letterSpacing -.45）+ `p` 动态描述（12px，`ml.textSecondary`）。
  文案随 active 标签切换（5 套，见功能文 settingsCopy 表）。
- **中**：搜索框 `.settings-search`（h40、radius14、底 `rgba(0,0,0,.16)`=`ml.calSunkBg`、
  边 aqua .12=`ml.calInputBorder`、字 .90、placeholder `.30`）。QML `TextField`，背景自绘
  圆角矩形（关原生 frame），placeholder 用 `placeholderText` + 低透色。
- **右**：返回按钮「返回首页」（h40、radius14、ghost 玻璃 `ml.calGhostBg` / hover `ml.calGhostHover` /
  边 `ml.calGhostBorder`、字 weight 760）。点击 = `requestNavigate("memorylake")`（见功能文 §3）。

---

## §6 卡网格与卡片

### 6.1 滚动区（settings-scroll 8431–8435）
`SilkyFlickable`（复用记忆湖顺滑滚动）或 `Flickable` + `ScrollBar.vertical`，
`overflow-y:auto`、右留 6px。`clip:true`。

### 6.2 分区入场（settings-section 8437–8449）
切标签时 active 分区播 `settingsSectionIn`：`opacity 0→1 + translateY(10→0)`，`.26s`
缓动 `ml.easeSnappy`。QML：分区根 `Item`，`visible` 切换时跑一段 `NumberAnimation`。
**坑**：同 §2 入场坑（running:true 自启，勿 onCompleted gating）。

### 6.3 卡网格（settings-grid 8451–8459）
2 列 `repeat(2, minmax(0,1fr))`、gap 14。`wide` 卡跨 2 列（`grid-column: span 2`）。
`three` 变体（3 列）当前 DOM 未用，但 CSS 存在——**MAY** 预留。
QML 用 `GridLayout{ columns:2; columnSpacing:14; rowSpacing:14 }`，wide 卡
`Layout.columnSpan:2`。

### 6.4 卡片（settings-card 8461–8513）
- `GlassPanel{ style: ml }`，`radius:22`、`padding:16`、`min-h:130`、`clip:true`。
  底 = `radial(0% 0% aqua .08) + rgba(255,255,255,.045)`：`ml.calPanelBg` 叠左上角低透
  `GlowCircle{ ml.aqua, 0.08 }`；边 `ml.panelBorder`。
  **注**：v88 在 11624–11632 把卡阴影统一压成 `0 10px 28px black .18`（`!important`）——
  QML `GlassPanel` 默认不挂硬投影（dropShadow:false），符合此「柔玻璃无硬下沉带」意图，**保持默认关**。
- **卡头 settings-card-head**：左 `h4`（15px，letterSpacing -.2）+ `p`（12px，`ml.textSecondary`，
  line-height 1.55）；右 **图标徽章 settings-icon-badge**（38×38、radius14、
  渐变 `135deg aqua .22 → violet .20`、字 `.88`）。徽章渐变 **MUST** 用 `RoundedFrame`
  或 `Rectangle{ gradient }`（aqua/violet 令牌），居中符号/SVG。
- **设置行 setting-row**：`margin-top:14`、`min-h:42`、`grid 1fr auto`、`padding:10 0`、
  **顶部 1px 分隔线** `rgba(255,255,255,.06)`（`ml.cellHair` 近似），首行无线。
  左 `setting-label`：`b` 标题 13px `.88` + `small` 说明 11px `.38`（`ml.textTertiary`）。
  右 = 控件（§7）。QML 每行 `RowLayout`，顶分隔 `Rectangle{ height:1; color: ml.cellHair }`。

---

## §7 控件渲染配方（逐控件 → QML + 令牌）

> 通用：所有控件 **MUST** 取 `MemoryLakeStyle` 令牌，禁止散落 hex。交互态（hover/active/
> on/off）配色见各小节。**MUST 整数像素**：所有 `font.pixelSize` 为 int（Qt6 小数报错）。

### 7.1 开关 switch（8544–8575）
- 轨 48×28、radius999；关 `rgba(255,255,255,.12)`、开渐变 `135deg aqua .75 → violet .72`。
- 旋钮 22×22 圆，关 `left:3`、开 `translateX(20)`，色 `.92`→white。
- 动画：旋钮 `.22s cubic-bezier(.18,.9,.2,1)`=`ml.easeSnappy`，轨底 `.2s`。
- **QML**：`Rectangle{ width:48;height:28;radius:14 }`（轨）+ 子 `Rectangle{ width:22;height:22;radius:11 }`
  旋钮，`x` 绑 `on? 23:3` + `Behavior on x`；轨 `color` 开态用 `LinearGradient`/两段 gradient（aqua→violet）。
  点击 toggle + 弹 toast（功能文 §3）。**复用** `qml/mobile/components/MobileSwitch.qml` 的旋钮位移
  范式（桌面需重做暗玻璃皮，见 §0 R5）。

### 7.2 下拉 select（8577–8592）
- h34、min-w132、radius12、底 `ml.calSunkBg`、边 `ml.calInputBorder`、字 `.86`。
- **QML**：`ComboBox`，**MUST 自绘** `background`（圆角矩形 + 令牌色）、`contentItem`（Text）、
  `popup`（暗玻璃 `ml.calPanelBg` + `ml.panelBorder` + 选中 `ml.accentSoft`），**关原生外观**
  （原生 ComboBox 在暗底下读作浅色突兀）。无既有暗玻璃 ComboBox，须**新建** `GlassComboBox.qml`
  （问题文档 §G 缺口 UI-1）。

### 7.3 文本输入 input（8577–8592 同族）
- 同 select 量值。**QML**：`TextField`，自绘背景 `ml.calSunkBg` + `ml.calInputBorder`，
  字 `ml.textPrimary`，关原生 frame。用于「默认便签作者」（默认值 JusTin D / 或取
  `settingsRepository.getValue("memo_author", …)`，见功能文）。

### 7.4 磨砂滑块 range-control（8589–8592）
- v88：`<input type=range min=8 max=36 value=24 accent-color:#9FE7EE>`。
- **QML**：`Slider`，自绘 track（`ml.trackBg`）+ filled（aqua→violet 或 `ml.aqua`）+ handle
  （aqua 圆 + 内高光）。无既有暗玻璃 Slider，须**新建** `GlassSlider.qml`（缺口 UI-2）。
- **D-NO-BACKDROP-BLUR**：此滑块在 web 改 `backdrop-filter:blur(v)`；QML 无实时背景模糊。
  渲染落地两选一（产品决策，问题文档 §G G-BLUR）：(a) 映射为玻璃叠色不透明度的细微调；
  (b) 标注为「视觉强度（占位）」当前不改实际模糊。无论哪种，滑块本身照画。

### 7.5 强调色点 accent-dot（8594–8620 + JS 17908）
- 4 颗 34×34、radius13、各自渐变（`135deg` 两色），边 `rgba(255,255,255,.16)` + 内高光 .18。
- active 叠居中 `✓`（white，900，文字阴影）。
- **QML**：`Row` of `Rectangle{ gradient }`（或 `RoundedFrame` 裁渐变），选中叠 `Text{"✓"}`。
  4 组渐变（aqua→violet 默认 / pink→orange / mint→cyan / lilac→violet）按 v88 `data-accent` 值。
- **D-ACCENT**：选色当前 web 只改 `--settings-accent` CSS 变量。在 QML，全 App 强调色由
  `MemoryLakeStyle.aqua/violet`（`readonly` 固定）决定。要让选色**真正全局生效**需把强调色
  改为**可注入**（仿 `injectedTextPrimary` 模式），属架构改动 → 问题文档 §G G-ACCENT（产品+技术决策）。
  最小落地：持久化 `settingsRepository.setValue("accent", hex)` + 仅本页高亮选中态，全局应用留待决策。

### 7.6 主题开关 theme-switch + chip 预览（12372–12418 + JS 18678）
- **theme-mode-control** 容器：radius18、`radial(0% 0% aqua .12) + rgba(0,0,0,.14)`、`grid 1fr auto`。
- 左 copy：`b`「白天模式色调」13px + `small` 说明 11px + **chip 预览**两颗 42×28 圆角999：
  `night` = `radial aqua .55 + linear(#0b111d,#24243a)`；`day` = `radial(#54c8dc) + linear(#eef8ff,#dce9ff)`。
- 右 **theme-switch** 66×34、radius999、底 `radial(24% aqua .20) + rgba(255,255,255,.08)`；
  旋钮 26×26 含字形：夜 `☾`（aqua）`left:4`；昼 `☀`（#3b7f9a）`translateX(32)` + 暖白底。
  动画 `.28s ml.easeSnappy`。
- **QML**：自绘轨 + 旋钮（`x` 绑 `dayOn? 36:4`），旋钮内 `Text{ "☾"/"☀" }`。
  **D-THEME=NIGHTMODE**：`dayOn === !nightMode`；点击 `nightModeToggled(!nightMode)`。
  chip 预览两颗用 `Rectangle{ gradient } + GlowCircle`。

### 7.7 指标条 metric-strip + settings-metric（8622–8648）
- 网格（2 或 4 列，DOM 用 inline `grid-template-columns`）。每格 radius16、底 `ml.calSunkBg`、
  边 `rgba(255,255,255,.065)`：`span` 标签 10px `.38` + `strong` 数值 21px `.94` letterSpacing -.4。
- **QML**：`GridLayout` of `Rectangle{ color: ml.calSunkBg }`，内 Column（小标签 + 大数值）。
  数值接真实后端（今日使用 / 切换次数 / 缓存 / 记录数 / 备忘页数 / 番茄态，见功能文 + 问题文档）。

### 7.8 应用清单 app-manage-item（8650–8689）
- 列表项 `grid 34px+1fr+auto`、radius14、底 `ml.calSunkBg`、边 .06。
- 左 **图标块** 34×34 radius12 渐变 `aqua .18 → violet .15` + 字母（首字，860）；
  中 `b` 名 12px + `small` 类别·时长 10px `.38`；右 = §7.1 开关。
- **QML**：`Repeater` + `RowLayout`。图标可用 `AppVisual.js` 取真实 APP 主色/首字（与记忆湖一致）。
  数据来源 = `usageStatManager` 应用清单（见问题文档：per-app 显隐是否落地）。

### 7.9 按钮 settings-btn（8691–8726）
- 基础：h38、radius13、底 `rgba(255,255,255,.06)`=`ml.calGhostBg`、边 aqua .15、字 weight 760；
  hover `aqua .10`=`ml.calGhostHover`。
- **primary**：渐变 `135deg aqua .82 → violet .78` + 近黑墨字 `ml.calBtnInk` + 边 .18。
- **danger**：边 `rgba(255,95,95,.20)`、字 `rgba(255,190,190,.86)`、hover 底 `rgba(255,95,95,.14)`
  = `ml.calDangerWash` 族。
- **QML**：`Rectangle + MouseArea`（或自绘 `Button`），三皮（ghost/primary/danger）。
  复用日历页 ghost/primary 按钮配方（同 CSS 家族）。

### 7.10 快捷键格 shortcut-grid + kbd（8728–8763）
- 2 列网格，每项 min-h40 radius14 底 `ml.calSunkBg`、`grid auto+1fr`：左 **kbd** 键帽
  （min-w34 h28 radius9 底 `rgba(255,255,255,.10)` 边 .14 字 900）+ 右说明 11px `.58`。
- **QML**：`GridLayout` of `RowLayout`（键帽 `Rectangle` + 说明 `Text`）。纯展示（只读）。

### 7.11 存储条 storage-bar（8765–8780）
- 轨 h12 radius999 底 `rgba(255,255,255,.07)`=`ml.trackBg`；填充 `span` 宽 47%、
  渐变 `90deg aqua → violet` + `box-shadow 0 0 18px aqua .35` 外辉。
- **QML**：`Rectangle{ color: ml.trackBg }` + 子填充 `Rectangle{ gradient(aqua→violet); width: parent.width*ratio }`，
  外辉用低透叠层或 `GlowCircle`。ratio 接真实存储占比（见问题文档：存储统计是否可得）。

### 7.12 toast settings-toast（8782–8806）
- 绝对底部居中：`bottom:24`、min-w220、radius999、底 `rgba(14,18,26,.86)`=`ml.calToastBg`、
  边 aqua .14、字 `.78`、`backdrop-filter:blur(14px)`（QML 用叠色近似）。
- 显隐：`opacity 0→1 + translateY(12→0)`，`.20s/.22s`；显示 1.3s 后淡出。
- **QML**：复用日历页 toast 配方（`ml.calToastBg`），页内顶层绝对定位。文案随动作切换
  （功能文 §3 toast 文案表）。

---

## §8 白天 / 日间模式映射（light 覆盖 → 派生浅瓷）

### 8.1 原则
v88 `body.light-mode`（12420–13500）把整 App（含设置页）换成**雾面日光玻璃**：
亮背景 + 深色文字 + 低饱和蓝紫光效——**保留同一套玻璃排版与霓虹色相，只换明度/饱和度**
（CSS 注释 12313–12316 原话）。这与 `MemoryLakeStyle` 的 `night:false` 昼分支**意图完全一致**。

### 8.2 落地（MUST）
- 设置页所有令牌取 `MemoryLakeStyle`，故**昼/夜只随 `ml.night` 自动切**，无需写第二套样式：
  - 页底：夜 `calPageTop/Bottom`（#141822/#080B12）↔ 昼（#FCFDFE/#F1F6FA）。
  - 玻璃面：`calPanelBg`、下沉 `calSunkBg`、输入边 `calInputBorder`、ghost `calGhost*` 均已带昼/夜两值。
  - 文字：`textPrimary/Secondary/Tertiary` 昼取注入暖墨色、夜取设计稿白阶。
- aqua/violet/pink **两态同色**，靠 `glowStrength`（夜 1.0 / 昼 0.45）与低 alpha 收昼辉（§0 D-REUSE-GLASS）。

### 8.3 待核对（→ 问题文档 §R 渲染缺口）
- v88 light 覆盖里**设置页专属类**（如 `body.light-mode .settings-card/.settings-nav-panel/.settings-tab/
  .theme-switch` 等，散落 12483–13021 与 12767–13030 与 13313–13480 三处）有**精确浅色 hex**。
  落地时 **MUST** 抽样比对：现有 `cal*` 昼值是否与设置页 light hex 在同一明度带；不一致处
  登记 **R-LIGHT-N** 并就地补设置页昼令牌（如 `protoAmber` 琥珀提示条昼值、`theme-switch` 昼轨色）。
- D-NO-BACKDROP-BLUR：磨砂强度滑块的昼/夜表现见 §7.4 + 问题文档 G-BLUR。

---

## §9 令牌映射表（v88 CSS rgba → MemoryLakeStyle）

| v88 CSS 值 | 用处 | MemoryLakeStyle 令牌 | 备注 |
|---|---|---|---|
| `linear(rgba(20,24,34,.93)→rgba(8,11,18,.92))` | 页底近黑 | `bg0/bg2/bg3` 深度坡 | Shell 已绘 |
| `radial 12%0% aqua .10` / `88%16% violet .10` | 角辉对 | `aqua`/`violet` + `GlowCircle` | Shell 已绘 |
| `42px 白发丝方格 .24` | 整页格纹 | `gridLine` + `GridTexture(cell:42)` | 须开 `:296` settings |
| `rgba(255,255,255,.045)` | 面板/卡玻璃底 | `calPanelBg` | 复用日历 |
| `rgba(0,0,0,.16~.18)` | 下沉输入/内卡/页脚 | `calSunkBg` | 复用日历 |
| `rgba(142,223,255,.12)` | aqua 输入描边 | `calInputBorder` | 复用日历 |
| `rgba(255,255,255,.08)` | 面板/卡边 | `panelBorder` | — |
| `rgba(255,255,255,.06)` | 行分隔/小边 | `cellHair`（近似） | — |
| `rgba(142,223,255,.12/.22)` | tab active 底/边 | `accentSoft`/`accentSoftBorder` | — |
| ghost 按钮 `rgba(255,255,255,.065)/.10/.11` | 返回/普通按钮 | `calGhostBg`/`calGhostBorder`/`calGhostHover` | 复用日历 |
| `135deg aqua .82→violet .78` + `rgba(4,8,14,.92)` 字 | primary 按钮 | `aqua`/`violet` + `calBtnInk` | — |
| `rgba(255,95,95,.14~.20)` | danger 按钮/危险洗 | `calDangerWash` 族 | 复用日历 |
| `rgba(14,18,26,.86)` | toast 底 | `calToastBg` | 复用日历 |
| `#9FE7EE`/`#9B8BFF`/`#D88AAC` | 强调三色 | `aqua`/`violet`/`pink` | — |
| `rgba(255,255,255,.07)` | 存储条轨 | `trackBg` | — |
| `cubic-bezier(.18,.9,.2,1)` | 开关/入场/切换 | `easeSnappy` | — |
| `rgba(255,230,163,.075/.13)` | 原型提示琥珀 | **新增** `protoAmber*` 或就地 | 见 §4.2/§8.3 |
| `rgba(255,255,255,.06)` 28×28 | tab 图标块底 | 就地 `Qt.rgba(1,1,1,0.06)` | 微量，免新增令牌 |

---

## §10 动画与缓动清单

| 动画 | v88 | QML 落地 | 缓动 |
|---|---|---|---|
| 整页入场 | `.open` opacity+translateY+scale .24/.30s | 根 Item NumberAnimation（running:true） | `easeSnappy` |
| 分区切换 | `settingsSectionIn` opacity+translateY .26s | 分区 visible→播放 | `easeSnappy` |
| 开关旋钮 | `transform .22s` | `Behavior on x` | `easeSnappy` |
| 主题开关 | `.28s` | `Behavior on x` | `easeSnappy` |
| tab 三态 | bg/border/color .18s | `Behavior on color` | 默认 |
| toast 显隐 | opacity+translateY .20/.22s | opacity/y NumberAnimation | `easeSnappy` |
| 搜索过滤 | 即时显隐 | `visible` 直切（可加 opacity） | — |

**坑（MUST 记牢，来自 timearc-stats-page）**：
1. **Qt6 `font.pixelSize` 必须 int**——v88 多处 11/13/21/25px 都是整数，安全；但任何派生
   计算（如 `*0.5`）出小数会报「int expected」。
2. **入场动画勿用 `opacity:0 + onCompleted.start` 配 `running:false`**——会整页隐形；用 `running:true`。
3. **rebuild 前必杀 `TimeArc.exe`**（exe 锁，记忆 timearc-ui-build-verify）。

---

## §11 性能与抓图验证

- **静态纹理**：`GridTexture`/`GlowCircle` 均为一次性 Canvas（无 FBO、不随帧刷新），
  设置页新增它们对帧率无持续开销（与日历/统计页同结论）。
- **玻璃近似**：无 `backdrop-filter`，全部叠色（`GlassPanel`），无每面板实时模糊开销。
- **避免** 给每张卡挂 `MultiEffect` 软投影（v88 已把卡投影压成廉价 box-shadow）——
  `GlassPanel.dropShadow` 保持默认 `false`。
- **抓图验证（MUST，记忆 timearc-ui-build-verify）**：
  - 用 **PrintWindow(by-PID)** 抓自有实例（非用户窗口），能穿全屏遮挡、非侵入。
  - **最小 1280×720 + 最大尺寸**两档都验：响应式 ≤1100 左面板隐藏 / 卡降 1 列是否正确。
  - 圆角/遮罩缺陷用 **品红底 3× 超采样 + 逐像素门**（普通截图会假阳性）。
  - 昼/夜两态、5 个标签分区、各控件交互态（开关 on/off、tab active、toast、下拉 popup）全覆盖。
  - 暗玻璃 ComboBox/Slider 等**新建控件**（§7.2/§7.4）须单独验证 popup/handle 在暗底下不露原生浅皮。

---

## §12 验收清单（美术 DoD）

- [ ] 整页全幅暗玻璃：Shell `fullBleedPage` + `:296` 格纹均含 `"settings"`；无「框中框」。
- [ ] 左面板：标题块/原型提示/5 标签三态/工作流图/同步点发光全部对齐令牌，无散落 hex。
- [ ] 右顶栏：动态标题+描述随标签切换；搜索框/返回按钮暗玻璃皮。
- [ ] 5 分区卡网格 2 列（wide 跨列）+ 分区入场动画；卡片玻璃底+角辉+图标徽章渐变。
- [ ] 全部控件配方落地：开关/下拉/输入/滑块/强调点/主题开关+chip/指标条/应用清单/三皮按钮/
      快捷键格/存储条/toast——交互态与动画齐全。
- [ ] 昼/夜随 `nightMode` 自动切（无第二套样式）；light 专属 hex 已比对，差异登记 R-LIGHT-*。
- [ ] 新建 `GlassComboBox`/`GlassSlider`（+ 可能 `GlassSwitch`）在暗底无原生浅皮外露。
- [ ] PrintWindow 1280×720 + 最大尺寸 + 昼夜 + 各交互态抓图通过；圆角逐像素门通过。
- [ ] `python .harness/tools/scan_qt_log.py` 零 QML 警告；`harness_check.py` exit 0。
