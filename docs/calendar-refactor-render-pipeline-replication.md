# 日历页 · 渲染管线完全复刻分析（暗玻璃 / 月历栅格 / 三栏 chrome）

> 配套文档：`docs/calendar-refactor-functional-replication.md`（行为 / 状态 / 数据）。
> 本文只管「像素怎么长出来」。功能搬运、数据契约、验收清单在配套文档。
> 设计稿真值：`MemoryLakeDesign/TimeArcDesign_v88.stripped.html`，日历 CSS 在 **9109–9606**（暗），
> light-mode 覆盖在 **~12438 / 13167–13302 / 13524**；标记在 **14167–14241**。
> 既有技法字典：`docs/memory-lake-art-lighting-qml-cookbook.md`（下称 *cookbook*）。
> 诚实天花板：`docs/memory-lake-fidelity-gaps.md`（下称 *gaps*）。

---

## §0 核心结论（先给判断，再给证据）

1. **这是「重皮」不是「绿地」。** 日历页已存在：`qml/desktop/pages/DesktopCalenderPage.qml`（1520 行），
   走的是旧的**奶油/米色 soft 主题**（`#FBF8F4` / mint / lavender / blush，`SoftCard/SoftButton/SoftPill`）。
   v88 把它换成与首页、备忘页**同一套** memory-lake 暗玻璃霓虹语言。渲染文档的活比备忘重（整页重新打光），
   功能文档的活比备忘轻（数据通路已正确）。

2. **页面形态已定：保持「路由页」，不做 overlay。**（用户决定）
   v88 的 `.calendar-page` 是窗口内 `inset:18px` 的浮层（`z-index:35`，`opacity/transform` 开合，
   `backdrop-filter: blur(30px)`）。而 TimeArc 日历是侧栏 `requestNavigate('calendar')` 进入的整页 Loader。
   **后果（关键）**：路由页背后没有「可快照重模糊」的活背景，所以 **`backdrop-filter` 无法 1:1**（*gaps* 标 🔴）。
   解法 = 用 MemoryLakeStyle 暗色竖直渐变做**不透明基底**替代毛玻璃（cookbook 认可）。
   不要为此再加第 4 个 `MultiEffect` 模糊（违反 ≤3 blur 预算）。备忘页「入口=动作非路由」的旗舰教训**在此不适用**。

3. **最高杠杆复用 = `MemoDatePicker.qml`。** 它**已经**用暗霓虹主题实现了 v88 的月历栅格：
   42 格 Grid、**周一起始**、`today/selected` 态、aqua 选中胶囊、`‹ 年-月 ›` 导航、`一..日` 表头、`TimeBox` 时分步进。
   月历核心**不要从零推**——抬它的日期数学（`_daysInMonth/_firstWeekday/_two`）与 cell delegate。
   次高杠杆 = `CalendarSyncList.qml`：已证明 `calendarManager.savedTodos` 绑定 + 玻璃+辉光+栅格的 panel 配方。

4. **诚实天花板（详见 §7）**：整体可达 ~**90%**。唯一 🔴 是 `backdrop-filter`（按 §0.2 用不透明基底降级，视觉可接受）；
   其余（暗玻璃板、双角辉光、42px 蓝图栅格、发丝 cell、事件胶囊、开合动效）都有 1:1 或近似 1:1 的既有组件。

---

## §1 v88 日历页渲染管线 · 全层解剖（终值 + 行号）

> 规则同备忘文档：CSS 分层，后块与 `!important` 覆盖前块；下方均为**终值**。暗模式为主，light 覆盖单列。

### §1.1 整页基底 `.calendar-page`（9109–9135；light 13289–13302）
```css
position:absolute; inset:18px; z-index:35; border-radius:26px;
background:
  radial-gradient(circle at 15% 0%,  rgba(142,223,255,.10), transparent 34%),   /* 左上 aqua 角晕 */
  radial-gradient(circle at 88% 18%, rgba(155,139,255,.12), transparent 38%),   /* 右上 violet 角晕 */
  linear-gradient(180deg, rgba(20,24,34,.94), rgba(8,11,18,.94));               /* 近黑竖直深度 */
border:1px solid rgba(255,255,255,.11);
box-shadow: 0 36px 120px rgba(0,0,0,.58), inset 0 1px 0 rgba(255,255,255,.06);
backdrop-filter: blur(30px) saturate(125%);    /* ← 路由页无法 1:1，§0.2 用不透明基底替代 */
color: rgba(245,250,255,.92); overflow:hidden;
opacity:0; pointer-events:none; transform: translateY(18px) scale(.985);
transition: opacity .24s ease, transform .30s cubic-bezier(.18,.9,.2,1);   /* = easeSnappy */
```
- `.open`：`opacity:1; transform: translateY(0) scale(1)`（9131–9135）。
- light（13289+）：背景→ `radial(10% 0%, rgba(8,145,178,.075)…) , linear(var(--day-panel)=rgba(255,255,255,.86), rgba(248,251,253,.80))`；
  边 `--day-line=rgba(24,42,62,.13)`；阴影 `0 18px 48px rgba(40,62,85,.13)`；`backdrop-filter` 由中段块设 `blur(28px) saturate(122%)` 并保留。
- **QML**：`RoundedFrame(radius:26)` 包裹 → `Rectangle` 竖直渐变基底 + 2×`GlowCircle`（角外置）+ `GridTexture`（见 §1.2）。
  暗影用 cookbook §3 的 `ElevatedSurface` 4 级阴影表里的「floating」级，不用 `backdrop-filter`。

### §1.2 蓝图栅格 `.calendar-page::before`（9137–9147；light 13632 调暗到 .10）
```css
background:
  linear-gradient(90deg, rgba(255,255,255,.035) 1px, transparent 1px),
  linear-gradient(0deg,  rgba(255,255,255,.030) 1px, transparent 1px);
background-size: 42px 42px; opacity:.24; pointer-events:none;
```
- **QML**：`GridTexture{ cell:42; lineColor: ml.gridLine; textureOpacity:0.24 }`，**置于 `RoundedFrame` 内**才会裁到 r26。
  `CalendarSyncList` 已用 `cell:24` 验证过同一组件，1:1 可达。

### §1.3 三栏外壳 `.calendar-shell`（9149–9166）
```css
display:grid; grid-template-columns: 280px 1fr 310px; gap:16px; padding:18px; height:100%; z-index:1;
/* .calendar-panel: r22; background:rgba(255,255,255,.045); border:1px rgba(255,255,255,.08);
   box-shadow: inset 0 1px 0 rgba(255,255,255,.05); overflow:hidden; */
```
- ⚠️ `.calendar-panel` 的 box-shadow 在 **11626** 被 `!important` 覆盖为 `0 10px 28px rgba(0,0,0,.18)` + inset 缝（终值用这条）。
- **QML**：`GridLayout`（3 列固定 280/伸缩/310）。每个 `.calendar-panel` = `GlassPanel`（tier-1 玻璃，自带边光对 G4）。

### §1.4 左栏 brand card `.calendar-brand-card`（9176–9205）
```css
border-radius:20px;
background: radial-gradient(circle at 8% 0%, rgba(142,223,255,.16), transparent 42%), rgba(0,0,0,.18);
border:1px solid rgba(142,223,255,.12); padding:16px;
/* .kicker: #9FE7EE 11px/850 大写 letter-spacing.7  */
/* h2: 27px line-height1.05 letter-spacing-.8  | p: rgba(235,245,255,.46) 12px */
```
- **QML**：`FrostCard{ tintTop: ml.aqua }`（135° aqua 斜向晕）+ 角 `GlowCircle(aqua,.16)`；kicker 用 `ml.glowCyan`。
  `CalendarSyncList` 的 kicker/title/sub 排版是直接模板。

### §1.5 视图 Tab `.calendar-view-tab`（9207–9246）
```css
/* 容器: display:grid; gap:8px */
height:44px; border-radius:15px; border:1px solid transparent; background:transparent;
color:rgba(235,245,255,.58); display:grid; grid-template-columns:28px 1fr; gap:10px; padding:0 10px;
/* i 字形片: 28×28 r10 background:rgba(255,255,255,.06) place-items:center  (月/周/今/钟) */
:hover  { background:rgba(255,255,255,.055); color:rgba(245,250,255,.88) }
.active { background:rgba(142,223,255,.12); border-color:rgba(142,223,255,.22); color:rgba(245,250,255,.94) }
```
- **QML**：`ColumnLayout` of 4 个 toggle pill + `ButtonGroup`。active 态 = `ml.accentSoft/accentSoftBorder`。
  无切换动画（瞬时）。chrome 词汇参考 `MemoToolbar` 的 active aqua→violet。

### §1.6 统计芯片 `.calendar-small-stats / .calendar-stat`（9248–9272）
```css
/* 2×2 grid gap:10 */
.calendar-stat{ border-radius:16px; background:rgba(0,0,0,.16); border:1px rgba(255,255,255,.06); padding:12px }
span{ color:rgba(235,245,255,.38); font-size:10px }  strong{ margin-top:7px; font-size:21px; color:rgba(245,250,255,.94) }
```
- **QML**：4 个下沉小 `FrostCard`/`Rectangle(color: ml.bg with .16)`。10px 标签 + 21px 数字。

### §1.7 中栏顶栏 `.calendar-topbar`（9274–9327）
```css
min-height:78px; border-radius:22px; background:rgba(255,255,255,.045); border:1px rgba(255,255,255,.08);
display:grid; grid-template-columns:1fr auto auto; gap:12px; align-items:center; padding:14px 16px;
/* h3 23px letter-spacing-.5 | p rgba(235,245,255,.45) 12px */
/* nav 按钮 + .calendar-close: h38 min-w38 r13 border rgba(255,255,255,.10)
   background rgba(255,255,255,.065) color rgba(245,250,255,.86) font-weight760; :hover bg .11 */
```
- **QML**：`GlassPanel` **但压掉 drop-shadow**（v88 仅保 inset 缝，11626 排除项）。导航键 = 半透明白胶囊（hover 提亮）。

### §1.8 月视图 + 表头 + 栅格（9329–9400）
```css
.calendar-month-view{ border-radius:22px; background:rgba(255,255,255,.045); border:1px rgba(255,255,255,.08);
                      overflow:hidden; display:grid; grid-template-rows:auto 1fr }
.calendar-week-head{ display:grid; grid-template-columns:repeat(7,1fr); border-bottom:1px rgba(255,255,255,.07) }
  > div{ height:42px; place-items:center; color:rgba(235,245,255,.42); font-size:11px/800 大写 }   /* Mon..Sun */
.calendar-grid{ display:grid; grid-template-columns:repeat(7,1fr); grid-auto-rows:minmax(84px,1fr) }
.calendar-cell{ position:relative; padding:10px; box-sizing:border-box; cursor:pointer; overflow:hidden;
                border-right:1px rgba(255,255,255,.055); border-bottom:1px rgba(255,255,255,.055);
                transition: background .15s ease }
  :hover   { background:rgba(142,223,255,.055) }
  .muted   { opacity:.35 }
  .today   { background: radial-gradient(circle at 80% 12%, rgba(142,223,255,.16), transparent 40%), rgba(142,223,255,.04) }
  .selected{ outline:2px solid rgba(142,223,255,.32); outline-offset:-2px }
.calendar-date-num{ color:rgba(245,250,255,.78); font-size:12px/820 }   /* .today 时 → #9FE7EE */
```
- **核心视觉反转**：v88 cell 是**发丝分隔的账本**（无填充，只有右/下 1px 线 + 光态）。
  当前页 cell 是**填充圆角块**（`cardSoft/lightMint/cream`）。重构要把「填充块」翻成「发丝线 + 仅光态」。
- **QML**：抬 `MemoDatePicker` 的 42 格 Grid。`valid/sel/today`→`muted/selected/today`。
  `today` 用角 `GlowCircle(aqua,.16)` + `rgba(aqua,.04)` 底；`selected` 用 2px inset `Rectangle` 描边（`outline-offset:-2`）。
  hover wash 用 `Behavior on color`（.15s）。**周一起始**（见配套文档 §7-B）。

### §1.9 事件胶囊 `.calendar-event-chip`（9402–9427）
```css
margin-top:8px; height:22px; padding:0 8px; border-radius:999px; display:flex; gap:6px; align-items:center;
color:rgba(245,250,255,.88); font-size:10px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
background:rgba(142,223,255,.12); border:1px rgba(142,223,255,.14);     /* 默认 = event(aqua) */
&.todo  { background:rgba(255,230,163,.10); border-color:rgba(255,230,163,.16) }   /* 琥珀 */
&.focus { background:rgba(155,139,255,.12); border-color:rgba(155,139,255,.16) }   /* violet */
```
- 渲染逻辑（JS 18203–18215）：每格取前 3 条 `time + title`；超出加 `+N more` 胶囊。
- **类型色仅三种**：`event`=aqua、`todo`=琥珀(`ml.shareGold` 近似)、`focus`=violet。**v88 无 meeting/其它色**。
- **QML**：cell 内 `Column`，胶囊 = `Rectangle radius:11` + 类型→色映射；`elide:Text.ElideRight`。`+N more` 同款无色胶囊。

### §1.10 右栏：选中日卡 / 加日程表单 / 当天议程（9429–9569）
```css
.selected-day-card{ r20; background: radial(8% 0%, rgba(142,223,255,.14)…), rgba(0,0,0,.16); border:1px rgba(142,223,255,.12); padding:16 }
  span #9FE7EE 11/850 大写 | h3 24px | p rgba(235,245,255,.46) 12px
.event-form{ r20; background:rgba(255,255,255,.04); border:1px rgba(255,255,255,.07); padding:14 }
  input,select{ h36 r13 border rgba(142,223,255,.12) background rgba(0,0,0,.16) color rgba(245,250,255,.86) }
  .event-form-row{ grid 1fr 1fr gap8 }   /* time + type 并排 */
.event-add-btn{ h38 r14 border rgba(255,255,255,.14)
                background: linear-gradient(135deg, rgba(142,223,255,.78), rgba(155,139,255,.74)); color:rgba(4,8,14,.92)/820 }
.day-agenda{ flex:1; overflow-y:auto }   /* light: 主按钮 #0891B2→#6D5BD0  (13524) */
.agenda-item{ grid 4px 1fr auto; gap10; padding:11 0; border-top:1px rgba(255,255,255,.06) }
  .agenda-color{ 4×38 r999 #9FE7EE }   /* .todo→#FFE6A3 .focus→#9B8BFF  类型脊柱色 */
  .agenda-copy b{ rgba(245,250,255,.88) 13px } small{ rgba(235,245,255,.38) 11px }
  .agenda-delete{ 26×26 r9 background rgba(255,255,255,.07); :hover background rgba(255,95,95,.18) color#fff }
```
- **QML**：`selected-day-card`=`FrostCard(tintTop:aqua)`；`event-form` 输入用暗底 `TextField/ComboBox`（去原生描边）；
  `event-add-btn`=aqua→violet 135° 渐变键；`day-agenda`=`SilkyFlickable` + `agenda-item` delegate（左 4px 类型脊柱条 `Rectangle`）。
  ⚠ 右栏要承载**保留下来的** 待办/记录/纪念 三态（用户决定全保留）——见配套文档 §2.6。

### §1.11 Toast `.calendar-toast`（9571–9595）
```css
position:absolute; left:50%; bottom:24px; transform:translateX(-50%) translateY(12px); opacity:0; z-index:80;
min-width:220px; padding:11 14; border-radius:999px; background:rgba(14,18,26,.86);
border:1px rgba(142,223,255,.14); box-shadow:0 14px 44px rgba(0,0,0,.40); backdrop-filter:blur(14px);
.show{ opacity:1; transform:translateX(-50%) translateY(0) }   /* transition .20 opacity + .22 easeSnappy */
```
- **QML**：底中胶囊 `Rectangle` + `Behavior on opacity/y` + 自动隐藏 `Timer`，或复用 `AchievementToast`。当前页无 toast，此为净增反馈。

### §1.12 响应式（9597–9606）
`@media(max-width:1200px)`：shell 转单列、左右栏 `display:none`。**桌面定宽窗口下基本不触发**；QML 可只做定宽三栏，把折叠列为「可选/超范围」。

---

## §2 绿地就要搭对的管线 · 根因清单（pitfall 表）

| ID | CSS 字面直译的坑 | 正确 QML 做法 | 来源 |
|----|----------------|--------------|------|
| **M0** | `backdrop-filter: blur(30px)` 直接照搬 | 路由页无活背景可模糊 → 用 `ml` 暗竖直渐变做**不透明基底**；**不要**加 `MultiEffect` 背景模糊 | *gaps* 🔴 + §0.2 |
| **M1** | 用 `clip:true` 裁 r26 整页 / cell 内胶囊·照片 | `clip:true` 只裁矩形包围盒，圆角会漏方角内容 → `RoundedFrame`（FBO + 单次圆角 mask，`maskThresholdMin:0.5`） | *gaps* 漏边修复；MEMORY |
| **M2** | cell 照搬当前「填充圆角块」 | v88 是**发丝线账本**：cell 无填充、只右/下 1px 线 + `today/selected/hover` 光态 | §1.8 |
| **M3** | 角晕用 `radial-gradient(... transparent ...)` 直译 | `transparent`=黑@0 → 脏暗边；clean glow 用**同色 α0 收尾**；角晕用 `GlowCircle` 圆心**置于角外**只露 1/4 | cookbook §3.2/§3.3 |
| **M4** | 顶栏直接套 `GlassPanel` 带阴影 | 顶栏终值（11626）**无 drop-shadow**，只 inset 缝 → 关掉 `GlassPanel` 的 shadow | §1.7 |
| **M5** | 月历从零写日期数学 | `MemoDatePicker` 已实现 42 格/周一起始/today·selected → 抬它，别重推 | KB |
| **M6** | 每个角晕都上 `MultiEffect` | 全局 ≤3 真模糊；小辉光用 `GlowCircle`(Canvas radial，无 FBO)；不加第 4 个模糊 | cookbook §8 |
| **M7** | 颜色写死 hex（当前页 `#FBF8F4`/mint/...） | G1：全部走 `MemoryLakeStyle`；缺的 cell `today/selected/muted` token 追加到文件末（仿 memo token 150–187） | §1 全节 |

---

## §3 HTML 层 → QML 技法 → 是否需 shader 对照表

| HTML 层 | 终值要点 | QML 技法 | 需 .qsb? |
|--------|---------|---------|:--:|
| `.calendar-page` 基底 | 竖直近黑渐变 + 2 角晕 + 边 + 浮起阴影 | `RoundedFrame`>`Rectangle(LinearGradient)`+2`GlowCircle`+`ElevatedSurface`阴影 | 否 |
| `::before` 蓝图栅格 | 42px 1px 线 @ .24 | `GridTexture(cell:42)` | 否 |
| `.calendar-panel` ×3 | .045 玻璃 + inset 缝 + 软阴影 | `GlassPanel`（顶栏关阴影） | 否 |
| `.calendar-brand-card` | aqua 角晕 over 黑.18 | `FrostCard(tintTop:aqua)`+`GlowCircle` | 否 |
| `.calendar-view-tab` | ghost→hover→active aqua wash | `ButtonGroup` toggle pills | 否 |
| `.calendar-grid/cell` | 发丝账本 + today/selected/hover 光态 | 抬 `MemoDatePicker` Grid+delegate | 否 |
| `.calendar-event-chip` | r999 类型色低 α 玻璃胶囊 | `Rectangle r11` + 类型→色 map | 否 |
| `.event-add-btn` / light 主按钮 | aqua→violet 135° / `#0891B2→#6D5BD0` | `Rectangle(LinearGradient 135°)` | 否（线性原生 1:1） |
| 选中日/议程脊柱条 | 4px 类型色条 | `Rectangle radius:2` 类型色 | 否 |
| 开合 / `.show` toast | `easeSnappy` translate+scale/opacity | `Behavior` + `ml.easeSnappy` | 否 |
| `backdrop-filter` | blur(30) | **降级**：不透明基底（不可 1:1） | 🔴 不可 |
| 备忘→日历 success conic 光环（延后批次） | 旋转 conic + 粒子 | `Shapes.ConicalGradient` 或预烘转图 + `Repeater` 粒子 | 可选 |

**结论：日历主体重构零 shader。** 唯一可能用到自写 shader 的是延后的「备忘→日历同步工具」success 光环（§6），非必需。

---

## §4 核心技法详解（含代码骨架）

> 仅给关键骨架，token 全部来自 `MemoryLakeStyle`（下记 `ml`）。

### §4.1 暗玻璃整页基底（M0 + M3）
```qml
RoundedFrame {                       // 裁到 r26，内层栅格/角晕不漏角
    radius: 26; anchors.fill: parent
    Rectangle {                      // 竖直近黑渐变（不透明基底 = backdrop-filter 替代）
        anchors.fill: parent
        gradient: Gradient { GradientStop{position:0; color: ml.calPageTop}    // rgba(20,24,34,.94)→不透明等效
                             GradientStop{position:1; color: ml.calPageBottom} }
    }
    GridTexture { anchors.fill: parent; cell:42; lineColor: ml.gridLine; textureOpacity:0.24 }
    GlowCircle { glowColor: ml.aqua;   glowOpacity:.10; /* 圆心置左上角外，露 1/4 */ }
    GlowCircle { glowColor: ml.violet; glowOpacity:.12; /* 圆心置右上角外 */ }
}
```
- 边框 + 浮起阴影用 cookbook §3 的 `ElevatedSurface`「floating」级，不要 `backdrop-filter`。

### §4.2 发丝账本 cell（M2）
```qml
// 抬 MemoDatePicker 的 cell delegate；关键差异：去填充，加右/下发丝线
Item {
    property bool muted; property bool today; property bool selected
    opacity: muted ? 0.35 : 1
    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color: ml.cellHair }   // .055
    Rectangle { anchors.bottom:parent.bottom; height:1; width:parent.width; color: ml.cellHair }
    Rectangle { anchors.fill:parent; visible:today; color: ml.todayWash }                          // aqua .04
    GlowCircle { visible:today; glowColor: ml.aqua; glowOpacity:.16 /* 角内 80%,12% */ }
    Rectangle { anchors.fill:parent; anchors.margins:1; visible:selected; color:"transparent"
                border.width:2; border.color: ml.selectedRing /* aqua .32 */ }
    Behavior on color { ColorAnimation { duration:150 } }   // hover wash
}
```

### §4.3 事件胶囊（M7）
```qml
component EventChip: Rectangle {
    property string type   // "event"|"todo"|"focus"
    height:22; radius:11
    color:   type==="todo"? ml.chipTodoBg : type==="focus"? ml.chipFocusBg : ml.chipEventBg
    border.color: type==="todo"? ml.chipTodoBd : type==="focus"? ml.chipFocusBd : ml.chipEventBd
    Text { anchors.fill:parent; anchors.margins:8; elide:Text.ElideRight; verticalAlignment:Text.AlignVCenter
           text: time + " " + title; font.pixelSize:10; color: ml.chipText }
}
```

### §4.4 开合动效（easeSnappy）
```qml
// 路由页：用本地 open bool（onLoaded 置 true），不是 CSS .open
transform: [ Translate{ y: open?0:18 }, Scale{ origin.x:width/2; origin.y:height/2; xScale: open?1:.985; yScale: xScale } ]
opacity: open?1:0
Behavior on opacity { NumberAnimation{ duration:240 } }
Behavior on /*y/scale*/ { NumberAnimation{ duration:300; easing.bezierCurve: ml.easeSnappy } }
```

### §4.5 角晕 / clean glow / 栅格 / 玻璃板
直接复用既有组件：`GlowCircle`（§4.1）、`GridTexture`、`GlassPanel`、`FrostCard`、`RoundedFrame`。
均与首页/备忘同源，cookbook §3.2（clean glow 同色 α0）、§3.3（角外置圆心）、§5.3（程序化栅格）、§5.7（RoundedFrame）。

---

## §5 架构决策（最高杠杆）

1. **路由页 vs overlay → 路由页（已定）。** 入口仍 `requestNavigate('calendar')` → `DesktopAppShell` Loader case `calendar`。
   背景降级为不透明暗玻璃（§0.2）。开合动效挂 `Loader.onLoaded` / 本地 `open` bool（§4.4），不照搬 `.open` class。
2. **`MemoDatePicker` 的「升格」。** 它今天是弹出选择器；把它的栅格内核**提取/复用**为整页月视图的 cell delegate
   （而非整体内嵌一个 picker）。`TimeBox` 复用于 event-form 的时间输入。
3. **token 策略（G1）。** 删当前页 `#FBF8F4/mint/lavender/blush` 全部写死色；映射到 `ml.*`；
   日历专属 token（`calPageTop/Bottom`、`cellHair`、`todayWash`、`selectedRing`、`chip*`）**追加到 `MemoryLakeStyle.qml` 末尾**
   （仿 memo token 在 150–187 追加的先例），night/day 双值。
4. **主题注入契约。** 现页经 `AppShell.applyThemeToLoadedPage`（nightMode + 5 个 theme 属性）注入。两条路二选一并写明：
   (a) 保留该注入契约（rule 04 §2），把注入值映射到 `ml`；或 (b) 像 `CalendarSyncList` 本地实例化 `MemoryLakeStyle`。
   **建议 (a)**，与既有页一致，少动 AppShell。
5. **照片 cell（用户决定保留）。** v88 cell 无照片概念；保留时 cell 增加「可选照片填充态」：
   `Image` + `RoundedFrame` mask（不要 `Image+Rectangle mask+MultiEffect` 的旧法在圆角处漏边——迁到 `RoundedFrame`）。
   照片态与「发丝账本」基态并存（有图则铺图+渐变压暗+日号底片，无图则发丝）。

---

## §6 自写 shader：清单与构建路径

- **主体重构：0 个。** §3 表所有层都用既有组件/线性渐变达成。
- **唯一候选（延后批次 M-B6）**：备忘→日历同步工具的 success **conic 光环**。
  路径：`QtQuick.Shapes` `ConicalGradient`（够用）或预烘一张旋转 PNG 走 `resources/CMakeLists.txt`（**未冻结**，offline `qsb`，零变更提案）。
  非必需，不阻塞可跑切片。

---

## §7 复刻分级 · 诚实天花板

| 层 | 等级 | 天花板 | 说明 |
|----|:--:|:--:|----|
| 暗玻璃基底（不透明替代毛玻璃） | 🟡 | ~92% | 无真 backdrop blur；不透明渐变基底视觉接近，需真机确认可接受 |
| `backdrop-filter` 真实毛玻璃 | 🔴 | — | 路由页无活背景可重模糊；按 §0.2 降级（用户已接受路由页方案） |
| 42px 蓝图栅格 | 🟢 | 100% | `GridTexture` 1:1 |
| 双角辉光 | 🟢 | ~98% | `GlowCircle` 角外置；clean glow |
| 三栏玻璃板 / brand / 顶栏 | 🟢 | ~97% | `GlassPanel/FrostCard`；顶栏关阴影 |
| 发丝账本 cell + 光态 | 🟢 | ~95% | 抬 `MemoDatePicker`；today/selected/hover |
| 事件胶囊（3 类型色） | 🟢 | 100% | `Rectangle` + 色 map |
| 主按钮 / 脊柱条线性渐变 | 🟢 | 100% | 线性原生 1:1 |
| 开合 / toast 动效 | 🟢 | ~95% | `Behavior` + easeSnappy |
| 备忘→日历 success 光环 + 粒子 | 🟡 | ~85% | conic + 粒子，延后；真机逐帧比 |

**总体 ~90%**，唯一硬伤是 backdrop-filter（已由「路由页」决策接受降级）。

---

## §8 实施批次（M-B，与功能文档 F-B 咬合）

> 每批收尾：kill `TimeArc.exe` → `build.py` → 启动 → `scan_qt_log.py`（无新 QML warning）→ 必要时 `git checkout HEAD -- .harness/journal/INDEX.md` → `harness_check.py`。

- **M-B1 基底重皮（可跑切片）**：整页 root 换暗玻璃 slab（§4.1）+ token 迁移到 `ml`（§5.3）。旧布局仍在，但已暗霓虹。咬合 F-B1。
- **M-B2 月视图（核心切片）**：顶栏（关阴影）+ 周一表头 + 发丝栅格（抬 `MemoDatePicker`，§4.2）。咬合 F-B2。
- **M-B3 事件胶囊 + 右栏**：cell 胶囊（cap3+more，§4.3）+ 右栏 选中日卡/表单/议程（§1.10）。咬合 F-B3。
- **M-B4 左栏**：brand card + 4 视图 tab + 2×2 统计芯片。咬合 F-B4。
- **M-B5 保留态视觉 + 动效**：右栏 待办/记录/纪念 三态暗霓虹化 + 照片 cell 态（§5.5）+ 开合动效 + toast + light-mode 一遍。咬合 F-B5/F-B6。
- **M-B6（延后/可选）**：备忘→日历同步工具 + success 光环/粒子（§6）。咬合 F-B7。

**验证法（每批）**：圆角漏边用 `RoundedFrame` + **magenta #FF00FF 3× 超采样逐像素**门——**仅对不透明层**；
半透明栅格/辉光/胶囊用肉眼（magenta 会透过 alpha 假报）。开合/hover/选中交互用真机 `run.cmd` 走查（Win32 自动化不稳）。

---

## §9 与既有文档关系

- 配套行为文档：`docs/calendar-refactor-functional-replication.md`（数据/状态/法规/验收/GAPS）。
- 技法字典：`docs/memory-lake-art-lighting-qml-cookbook.md`（token §2、打光 §3、渐变 §4、纹理 §5.3、RoundedFrame §5.7、easing §6.1）。
- 诚实天花板 + 漏边/超采样验证法：`docs/memory-lake-fidelity-gaps.md`。
- 结构母版：`docs/memory-lake-{home,memo}-render-pipeline-replication.md`（本文沿用其 §0–§9 文法）。
- 复用组件源码：`qml/desktop/memorylake/{MemoDatePicker,CalendarSyncList,GlassPanel,FrostCard,RoundedFrame,GlowCircle,GridTexture,SilkyFlickable,MemoToolbar,DetailPanel}.qml`；token 源 `MemoryLakeStyle.qml`。
- 重构目标：`qml/desktop/pages/DesktopCalenderPage.qml`（注意拼写 `Calender`）。
