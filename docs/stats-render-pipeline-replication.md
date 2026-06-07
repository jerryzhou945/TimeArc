# 统计页 · 渲染管线完全复刻分析（暗玻璃 / 图表 / chrome · 含降玻璃甜甜圈）

> 配套文档：`docs/stats-functional-replication.md`（行为/数据/复刻规则）、
> `docs/stats-backend-data-gaps.md`（后端缺口）。
> 设计稿真值：`MemoryLakeDesign/TimeArcDesign_v88.stripped.html`
> ——统计页 CSS（暗）`10705–11370`、DOM `14243–14465`、JS `15280–15413`；
> 饼 `11137–11175`、light 覆盖 `13056–13072 / 13547–13559`；首页占比饼参照 `13800–13860`。
> 既有技法字典：`docs/memory-lake-art-lighting-qml-cookbook.md`（cookbook，下记技法编号）。
> 诚实天花板：`docs/memory-lake-fidelity-gaps.md`（QML 无逐元素实时 backdrop-blur 的总账）。
> 重构目标：`qml/desktop/pages/DesktopStatsPage.qml`。Track **B**。

---

## §0 核心结论（先给判断，再给证据）

1. **重皮，不是绿地**。`DesktopStatsPage.qml` 已存在（奶油浅色 dashboard），要整块换成
   v88 暗玻璃 + 图表网格。范式 100% 沿用日历页 PR#22 的零-C++ 暗玻璃重皮
   （`MemoryLakeStyle` 令牌 + `RoundedFrame` + `GlassPanel`/`FrostCard`）。
2. **最高杠杆复用 = 首页甜甜圈 `DailyUsageShare.qml`**。v88 统计饼与首页占比饼**同构**
   （Canvas 真实扇区 + 16px 中心孔 + 中心总时数 + 同色图例）。复用它 + 加「降玻璃」开关
   即得统计饼（用户要清晰版本）。
3. **v88 统计色 ≈ 既有令牌全命中**：aqua `#9FE7EE`=`ml.aqua`、violet `#9B8BFF`=`ml.violet`、
   gold `#FFE6A3`=`ml.shareGold`、pink `#FF7A9A`=`ml.sharePink`、slate `#6F7C91`=`ml.shareOther`、
   辉光青 `rgba(142,223,255)`=`ml.glowCyan(#8EDFFF)`、发丝 `ml.gridLine`、页底
   `rgba(20,24,34,.94)→(8,11,18,.94)`=`ml.calPageTop(#141822)→calPageBottom(#080B12)`、
   缓动 `cubic-bezier(.18,.9,.2,1)`=`ml.easeSnappy`。**仅 4 个新令牌待加**（§1 末）。
4. **诚实天花板 ~92%**。唯一不能 1:1 = `backdrop-filter: blur(30px)`（QML 无逐元素实时
   背板模糊）→ 用不透明近黑渐变替代，与日历页同处置。其余暗玻璃/图表/动画可高保真。

---

## §1 v88 统计页渲染管线 · 全层解剖（终值 + 行号）

> 规则同日历/备忘文档：CSS 分层逐块给**终值**，下方配 `- **QML**：…` 落地映射。

### §1.1 整页基底 `.stats-page`（10705–10725；light 13xxx）

```css
.stats-page{
  position:absolute; inset:18px; z-index:36; border-radius:26px;
  background:
    radial-gradient(circle at 13% 0%, rgba(142,223,255,.10), transparent 35%),
    radial-gradient(circle at 88% 14%, rgba(155,139,255,.12), transparent 38%),
    linear-gradient(180deg, rgba(20,24,34,.94), rgba(8,11,18,.94));
  border:1px solid rgba(255,255,255,.11);
  box-shadow:0 36px 120px rgba(0,0,0,.58), inset 0 1px 0 rgba(255,255,255,.06);
  backdrop-filter:blur(30px) saturate(125%);
}
```
- **QML**：fullBleed 下由 Shell 关掉外框/玻璃（`DesktopAppShell.qml:765/785`，加 `"stats"`
  到 `fullBleedPage`）。页内底 = `Rectangle` 竖渐变 `ml.calPageTop→calPageBottom`（**替代
  backdrop-filter**，技法 cookbook §2 蓝黑深度坡，🔴 天花板见 §7）；双角 `GlowCircle`
  aqua(13%,0%)/violet(88%,14%)；外缘 1px = `ml.panelBorder`。`box-shadow` 软投影用
  `MultiEffect` shadow（仅焦点面，`ml.shadowSoftOpacity`）。

### §1.2 页方格底纹 `.stats-page::before`（10733–10743）

```css
background:
  linear-gradient(90deg, rgba(255,255,255,.035) 1px, transparent 1px),
  linear-gradient(0deg, rgba(255,255,255,.030) 1px, transparent 1px);
background-size:42px 42px; opacity:.24;
```
- **QML**：`GridTexture{ cell:42; lineColor:ml.gridLine; textureOpacity:0.24 }`（复用，技法
  cookbook §4.x）；置于背景渐变之上、内容之下；圆角处用 `RoundedFrame` round-clip（G7）。

### §1.3 双栏壳 `.stats-shell` + 左栏 `.stats-side`（10745–10868）

```css
.stats-shell{ height:100%; display:grid; grid-template-columns:250px 1fr; gap:16px; padding:18px; }
.stats-side{ border-radius:22px; background:rgba(255,255,255,.045);
  border:1px solid rgba(255,255,255,.08); box-shadow:inset 0 1px 0 rgba(255,255,255,.05); }
.stats-brand{ background:radial-gradient(circle at 8% 0%, rgba(142,223,255,.16), transparent 42%), rgba(0,0,0,.18);
  border:1px solid rgba(142,223,255,.12); }
.stats-kicker{ color:#9FE7EE; font-size:11px; font-weight:850; letter-spacing:.7px; text-transform:uppercase; }
```
- **QML**：`RowLayout`（或 Grid）250+1fr，`spacing:16`。左栏 = `GlassPanel`/`FrostCard`
  （`ml.cardBg` `ml.cardBorder` + 顶沿 `ml.edgeHighlight`）。品牌块 = 角向 `GlowCircle`
  aqua + `Qt.rgba(0,0,0,.18)`。kicker = `ml.glowCyan`（注意 css 用 `#9FE7EE`=aqua，统一
  取 `ml.aqua` 即可），全大写 `font.capitalization:Font.AllUppercase`。

### §1.4 范围 Tab `.stats-range-tab`（10801–10847）

```css
.stats-range-tab{ height:46px; border:1px solid transparent; border-radius:15px;
  display:grid; grid-template-columns:30px 1fr; gap:10px; color:rgba(235,245,255,.58); }
.stats-range-tab.active{ background:rgba(142,223,255,.12); border-color:rgba(142,223,255,.22); color:rgba(245,250,255,.94); }
.stats-range-tab i{ width:30px;height:30px;border-radius:11px; background:rgba(255,255,255,.06); }
```
- **QML**：`Repeater[周/月/年]` → `Rectangle` 46px，active 用 `ml.accentSoft`/`ml.accentSoftBorder`
  （= aqua .12/.22 同族），左侧 30px 字符徽。范式直接抄日历三视图 Tab。

### §1.5 顶栏 `.stats-topbar` + ghost 按钮（10877–10923）

```css
.stats-topbar{ display:grid; grid-template-columns:1fr auto auto; gap:12px; align-items:center;
  background:rgba(255,255,255,.045); border:1px solid rgba(255,255,255,.08); border-radius:22px; }
.stats-date-switch button, .stats-close{ height:38px; border-radius:13px;
  border:1px solid rgba(255,255,255,.10); background:rgba(255,255,255,.065); color:rgba(245,250,255,.86); }
```
- **QML**：标题列（h3 23px + p 12px）+ 期次三按钮（‹ / 本期 / ›）+ 返回首页。按钮 = ghost
  玻璃，复用 `ml.calGhostBg/calGhostHover/calGhostBorder/calGlyph`（日历 nav 同款）。

### §1.6 卡片 `.stats-card`（10951–11010；span 网格 10982–10988）

```css
.stats-card{ border-radius:22px;
  background:radial-gradient(circle at 0% 0%, rgba(142,223,255,.08), transparent 42%), rgba(255,255,255,.045);
  border:1px solid rgba(255,255,255,.08); box-shadow:inset 0 1px 0 rgba(255,255,255,.04);
  padding:16px; min-height:132px; overflow:hidden; }
.stats-card::before{ /* 26px 方格 */ background-size:26px 26px; opacity:.22; }
.stats-grid{ display:grid; grid-template-columns:repeat(12, minmax(0,1fr)); gap:14px; }
```
- **QML**：`StatsGrid` = 12 列 `GridLayout`（`columnSpacing/rowSpacing:14`），卡 span 用
  `Layout.columnSpan`。卡片 = `FrostCard`（`ml.cardBg` + 左上角 `GlowCircle` aqua .08 + 顶沿
  edge-light）+ 内 `GridTexture{cell:26;opacity:.22}`（RoundedFrame 收圆角）。

### §1.7 指标卡 head/value/change + badge（11012–11043）

```css
.stats-metric-value{ font-size:30px; font-weight:920; letter-spacing:-1px; color:rgba(245,250,255,.96); }
.stats-metric-change{ color:rgba(125,255,178,.78); }   /* 升 */
.stats-metric-change.down{ color:rgba(255,122,154,.78); } /* 降 */
.stats-badge{ height:28px; border-radius:999px; background:rgba(142,223,255,.10);
  border:1px solid rgba(142,223,255,.16); color:rgba(210,245,255,.86); }
```
- **QML**：值 = `Text` 30px weight 900（`tnum` 等宽数字）。change 升=**新令牌 `ml.changeUp`**
  `rgba(125,255,178,.78)`、降=`ml.changeDown`（已存在 `#FF8FB5`，或精确加 `rgba(255,122,154,.78)`）。
  badge = aqua .10 pill（`ml.accentSoft` 同族）。

### §1.8 柱状图 `.stats-bar-chart`（11045–11095）

```css
.stats-bar-chart{ height:190px; display:flex; align-items:flex-end; gap:10px; padding-top:14px; }
.stats-bar{ flex:1; border-radius:12px 12px 6px 6px;
  background:linear-gradient(180deg, rgba(159,231,238,.88), rgba(155,139,255,.58));
  box-shadow:0 0 18px rgba(142,223,255,.22); transform-origin:bottom;
  animation:statsBarGrow .68s cubic-bezier(.18,.9,.2,1) both; }
@keyframes statsBarGrow{ from{transform:scaleY(.15);opacity:.35} to{transform:scaleY(1);opacity:1} }
.stats-bar::after{ content:attr(data-label); }   /* 底标 */
.stats-bar::before{ content:attr(data-value); opacity:0 } /* hover 顶显 */
```
- **QML**：`Row` 底对齐 + `Repeater` `Rectangle`，高 = `parent.height * ratio`，圆角
  `topLeft/topRight 12, bottom 6`（用 RoundedFrame 或 `Rectangle radius` + 底压条），
  渐变 `ml.aqua(.88)→ml.violet(.58)`，外晕 `0 0 18px aqua .22`（GlowCircle/MultiEffect）。
  入场 `NumberAnimation scaleY .15→1 .68s ml.easeSnappy`。label 常显、value hover（MouseArea）。

### §1.9 折线/面积 `.stats-line-chart`（11097–11135）

```css
.stats-line-chart .line{ fill:none; stroke:#9FE7EE; stroke-width:3;
  filter:drop-shadow(0 0 8px rgba(159,231,238,.45)); stroke-dasharray:520; stroke-dashoffset:520;
  animation:drawStatsLine .9s ease forwards; }
.stats-line-chart .area{ fill:url(#statsLineGradient); opacity:.58; } /* aqua.36→violet.0 竖渐变 */
```
- **QML**：`Canvas` 画 area（`fillStyle` 竖渐变 aqua .36→透明）+ line（`strokeStyle` ml.aqua
  width 3，外加 GlowCircle/MultiEffect 描边辉光）。描边动画用 `Canvas` 逐帧推进 path 长度，
  或简单 `opacity`/裁切揭示（drawStatsLine 等价）。3 条 gridline = 半透白横线。

### §1.10 ★甜甜圈 `.stats-pie`（11137–11175；light 13056–13072 / 13547–13559）

```css
.stats-pie{ width:156px; height:156px; border-radius:50%;
  background:conic-gradient(#9FE7EE 0 126deg,#9B8BFF 126 218deg,#FFE6A3 218 292deg,#FF7A9A 292 334deg,#6F7C91 334 360deg);
  box-shadow:0 0 0 1px rgba(255,255,255,.07), 0 0 32px rgba(142,223,255,.13), inset 0 0 24px rgba(0,0,0,.22);
  animation:statsPieIn .62s cubic-bezier(.18,.9,.2,1) both; }
.stats-pie::before{ inset:16px; border-radius:50%;
  background:linear-gradient(180deg, rgba(20,24,34,.96), rgba(10,13,21,.94)); box-shadow:inset 0 1px 0 rgba(255,255,255,.07); }
.stats-pie::after{ content:attr(data-center); font-size:21px; font-weight:900; }
@keyframes statsPieIn{ from{opacity:0;transform:rotate(-22deg) scale(.84);filter:blur(4px)} to{opacity:1;transform:rotate(0) scale(1);filter:blur(0)} }
```
- **QML（核心复用）**：= 首页 `DailyUsageShare.qml`（Canvas 真实扇区 `arc` + `destination-out`
  打孔 + 中心 `data-center` 字 + 同色图例）。v88 统计饼的外晕 `0 0 32px aqua .13` **本就比首页
  霓虹弱**——这正是「降玻璃」目标值。中心孔 inset16 竖渐变 = `ml.donutHoleTop→donutHoleBottom`。
  入场 `statsPieIn`（rotate-22→0 / scale.84→1 / blur 4→0）。**降玻璃配方见 §4.1 + §5.1**。

### §1.11 图例 / 热力 / 排行 / 洞察 / 按钮 / toast（11177–11352）

```css
.heat-cell.lv1{background:rgba(142,223,255,.18)} .lv2{rgba(142,223,255,.32)}
.lv3{background:rgba(155,139,255,.42)} .lv4{background:rgba(255,230,163,.50)}
.stats-insight{ background:linear-gradient(135deg, rgba(142,223,255,.09), rgba(155,139,255,.075)), rgba(0,0,0,.13);
  border:1px solid rgba(142,223,255,.11); }
.stats-btn.primary{ background:linear-gradient(135deg, rgba(142,223,255,.82), rgba(155,139,255,.78)); color:rgba(4,8,14,.92); }
.stats-toast{ background:rgba(14,18,26,.86); backdrop-filter:blur(14px); border:1px solid rgba(142,223,255,.14); }
```
- **QML**：图例 = `Repeater` 行（GlowCircle 同色点 + 名 + %）；热力 = `Grid 14 列` Repeater
  单元格，等级色 = **新令牌**或 `Qt.rgba(ml.aqua.r,…,.18/.32)`、`Qt.rgba(ml.violet…,.42)`、
  `Qt.rgba(ml.shareGold…,.50)`（token-derived，符合 G1）；洞察 = 135° aqua/violet 浅染卡
  （沿用 DailyUsageShare 底部洞察胶囊范式）；主按钮 = aqua→violet 亮渐变 + `ml.calBtnInk`
  近黑墨字；toast = `ml.calToastBg`（= rgba(14,18,26,.86)）+ 边 aqua .14（backdrop blur 14
  → 不透明底替代，🔴 同 §7）。

### §1.x 需新增的 `MemoryLakeStyle` 令牌（4 个）

| 令牌 | 值（暗） | 用处 |
|---|---|---|
| `changeUp` | `rgba(125,255,178,.78)` | 指标卡升幅绿（`stats-metric-change`） |
| `statsBarTop/统一用 aqua` | （沿用 `ml.aqua` .88 / `ml.violet` .58） | 柱渐变（无需新令牌，token 派生） |
| `heatLv*` | aqua .18/.32、violet .42、gold .50 | 热力四级（可 token 派生，免新令牌） |
| `lineAreaTop` | `aqua .36` | 折线面积顶（token 派生 aqua + alpha） |

> 实操：仅 `changeUp` 必须新增；其余皆可 `Qt.rgba(ml.<base>…, alpha)` 派生，零内联 hex（G1）。

---

## §2 绿地就要搭对的管线 · 根因清单（pitfall 表）

| ID | CSS 字面直译的坑 | 正确 QML 做法 | 来源 |
|---|---|---|---|
| M0 | `backdrop-filter:blur(30/14)` 直接照搬 | QML 无逐元素实时背板模糊；用不透明近黑渐变（`ml.calPageTop→Bottom`）替代，toast 用不透明底 | 10718/11342 |
| M1 | `conic-gradient` 当成可直接画的渐变 | conic 在 QML 须 Canvas `arc` 逐扇区画（DailyUsageShare 已实现）；别用 `Gradient`（只支持线性/径向） | 11142 |
| M2 | `clip` 圆角卡裁方格 | `clip:true` 只裁矩形→圆角戳方角；用 `RoundedFrame` round-clip（layer+MultiEffect mask） | 10962 + G7 |
| M3 | `::before/::after` 内容（label/value/center）当真实节点 | QML 用独立 `Text` 子项 + `MouseArea` 控 hover 显隐，别指望伪元素 | 11070/11161 |
| M4 | `box-shadow 0 0 Npx` 外晕直接当 border | 用 `GlowCircle`（径向透明衰减）或 `MultiEffect` blur 源副本，非 `border` | 11059/11147 |
| M5 | `filter:drop-shadow`/`blur()` 关键帧逐字搬 | 入场 blur 用 `MultiEffect` 一次性或省略；持续辉光用 GlowCircle，别每帧 filter | 11122/11173 |
| M6 | 柱/饼动画 `transform:scaleY/rotate` 当 css 写 | QML `NumberAnimation`（scaleY/rotation/scale）+ `transformOrigin`；缓动统一 `ml.easeSnappy` | 11062/11149 |
| M7 | 热力 `aspect-ratio:1` 直接套 | QML 无 aspect-ratio；用 `width:cellW; height:cellW`（GridLayout 等分宽 → 绑高） | 11224 |

---

## §3 HTML 层 → QML 技法 → 是否需 shader 对照表

| HTML 层 | 终值要点 | QML 技法 | 需 .qsb? |
|---|---|---|---|
| 整页底 + 角辉 | 近黑竖渐变 + 双径向 | `Rectangle gradient` + `GlowCircle`×2 | 否 |
| 42/26px 方格 | 双向 1px 发丝 | `GridTexture` + `RoundedFrame` | 否 |
| 玻璃卡/左栏/顶栏 | white .045 + inset 高光 | `FrostCard`/`GlassPanel` + edge-light 对 | 否 |
| 指标值/badge/change | 字号字重 + 升降色 | `Text` + `ml` 令牌 | 否 |
| 柱状图 | 渐变柱 + scaleY 入场 + 外晕 | `Repeater Rectangle` + `NumberAnimation` + GlowCircle | 否 |
| 折线/面积 | 描边 + 竖渐变面积 + 描边动画 | `Canvas`（path + gradient）逐帧揭示 | 否 |
| ★甜甜圈 | conic 扇区 + 中心孔 + 中心字 + 外晕 | **复用 `DailyUsageShare`**（Canvas）+ 降玻璃开关 | 否 |
| 图例 | 同色霓虹点 + 名 + % | `Repeater` 行 + `GlowCircle` | 否 |
| 热力图 | 14 列 + lv0-4 亮度 | `Grid` + `Repeater Rectangle`（token-derived 等级色） | 否 |
| 排行 | 图标 + 名 + N 次 + 时长 + 进度 | `ListView`/`Repeater` + `AppVisual.js` + `image://appicon` | 否 |
| 洞察/按钮/toast | 浅染卡 / 亮渐变 / 胶囊 | `Rectangle gradient` + `ml.calBtnInk`/`calToastBg` | 否 |

> **结论：全页零 shader（零 .qsb）**。所有暗玻璃/图表/动画用既有 QML 元件即可，
> 唯一非 1:1 是 backdrop-filter（不透明替代）。

---

## §4 核心技法详解（含代码骨架）

> 仅给关键骨架，token 全部来自 `MemoryLakeStyle`（下记 `ml`）。

### §4.1 ★降玻璃甜甜圈（DailyUsageShare 复用 + clarity 开关）

给 `DailyUsageShare.qml` 增一个**清晰度/玻璃强度**入参，统计页传低值；首页不传（默认满玻璃）：

```qml
// DailyUsageShare.qml 新增
property real glassStrength: 1.0   // 1.0=首页满霓虹；0.0=纯扁平。统计页用 ~0.45
readonly property real gs2: gs * glassStrength   // gs 仍 = style.glowStrength（昼夜）

// (1) 整体 aqua 柔晕：glowOpacity: 0.16 * gs   → 0.16 * gs2
// (2) 彩色霓虹外晕 MultiEffect（最重一层）：
//     visible: hasData && gs2 > 0.25            // 阈值从 0.6 降，低玻璃时仍留一丝
//     opacity: 0.85 * glassStrength             // 0.85 → ~0.38
//     blurMax: Math.round(28 * glassStrength)   // 28 → ~12（核心：把毛玻璃糊度收一半多）
// (3) 呼吸光环 ring：visible: hasData && glassStrength > 0.6   // 统计页关掉（清晰优先）
// (6) 中心孔顶 aqua 高光：glowOpacity: 0.14 * gs2
// (7) 中心总时数发光副本 MultiEffect：blurMax: Math.round(18 * glassStrength) // 18 → ~8
// 扇区 Canvas / 外缘 1px 描边 / 中心孔渐变 / 图例：原样保留（清晰主体不动）
```

统计页用法：
```qml
DailyUsageShare {
    style: ml
    glassStrength: 0.45            // 「适当降低、不完全丢弃」——保留约一半霓虹外晕
    share: viewModel.categoryShare // 真实分类占比（week/year 版 usageShare）
    total: viewModel.totalText     // 该 range 真实总时数（= v88 data-center）
}
```
要点：扇区、中心孔、外缘描边、中心字、图例**全程清晰**；只把 (2)(7) 的 `MultiEffect`
模糊半径与不透明度、(1)(6) 的 `GlowCircle` 不透明度、(3) 呼吸环按 `glassStrength` 收一档。
v88 统计饼自身外晕（`aqua .13`）本就弱于首页（`aqua 0.16*gs`），`glassStrength≈0.45` 即对齐。

### §4.2 柱状图骨架

```qml
Row {                                   // .stats-bar-chart：底对齐
    height: 190; spacing: 10; layoutDirection: Qt.LeftToRight
    Repeater {
        model: viewModel.bars           // [{label, ratio(0..1), valueText}]
        delegate: Item {
            width: (parent.width - 10*(count-1)) / count; height: parent.height
            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width
                height: parent.height * modelData.ratio
                radius: 6; transformOrigin: Item.Bottom
                gradient: Gradient {    // aqua .88 → violet .58
                    GradientStop { position: 0; color: Qt.rgba(ml.aqua.r,ml.aqua.g,ml.aqua.b,0.88) }
                    GradientStop { position: 1; color: Qt.rgba(ml.violet.r,ml.violet.g,ml.violet.b,0.58) }
                }
                NumberAnimation on scaleY { from: 0.15; to: 1; duration: 680; easing.bezierCurve: ml.easeSnappy }
                // 顶角 12 用 RoundedFrame 或顶部额外圆角条；底 6 已由 radius 给
            }
        }
    }
}
```

### §4.3 热力图骨架（等级量化 = 派生，阈值见缺口 A-2）

```qml
Grid {
    columns: 14; rowSpacing: 5; columnSpacing: 5
    Repeater {
        model: viewModel.heatCells      // [{level:0..4}]，QML 由 dailySecondsForMonth 量化
        delegate: Rectangle {
            width: (parent.width - 13*5)/14; height: width      // M7：手动等高
            radius: 6
            color: [ ml.trackBg,
                     Qt.rgba(ml.aqua.r,ml.aqua.g,ml.aqua.b,0.18),
                     Qt.rgba(ml.aqua.r,ml.aqua.g,ml.aqua.b,0.32),
                     Qt.rgba(ml.violet.r,ml.violet.g,ml.violet.b,0.42),
                     Qt.rgba(ml.shareGold.r,ml.shareGold.g,ml.shareGold.b,0.50) ][modelData.level]
        }
    }
}
```

### §4.4 折线/面积骨架（Canvas）

```qml
Canvas {
    onPaint: {
        var ctx = getContext("2d"); ctx.reset();
        var g = ctx.createLinearGradient(0,0,0,height);          // area 竖渐变
        g.addColorStop(0, Qt.rgba(ml.aqua.r,ml.aqua.g,ml.aqua.b,0.36));
        g.addColorStop(1, Qt.rgba(ml.violet.r,ml.violet.g,ml.violet.b,0));
        // 1) 画 area path（折线 + 底封闭）fillStyle=g
        // 2) 画 line path（同折线）strokeStyle=ml.aqua, lineWidth=3
    }
    // 描边动画：用一个 0→1 的 progress 属性裁出可见段，requestPaint() 跟进（等价 drawStatsLine）
}
```

---

## §5 架构决策（最高杠杆）

1. **饼 = 复用 + 一个 `glassStrength` 入参**（§4.1）。零新组件、零 C++，且首页满玻璃不受影响。
   这是「降玻璃但不丢玻璃」的最小改动落点。
2. **全幅暗玻璃 = 复用日历重皮范式**：fullBleedPage 加 stats + `MemoryLakeStyle` + RoundedFrame
   + GlassPanel/FrostCard + GridTexture + GlowCircle，零 C++、零 shader。
3. **图表全用既有元件**（Repeater/Canvas/GlowCircle），不引图表库，不写 .qsb。
4. **令牌只补 1 个**（`changeUp`），其余 token 派生，杜绝色表漂移（G1）。
5. **数据装配在功能文档 §3 收口**；本文只管像素，不重复数据逻辑。

---

## §6 自写 shader：清单与构建路径

**无**。全页零 `.qsb`、零自定义 `ShaderEffect`。模糊一律 `MultiEffect`（入场/降玻璃外晕/
中心字发光），背板模糊用不透明渐变替代（§7）。若后续要更软的页底辉光，最多再加 `GlowCircle`，
仍无需 shader。

---

## §7 复刻分级 · 诚实天花板

| 层 | 等级 | 天花板 | 说明 |
|---|---|---|---|
| 整页底 / 角辉 / 方格 | 🟢 | ~98% | 渐变 + GlowCircle + GridTexture 高保真 |
| 玻璃卡 / 左栏 / 顶栏 chrome | 🟡 | ~92% | white .045 玻璃片 + edge-light；缺真实背板模糊（见 🔴） |
| ★甜甜圈扇区 / 中心孔 / 图例 | 🟢 | ~96% | Canvas 真实扇区，1:1 几何 |
| ★甜甜圈降玻璃外晕 | 🟢 | 100% | **有意降低**，正中「清晰版」诉求；保留约一半霓虹 |
| 柱 / 折线 / 入场动画 | 🟢 | ~95% | NumberAnimation/Canvas 等价 statsBarGrow/drawStatsLine/statsPieIn |
| 热力等级 | 🟢 | ~98% | token 派生四级；唯阈值口径是产品决策（A-2），非渲染问题 |
| `backdrop-filter blur(30/14)` | 🔴 | ~70% | QML 无逐元素实时背板模糊 → 不透明近黑渐变替代（与日历同账） |

> **总体 ~92%**。唯一系统性损失是 backdrop-filter（全 app 一致的已知账，`fidelity-gaps.md`）；
> 降玻璃饼是**主动**降，不计损失。

---

## §8 实施批次（M-B，与功能文档 F-B 咬合）

> 收尾每批同功能文档 §6 ritual：kill exe → `build.py` → 启动 → `scan_qt_log`
> → record_error → harness_check。**验证法**：品红底 3× 超采样逐像素门**只对不透明层**
> （玻璃/辉光层用普通截图会误判）；全幅页 PrintWindow-by-PID 抓**本实例**（min 1280×720 + 最大化）。

- **M-B0 页壳**：fullBleedPage 加 stats + 暗玻璃背景三件套 + 250+1fr 壳 + 顶栏 chrome。（咬合 F-B0）
- **M-B1 卡架**：StatsGrid 12 列 + FrostCard + 卡内 26px 方格（RoundedFrame）。（咬合 F-B1）
- **M-B2 指标卡**：值/badge/升降色（新令牌 changeUp）。（咬合 F-B2）
- **M-B3 图表**：BarChart + ★降玻璃饼（DailyUsageShare glassStrength）+ LineArea Canvas + Heatmap。（咬合 F-B3）
- **M-B4 排行 + 图例 + 洞察卡**：复用 AppVisual.js + GlowCircle 图例 + 浅染洞察。（咬合 F-B4/F-B5）
- **M-B5 交互动效**：statsSectionIn 切换、toast、按钮态、hover tip。（咬合 F-B6）
- **M-B6 昼夜 + 响应式**：night/day 校验、≤1200 左栏折叠、min 1280×720 抓图门。（咬合 F-B7）

---

## §9 与既有文档关系

- **配套**：`docs/stats-functional-replication.md`（行为/数据/复刻规则·标准·步骤）、
  `docs/stats-backend-data-gaps.md`（后端缺口）。
- **技法字典 / 天花板**：`docs/memory-lake-art-lighting-qml-cookbook.md`、
  `docs/memory-lake-fidelity-gaps.md`、`docs/calendar-refactor-render-pipeline-replication.md`
  （暗玻璃重皮范式直接来源）。
- **复用源**：`qml/desktop/memorylake/DailyUsageShare.qml`（饼，加 glassStrength）、
  `GridTexture.qml`、`GlowCircle.qml`、`RoundedFrame.qml`、`GlassPanel.qml`、`FrostCard.qml`、
  `MemoryLakeStyle.qml`（令牌，加 `changeUp`）、`qml/desktop/components/AppVisual.js`。
- **重构目标**：`qml/desktop/pages/DesktopStatsPage.qml`；入口 `qml/desktop/DesktopAppShell.qml`。
- **收尾建议**：把本三文档登进 `CLAUDE.md` Product Context + `.harness/rules/04` 索引。
