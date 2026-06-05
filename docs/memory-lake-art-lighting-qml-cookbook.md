# Memory Lake 美术 / 光照 / 质感 —— HTML → QML 复刻知识库

> 本文是把 `MemoryLakeDesign/TimeArcDesign_v88.html` 的视觉语言（科技感、光照、恰到好处的质感）
> **建设性地**搬进 Qt6/QML 的「怎么做」手册。它是配方书（cookbook），不是清单。

---

## 0. 这份文档是什么 / 怎么用

**研究对象（scope）**
只覆盖 `section.memory-window#memoryWindow`（= TimeArc App 本体）及其全部子层。
v88.html 为了截图测试，在窗口背后画了一整套 Win11 桌面外壳（`.desktop` / `.desktop-icons` /
`.taskbar` / 壁纸 base64）。**这些一律忽略**，不在复刻范围内。

**来源**
- 通读 `TimeArcDesign_v88.html` 的 `<style>`（约 13,636 行 CSS）。CSS 是**分层覆盖**的：base
  组件规则 → 中段覆盖 → Memory-Lake `:root` + `!important` 块（约 1513 起）→ V15/V22/V25/V60–V88
  等迭代块。**本文所有 CSS 值都是「穿过所有覆盖层之后的有效最终值（effective final）」**，不是
  base 行原值。这一点至关重要（见 §1）。
- 比对现有 `qml/desktop/memorylake/*.qml`（17 个组件，已落地了相当一部分技法）。

**与 `docs/memory-lake-fidelity-gaps.md` 的关系**
那份是「**哪些做不到 / 有多接近**」的诚实差距表（🟢≈1:1 / 🟡接近 / 🔴无法全复刻）。
本文是「**怎么做到**」的正向配方。两者互补，不重复：遇到保真天花板，本文只给一句结论并指向那份。

**阅读约定**
- CSS 代码块 = 设计稿有效最终值。
- QML 代码块 = Qt 6.11 真实 API，尽量映射到**已存在**的组件与其**真实属性名**；标 `// 建议新增` 的是
  还没落地、推荐补的。
- 强调色三角全文统一称 **aqua `#9FE7EE` / violet `#9B8BFF` / pink `#D88AAC`**。

---

## 1. 设计哲学：为什么「恰到好处」

整套界面是**一块漂浮在暗色桌面上的半透明深蓝黑「烟熏玻璃」**，遵循一个统一光模型：

> **一束来自正上方的柔性主光 + 两枚角落彩色辅光（左上 aqua、右上 violet）+ 又深又极柔的环境阴影。**
> 全程没有任何硬的方向性阴影——所有高度都读作「物体悬浮在雾里」。

四条让它「好看而不过」的克制原则，复刻时必须照搬：

1. **把霓虹调暗（soften the neon）。** base 行的发光本来很高饱和：角落辉光 base 是
   `rgba(106,237,255,.16)`、选中卡 base 是 `0 0 38px rgba(94,219,255,.28)`。ML / V-block **刻意**把它们
   降到 `.05–.07`。**复刻请用最终值，照搬 base 行会立刻变「太赛博、太亮」，失去恰到好处。**
2. **强调色当 tint，不当 flood。** 角落光、accent 渐变 alpha 普遍 `.05–.18`，是给玻璃染色，不是泛光。
3. **发光只在交互时醒来。** 静止态卡面 `box-shadow:none`、内层卡只有顶沿高光无投影。辉光、光环、
   扫光只在 `:hover / .is-selected / .running / .active` 时出现。
4. **冷色叙事 + aqua 主导。** 蓝黑深度坡是底；三角里 aqua 是「时间」语义主色（进度起点、选中、角落主光），
   violet 次要（进度终点、右上辅光、品牌渐变尾），pink 几乎只出现在渐变 / 分组 / 饼图扇区。

记住这四条，下面所有配方才有意义。

---

## 2. 设计令牌：单一事实源 → `MemoryLakeStyle.qml`

`:root` 的 `--ml-*` 全集（有效最终值）：

| token | 值 | 角色 |
|---|---|---|
| `--ml-bg-0` | `#05070D` | 最深 void / 页底 |
| `--ml-bg-1` | `#090D16` | 深度坡 1 |
| `--ml-bg-2` | `#0D1320` | 深度坡 2 |
| `--ml-bg-3` | `#121A2A` | 深度坡 3 / 最高不透明面 |
| `--ml-border` | `rgba(255,255,255,.075)` | 默认发丝边缘光 |
| `--ml-border-strong` | `rgba(255,255,255,.13)` | **更亮的底边**（底沿接住环境反弹光） |
| `--ml-text` | `rgba(255,255,255,.88)` | 主文字 |
| `--ml-text-2` | `rgba(255,255,255,.56)` | 次文字 |
| `--ml-text-3` | `rgba(255,255,255,.34)` | 弱文字 / 大写 kicker |
| `--ml-aqua` | `#9FE7EE` | 强调 1：左上主光、进度起点、选中/active |
| `--ml-violet` | `#9B8BFF` | 强调 2：右上辅光、进度终点、品牌渐变尾 |
| `--ml-pink` | `#D88AAC` | 强调 3：分组 / 饼图扇区（chrome 层不用） |
| `--ml-radius-lg/md/sm` | `28 / 22 / 16px` | 圆角坡 |
| `--ml-shadow-soft` | `0 24px 80px rgba(0,0,0,.46)` | 标准环境抬升阴影 |
| `--ml-shadow-focus` | `0 34px 90px rgba(0,0,0,.62)` | 聚焦抬升阴影（选中卡浮起） |

**现有 `MemoryLakeStyle.qml` 已经映射了大部分**（QtObject 单例，`night/day` 双主题）：
`aqua/violet/pink`、`stageBg`（=window-body `#070A11`）、`stageGlow1/2`（=角落光 aqua/violet）、
`panelBg/panelBorder/panelBorderStrong`、`cardBg/cardBorder`（tier-2 frost）、
`faceBg #0D121D /faceBorder/faceBorderActive`、`textPrimary/Secondary/Tertiary`、`trackBg`、
`accentSoft/accentSoftBorder/accentText`、`lockBg/Border/Text`、`ambientImageOpacity`、`glowStrength`、
`radiusPanel/Card/Inner = 18/18/16`。

**建议补全的 token**（当前 singleton 缺，做高保真光照时会用到）：

```qml
// 建议新增到 MemoryLakeStyle.qml —— 深度坡 + 显式阴影令牌
readonly property color bg0: night ? "#05070D" : "#F4EFE6"
readonly property color bg1: night ? "#090D16" : "#EFE7DA"
readonly property color bg2: night ? "#0D1320" : "#E8DECF"
readonly property color bg3: night ? "#121A2A" : "#E0D4C2"

// 环境阴影（黑 ↔ 蓝灰随主题翻），供 §3.4 的 ElevatedSurface 读取
readonly property color shadowAmbient: night ? "#000000" : "#4E6A88"
readonly property real  shadowSoftOpacity:  night ? 0.46 : 0.18   // --ml-shadow-soft
readonly property real  shadowFocusOpacity: night ? 0.62 : 0.24   // --ml-shadow-focus
```

**双主题范式**（已是 singleton 的写法）：白天 ≠ 重画，而是同一几何换值——
所有 `text-shadow → none`、环境阴影**黑 → 蓝灰** `rgba(75,104,132,…)`、accent **aqua → teal** `#1DAFD0 / #0891B2`、
顶沿高光 `.04–.12 → .62–.94`（瓷光）。`glowStrength`(1.0/0.45) 与 `ambientImageOpacity`(0.34/0.22) 就是这套主题分支的把手。

---

## 3. 光照系统（光照）

### 3.1 光模型总览

每个抬升面都合成**同一套三段式**「box-shadow 栈」：

1. **大而柔的黑色环境投影** `0 +Y +Z rgba(0,0,0,a)`，Y 为正（光在上，影朝下）。暗世界里 blur 半径
   70–130px、alpha .46–.72，高度**只靠投影的大小/深浅 + 顶沿亮度**来读。
2. **1px 顶沿高光** `inset 0 1px 0 rgba(255,255,255,a)`（暗 .04–.12 / 亮 .55–.94）= 主光打在上边缘斜面。
3. （状态时）**发丝环** `0 0 0 1px rgba(accent,a)` 和/或 **彩色辉光** `0 0 Z rgba(accent,a)`。

发丝白边（border）是**第二道边缘光**，沿轮廓一圈描出 catch-light。

### 3.2 四层环境光叠层（窗口内部）

从底到面，窗口里堆了四层「氛围光」。这是「记忆湖」气质的来源：

| 层 | CSS（最终值） | 作用 | QML 路径 |
|---|---|---|---|
| ① 桌面环境染 `.desktop::after` | `linear-gradient(180deg,rgba(0,0,0,.16),rgba(0,0,0,.48)), radial-gradient(circle at 48% 40%,rgba(120,154,190,.08),transparent 36%)` | 窗口**坐落**的那片冷蓝灰 ambient | 窗口背后一张 Rectangle + 一枚淡 `GlowCircle` |
| ② `.app-bg#appBg` | `opacity .34; filter:blur(42px) saturate(.95) brightness(.86); transform:scale(1.18)` | 选中记忆海报放大模糊去饱和后的**色彩晕染**，随浏览交叉淡变 | `Image` + `layer.effect: MultiEffect{ blur, saturation, brightness }`，`scale 1.18`，`Behavior on opacity 350ms` |
| ③ `.memory-window::before` | 角落 aqua+violet 辐射光 + 竖直暗幕 `linear-gradient(180deg,rgba(5,8,14,.86),rgba(8,11,18,.90))` | 主光照（见 §3.3） | RadialGradient/GlowCircle 叠在 z 最底 |
| ④ `.memory-window::after` | `rgba(2,4,8,.12)` + `backdrop-filter:blur(6px)` | 把①②③统一磨成「漫射光」而非清晰图像 | 一张薄黑 Rectangle（backdrop-blur 见 §3.8） |

现成参照：`AmbientBackground.qml`（窗口级氛围底）、`MemoryLakeStyle.ambientImageOpacity`（=层②的 .34）。

### 3.3 角落辅光（aqua 左上 + violet 右上）—— 招牌

```css
/* .memory-window::before 有效最终值（V15）*/
background:
  radial-gradient(circle at 8% 0%,  rgba(159,231,238,.065), transparent 28%),
  radial-gradient(circle at 95% 5%, rgba(155,139,255,.055), transparent 30%),
  linear-gradient(180deg, rgba(5,8,14,.86), rgba(8,11,18,.90));
```

QML 里 `Rectangle.gradient` **只支持线性**（`Gradient` + `orientation`），辐射光要换实现。三条路，按性价比：

**路 A（推荐，最省）：模糊实心圆 = `GlowCircle.qml`（已存在）。**
一张实心圆经高斯模糊得柔边发光，叠到角落即可。注意**角落光若被父层硬角 `clip` 掉一半会很难看**——
`AmbientBackground.qml` 的注释正是为此把光**居中**而非贴角。贴角时改用 `RoundedFrame` 包裹或让光圆心落在角外：

```qml
// 左上 aqua 角落光：圆心落在窗口角外，只让 1/4 透进来
GlowCircle {
    width: 360; height: 360
    x: -120; y: -120                     // 圆心在窗口左上角之外
    glowColor: style.aqua
    glowOpacity: 0.065 * style.glowStrength
    blurAmount: 1.0
}
```

**路 B（最准）：`QtQuick.Shapes` 的 `RadialGradient`。**

```qml
import QtQuick.Shapes
Shape {
    anchors.fill: parent
    ShapePath {
        strokeWidth: 0
        fillGradient: RadialGradient {
            centerX: parent.width * 0.08; centerY: 0
            centerRadius: parent.width * 0.28
            focalX: centerX; focalY: centerY
            GradientStop { position: 0; color: Qt.rgba(0.62,0.90,0.93, 0.065) }
            GradientStop { position: 1; color: "transparent" }
        }
        PathRectangle { width: parent.width; height: parent.height } // Qt6.x: 或用 startX/startY+PathLine 画矩形
    }
}
```

**路 C：烘焙 PNG 角落光**贴图。最稳、最省 GPU，但失去随主题调色的灵活。
> 现状选择：`GlowCircle`（路 A）。多枚辐射光叠加时它最廉价。

### 3.4 高度分层 —— `ElevatedSurface` 配方表

把全 app 的阴影收敛成**四档高度**，做成一个可复用组件（强烈建议，能统一全部面板气质）：

| 档 | 典型选择器 | 阴影栈（暗模式有效值） | 读感 |
|---|---|---|---|
| **Resting** 静止 | tier-2 内层卡 `.profile/.overview/.note` | `inset 0 1px 0 rgba(255,255,255,.035)`（**只有顶沿，无投影**） | 嵌进父面，齐平 |
| **Raised** 抬升 | 三栏 `.sidebar/.main-panel/.right-panel` | `inset 0 1px 0 rgba(255,255,255,.04), 0 24px 80px rgba(0,0,0,.46)`（`--ml-shadow-soft`） | 浮在底板上 |
| **Floating** 漂浮 | 弹层 `.summary-shell/.settings-page/.calendar-page` | `0 36–44px 110–130px rgba(0,0,0,.58–.68), inset 0 1px 0 rgba(255,255,255,.055)` | 盖在 app 之上 |
| **Focused** 聚焦 | 选中卡 `.card.is-selected` | `--ml-shadow-focus 0 34px 90px rgba(0,0,0,.62)` + `translateY(-6px)` + 微 aqua 环 | 浮到最高 |

QML 高保真做法 —— `QtQuick.Effects.MultiEffect` 的阴影：

```qml
// 建议新增：ElevatedSurface.qml
import QtQuick
import QtQuick.Effects
Item {
    id: surf
    property MemoryLakeStyle style
    property int tier: 1                 // 0 Resting / 1 Raised / 2 Floating / 3 Focused
    property color accent: "transparent" // Focused 时给 aqua
    default property alias content: body.data

    // 阴影档位表（与上表一一对应）
    readonly property var _blur:   [0.0, 0.55, 0.75, 0.62]   // 归一化 0..1（× blurMax）
    readonly property var _yoff:   [0,   24,   40,   34]
    readonly property var _op:     [0.0, 0.46, 0.62, 0.62]

    Rectangle {
        id: body
        anchors.fill: parent
        radius: style ? style.radiusPanel : 18
        color: tier === 0 ? style.cardBg : style.panelBg
        border.width: 1
        border.color: style.panelBorder
    }
    // 环境投影（tier>0 才有）
    MultiEffect {
        source: body; anchors.fill: body; z: -1
        visible: surf.tier > 0
        shadowEnabled: true
        shadowColor: style ? style.shadowAmbient : "#000"
        shadowBlur: surf._blur[surf.tier]
        blurMax: 130
        shadowVerticalOffset: surf._yoff[surf.tier]
        shadowOpacity: surf._op[surf.tier]
    }
    // 顶沿 1px 高光（§3.5）
    Rectangle {
        z: 2; anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
        height: 1; color: Qt.rgba(1,1,1, surf.style && surf.style.night ? 0.04 : 0.62)
    }
}
```

> 现状对比：`GlassPanel.qml` 没用 MultiEffect，而是**一张 y:10、z:-2 的偏移实心 Rectangle** 充当廉价投影
> （注释：「避免每面板挂 MultiEffect」）。这是**性能 vs 保真**的有意取舍——大面板多时偏移色块法更省。
> 建议：默认仍用偏移法；只给**少数 Floating/Focused 焦点面**升级到 MultiEffect 软投影。实时模糊层全局 ≤3（见 §8）。

### 3.5 边缘光对：顶沿高光 + 更亮底边

CSS 用「`border:1px .075` + `border-bottom-color:.13` + `inset 0 1px 0 白`」三件套：四周一圈发丝光，**底边更亮**
（读作玻璃下唇接住环境反弹），顶边再加一道内高光斜面。

QML 的 `Rectangle.border` **不能逐边设色**，所以拆成「基边框 + 两条 1px Rectangle」：

```qml
Rectangle {
    radius: 18; color: style.panelBg
    border.width: 1; border.color: style.panelBorder        // 四周 .075
    Rectangle {                                              // 顶沿内高光
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
        height: 1; color: Qt.rgba(1,1,1, style.night ? 0.04 : 0.62)
    }
    Rectangle {                                              // 更亮底边 = --ml-border-strong
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }
        height: 1; color: style.panelBorderStrong            // .13
    }
}
```

> `GlassPanel.qml` 已含顶沿 1px 高光；**底边那条更亮 border 目前缺**，补上能立刻多一分「浮起的玻璃下唇」。

### 3.6 强调辉光 / 光晕 / 内发光

交互态的「光能层」。状态机：

```
rest      → 无辉光（顶沿高光常驻）
hover     → drop-shadow(0 0 18px aqua .20) + face 1px aqua 环 .16 + 边色→aqua .42
selected  → --ml-shadow-focus + face inset 顶沿 .06 + 极淡 aqua 环 .06（最终值很克制！）
active/run → 角落/节点 aqua 点光 + 呼吸/旋转光环（§6.4）
```

**小辉光别用 MultiEffect**（每个都挂 FBO 太贵）。两个现成省法：

1. **叠两层低透圆**仿 `box-shadow` 柔晕——`TimeRiver.qml` 节点正是这么做的：

```qml
// 节点圆点柔晕：外大淡 + 内小浓，叠出柔边光
Rectangle { width:28;height:28;radius:14; color: Qt.rgba(aqua.r,aqua.g,aqua.b, 0.08) }
Rectangle { width:18;height:18;radius:9;  color: Qt.rgba(aqua.r,aqua.g,aqua.b, 0.16) }
Rectangle { width:10;height:10;radius:5;  color: Qt.rgba(0.86,0.97,0.98, 0.92) }   // 亮芯
```

2. **`GlowCircle.qml`**（真高斯模糊）给需要大柔光的少数焦点（如选中卡底灯，见 §6.6）。

### 3.7 发光文字（替代渐变文字）

设计稿**没有任何** `-webkit-background-clip:text` 渐变字。premium 高光全靠 **accent 色 `text-shadow`**：

```css
/* 运行态计时器 */ text-shadow: 0 0 12px rgba(142,223,255,.54), 0 0 28px rgba(155,139,255,.32);
/* 回顾标题   */ text-shadow: 0 0 16px rgba(142,223,255,.22);
```

QML 的 `Text` 无 `text-shadow`，用 `Qt5Compat.GraphicalEffects` 的 `Glow`/`DropShadow` 叠在字后，**按主题 gate**
（白天 `text-shadow:none`）：

```qml
import Qt5Compat.GraphicalEffects
Item {
    Text { id: t; text: timeText; color: style.textPrimary; font.pixelSize: 38; font.weight: 850 }
    Glow {
        anchors.fill: t; source: t; visible: style.night && running
        radius: 12; samples: 25; color: style.aqua; spread: 0.2
    }
}
```

### 3.8 backdrop-filter 的现实（🔴）

窗口体 `backdrop-filter:blur(30px) saturate(118%)`、标题栏 mica、进度胶囊都靠**实时背景模糊**。
**QML 没有逐元素实时 backdrop blur。** 现状用**更实的叠色**近似（`panelBg` 夜晚 alpha 拉到 **0.94**，注释明说
「QML 无逐面板实时背景模糊，以更实叠色挡住身后卡牌」）。细节与替代方案见 `memory-lake-fidelity-gaps.md` 🔴1，本文不展开。

---

## 4. 美术 / 色彩 / 构图（美术）

### 4.1 蓝黑深度坡 + 三色点缀

底子是 4 阶近黑蓝坡 `#05070D → #090D16 → #0D1320 → #121A2A`，越上层越亮。三角强调色 aqua/violet/pink
按 §1 第 4 条分工。**值越往后迭代越淡**——再次强调用最终值。

### 4.2 渐变配方目录（9 类）

QML 渐变能力分级（先记住，再看配方）：

- **线性**：`Rectangle.gradient: Gradient { orientation: Gradient.Horizontal/Vertical }` —— 原生、最省。
  **但只能两端轴向**，要 135° 斜向得用 `QtQuick.Shapes` 的 `LinearGradient`（可设任意 start/end）。
- **辐射 radial**：`Shapes.RadialGradient` / `Qt5Compat` `RadialGradient` / `GlowCircle` 叠圆 / 烘焙 PNG。
- **角向 conic**：`Canvas` 画弧（推荐，见 §4.3）/ `Shapes.ConicalGradient` / `Qt5Compat ConicalGradient`。

| # | 名称 | CSS（最终值） | QML 实现 |
|---|---|---|---|
| 1 | 角落「记忆湖」光对 | `radial 8% 0% aqua .065 →t 28%, radial 95% 5% violet .055 →t 30%` | §3.3 路 A/B |
| 2 | 底部上照光 | `radial 50% 105% rgba(83,124,255,.42) →t 28%`（夜）/ 暖金（昼） | `GlowCircle` 置于面底外 |
| 3 | accent 135° 斜染 | `linear-gradient(135deg, aqua .08, violet .045), rgba(255,255,255,.025)` | `Shapes.LinearGradient` 斜向，或叠两层半透 Rectangle |
| 4 | accent 实心 chip 145° | `linear-gradient(145deg,#9FE7EE,#9B8BFF)`（logo/avatar/node/CTA） | `Shapes.LinearGradient`；小图标可烘焙 |
| 5 | 进度填充 90° | `linear-gradient(90deg, aqua .82, violet .72)`，轨 `rgba(255,255,255,.055)` | `Gradient{ orientation:Horizontal }`（原生！） |
| 6 | 甜甜圈 conic | `conic-gradient(aqua 0–105°, violet –190°, gold –263°, pink –312°, slate –360°)` | `Canvas`（§4.3） |
| 7 | 旋转光环 conic | `conic-gradient(from 90deg, t, aqua .18, t, violet .20, t)` 旋转 | `Canvas` + `RotationAnimator`，或 Qt5Compat ConicalGradient + 旋转 |
| 8 | 扫光/分隔线 90° | `linear-gradient(90deg, t, aqua .12, t)` | `Gradient` 三停 transparent→aqua→transparent（`TimeRiver` 时间轴已用） |
| 9 | 图片底部 scrim | `linear-gradient(180deg, rgba(0,0,0,.02), rgba(7,11,18,.74))` | `Gradient{ Vertical }`（`MemoryCard` cover 已用） |

配方 5、8、9 是**原生线性**就能 1:1 的——优先用它们，最省。

### 4.3 甜甜圈 / 饼图 → `Canvas` 2D（不要实时 conic）

`DailyUsageShare.qml` 已落地标准做法：`ctx.arc` 逐扇区填色 → `globalCompositeOperation="destination-out"`
再画内圆**挖出中心**得到甜甜圈。这比每帧跑 conic shader 省得多，且扇区可数据驱动：

```qml
// DailyUsageShare.qml 既有逻辑（节选）
for (var j=0;j<slices.length;j++){
    var end = start + slices[j].percent/total * 2*Math.PI;
    ctx.beginPath(); ctx.moveTo(cx,cy); ctx.arc(cx,cy,r,start,end); ctx.closePath();
    ctx.fillStyle = slices[j].color; ctx.fill(); start = end;
}
ctx.globalCompositeOperation = "destination-out";          // 挖中心 → 甜甜圈
ctx.beginPath(); ctx.arc(cx,cy,inner,0,2*Math.PI); ctx.fill();
ctx.globalCompositeOperation = "source-over";
```

扇区配色用设计稿的分类色：aqua `#9FE7EE` / violet `#9B8BFF` / gold `#FFE6A3` / pink `#FF7A9A` / slate `#6F7C91`
（图例点颜色与扇区严格对齐）。中心总时数文字加 aqua `Glow`（§3.7）。

### 4.4 构图：三栏 + 中央「湖」舞台 + 选中景深

- **三栏**：左导航 / 中舞台（main-panel + cards-zone）/ 右数据。每栏是 Raised 档玻璃面（§3.4）。
- **湖舞台 `.cards-zone`**：底色 `radial 50% 68% aqua .055 →t 34%, rgba(8,12,20,.58)` = 从下中升起的 aqua 上照光
  （像光从湖面浮起）+ 顶沿内高光 + 64% 高度一条 aqua「水位线」`linear 90deg t→aqua .12→t`。
- **选中景深**：非选中卡 `opacity:.42; filter:saturate(.55) brightness(.70) blur(.25px); scale(.88)`，翻面时其它卡更退
  `opacity:.25`。这套**伪景深**让中央卡「在焦点、在前」。

`MemoryCard.qml` 已用属性分支表达：

```qml
scale:   selected ? 1.01 : (previewed ? 0.96 : 0.88)
opacity: selected ? 1.0  : (dimmed ? 0.25 : (previewed ? 0.82 : 0.42))
```

> blur(.25px) 的亚像素景深 QML 可省略（差异肉眼几乎不可见），用 scale+opacity+（可选）`MultiEffect.saturation/brightness` 即可。

---

## 5. 质感 / 材质（质感）

### 5.1 毛玻璃两层材质

| 层 | 选择器 | 配方（最终值） | QML |
|---|---|---|---|
| **Tier-1 大框** | `.sidebar/.main-panel/.right-panel` | `bg rgba(11,16,27,.72)` + `border .075`（底 .13）+ `inset 0 1px 0 .04` + `--ml-shadow-soft` | `GlassPanel{ strong:false }` + §3.4 |
| **Tier-2 内层卡** | `.profile/.overview/.note…` | `bg rgba(255,255,255,.035)`（**白霜膜，非暗填**）+ `border .065` + **只顶沿 inset .035，无投影** | `Rectangle{ color: style.cardBg }`（=.035） |

`.profile`/`.overview` 在霜膜上再叠一层 accent 斜染（配方 #3），是「被柔光染过的彩色玻璃」。

### 5.2 边缘光对 → 见 §3.5（两条 1px Rectangle）。

### 5.3 程序化纹理：**全程无噪声**

整个 app **没有任何** raster noise / feTurbulence / 噪声贴图 / 颗粒滤镜。纹理 100% 靠 CSS 渐变：

- **蓝图网格**（设置/日历/回顾面 `::before`）：两道交叉 1px 渐变
  `linear(90deg, rgba(255,255,255,.04) 1px, transparent 1px), linear(0deg, …035 1px, transparent 1px)`，
  `background-size: 26–48px`，`opacity .18–.24` → CAD/科技底纹。
- **Miro 点板**（memo 浮层）：`radial(circle, rgba(80,80,80,.30) 1px, transparent 1.2px)`，`size 22px`。

QML 三选一（按性价比）：

```qml
// 路 1：ShaderEffect 画网格（最省、随尺寸无损）
ShaderEffect {
    property real pitch: 42.0
    property color line: Qt.rgba(1,1,1,0.04)
    fragmentShader: "qrc:/shaders/blueprint_grid.frag.qsb"   // 两组 1px 线，按 pitch 取模
    opacity: 0.24
}
// 路 2：Canvas 一次性画好网格/点阵，缓存为纹理（简单、零 shader 依赖）
// 路 3：烘焙一张 small tiled PNG，Image{ fillMode: Tile }（最稳，丢失主题调色）
```

> **不要上噪声 shader**——设计本身就没有，加了反而失真。

### 5.4 `mix-blend-mode: screen`（只两处）

仅 `.summary-wave`（回顾页极光光漏）与 `.pixel-tomato-mini::before`（aqua 电路扫线）。screen = **只加亮不压暗**
（暗处发光、亮处消失）。QML 无 screen 混合属性。两种近似：

1. **低透亮色层**：在**近黑底**上，普通 `alpha` 合成 ≈ screen（因 dst≈0 时 `src+dst-src·dst ≈ src`）。
   这两处底都极暗，直接用一张低 opacity 的亮渐变 Rectangle 即可，肉眼几乎等价。
2. **ShaderEffect 真 screen**：`gl_FragColor = src + dst - src*dst`（需采样背景，较重）。仅在必须时上。

```qml
// 极光光漏近似：斜置、模糊、超尺寸的紫→粉→白→蓝亮带，低透叠加（近黑底 ≈ screen）
Item {
    Shape { /* LinearGradient 115°: t, violet .14, pink .22, white .18, blue .16, t */ }
    transform: [ Rotation{ angle:-8 }, Scale{ xScale:1.25; yScale:1.25 } ]
    layer.enabled: true
    layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 40 }
    opacity: 0.6
}
```

### 5.5 排版系统

一套紧凑几何无衬线。复刻要点：

- **字族**：`Inter, "Microsoft YaHei", "PingFang SC", Arial`（chrome 用 `Segoe UI`）。QML `font.family`，
  自带 Inter 字体文件保证跨平台一致。
- **重字重坡（非标准数值）**：760=主力半粗（最多）、900=英雄数字/标题、850/800/820/880/950=展示。
  Qt6 `font.weight` **接受整数 1–1000**：`font.weight: 760`。
- **显示负字距**：`.slide-title` 54px / line-height 1.02 / **letter-spacing -2.2px**。QML `font.letterSpacing: -2.2`
  （接受负值），`lineHeight: 1.02; lineHeightMode: Text.ProportionalHeight`。
- **eyebrow 正字距大写**：10–12px / `text-transform:uppercase` / `letter-spacing +0.8~1.2px` / 低 alpha 或 aqua。
  QML：`font.capitalization: Font.AllUppercase; font.letterSpacing: 1.0`。
- **等宽数字**（时钟/计时器不跳动）：`font-variant-numeric: tabular-nums` → Qt 6.7+ `font.features: { "tnum": 1 }`，
  或退化为固定宽度数字容器。
- **发光强调**：见 §3.7（accent text-shadow 而非渐变字）。

### 5.6 图标

- **品牌渐变方块**：`.app-mark`(24px,r7)、`.timearc-logo`(36px,r14) = `linear 135–145° aqua→violet` 上压暗墨字「T」(900)。
  QML：`Rectangle` + `Shapes.LinearGradient` 填充 + 居中 `Text`。
- **功能图标**：全是裸 Unicode 字形（⌂Home ▦Calendar ▥Stats ⚙Settings ◉Notes ⌖Recap «collapse），在 30px r11 cell 里
  用 `currentColor`。QML 可直接 `Text` 字形，但**建议换成矢量图标**求清晰；颜色随 state 用 `color` 绑定。
- **active 导航三重信号**（同时）：aqua 染底 `.13` + aqua 边 `.22` + 5px aqua 点 `::after`（`0 0 14px aqua .65` 辉光）。
  QML：底色/边色绑 `active`，那枚发光点用 §3.6 叠圆法。

### 5.7 圆角坡 + 同心嵌套 + 圆角裁切

- **坡**：容器 24–34、卡/面 16–22、控件/图标 8–14、胶囊/点 999（最常见，约 81 处）。**内层圆角永远小于父层**，
  保证发丝斜面同心平行。QML：定义 `radiusLg/Md/Sm` token，子层取「父 radius − padding」。
- **圆角裁切**：`clip:true` **只裁矩形包围盒**，圆角处的方角内容（图片棱角/渐变/文本）会溢出圆角边。
  正解是 `RoundedFrame.qml`：把子项 + 顶层描边整体合成进一张多重采样 layer，再用**单一圆角 MultiEffect 遮罩**一次裁切。
  关键参数 `maskThresholdMin: 0.5`（把裁切卡在「50% 覆盖」等高线 = 几何圆角半径，否则抗锯齿淡边整幅透出、内容半径比描边大 ~2px 导致漏边）+ `maskSpreadAtMin: 0.28`（留一点软过渡保抗锯齿）。

```qml
// 凡是「圆角 + 内部有图片/渐变/描边」的容器，用 RoundedFrame 取代 clip:true
RoundedFrame {
    radius: 18
    Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop }   // 棱角不会越过圆角
    // 顶层描边写在 RoundedFrame 内部 rim（已内置），与内容共用同一条圆角边，零漏边
}
```

---

## 6. 动效（feel over time）

### 6.1 三条缓动曲线 = 品牌手感

| 曲线 | cubic-bezier | 用途 | QML |
|---|---|---|---|
| 柔落 soft-settle | `(.2,.8,.2,1)` | 卡滑动 .42s、翻面 .68s、弹层 .46s、导航折叠 .28s | `easing.type: Easing.Bezier; easing.bezierCurve: [0.2,0.8,0.2,1, 1,1]` |
| 弹入 snappy | `(.18,.9,.2,1)` | 区块切换、爆发、揭示、脉冲 | `[0.18,0.9,0.2,1, 1,1]` |
| 英雄 gentle | `(.16,.9,.2,1)` | 海报 .9s、回顾壳 .58s | `[0.16,0.9,0.2,1, 1,1]` |

**重要纠偏**：这三条曲线 y 都 ∈[0,1]，是**强 ease-out，本身不过冲**。设计里的「弹/过冲」感来自**关键帧值**
（如 `rightSectionSwap` 在 62% 到 `scale(1.008)` 再落回）。QML 复刻过冲要用 **`SequentialAnimation` + 中间过冲值**，
而不是指望曲线：

```qml
SequentialAnimation {                     // 右栏 reorder 的「升-过冲-落定」
    NumberAnimation { target: panel; property:"scale"; from:0.985; to:1.008; duration:260; easing.bezierCurve:[0.18,0.9,0.2,1,1,1] }
    NumberAnimation { target: panel; property:"scale"; to:1.0; duration:160; easing.type: Easing.OutCubic }
}
```

时长聚类：微交互 .16–.24s / 状态 .28–.46s / 入场 .55–.9s / 环境循环 1–8s。

### 6.2 状态过渡

- **卡翻面**（招牌）：见 §6.6。
- **选中放大**：`width/height/transform/filter/opacity` 各 .32s。`MemoryCard` 用 `Behavior on width/height/scale/opacity`。
- **轨道滑动**：JS 读 offset 设 `translateX` 居中，CSS .42s 柔落补间。QML：`Row`/`ListView` + `Behavior on contentX`，
  或 `CardCarousel.qml`。
- **导航折叠**：`width 220→76px` .28s，content 与标题栏同步左移、label `opacity→0`。
- **右栏 reorder**：翻面/切卡时右栏「升-过冲-落定」（§6.1 SequentialAnimation）。

### 6.3 入场

- **recapRise 阶梯**：`opacity:0→1, translateY(22→0), scale(.985→1), blur(5→0)`，每元素 `animation-delay: var(--d)` 错峰。
  QML：每子项一个 `ParallelAnimation`（位移+淡入+`MultiEffect.blur` 解模糊）+ `PauseAnimation{ duration: index*d }` 起跑。
- **6+ 种 slide 变体**（zoom/wipe/rise/rotate/ticket/posterReveal…）共享 `blur→sharp + scale 落定`。
- **通用式**：几乎每个揭示都是「先 blur(2–16px) + 位移/缩放 → 清晰落定」。做一个 `RevealBehavior` 复用。

### 6.4 环境循环 ⚠️ 必须可关

呼吸（scale 1↔1.018）、光环旋转（conic 2.8–5s linear）、扫光（translateY/X 1.3–1.8s）、点脉冲、进度泛光平移……
全是 `infinite` 循环。

> **设计稿里完全没有 `prefers-reduced-motion` 处理——所有循环无条件常驻。** 移植到 QML 时**务必把环境循环 gate 在一个设置开关后**
> （`running: settings.ambientMotion && widget.active`），否则桌面端会无谓耗电/占 GPU。

QML：`SequentialAnimation{ loops: Animation.Infinite }`（呼吸）、`RotationAnimator{ loops: Infinite; duration: 2800 }`（光环）。

### 6.5 微交互

- **hover lift**：`translateY(-2px)` + aqua 边/晕。`HoverHandler` + `Behavior`。
- **press 0.94**：唯一 WAAPI（pomodoro 启动）。QML：`TapHandler` + `SequentialAnimation` scale 1→.94→1（220ms）。
- **滚动橡皮筋**：自定义惯性（lerp 0.22/帧）+ 到边 `translateY(±18px)` .44s 回弹 → `SilkyFlickable.qml` 已实现。
- **粒子爆发**：纯 JS 随机角度/距离 span，`setTimeout` 回收。QML：`Repeater` + `ParallelAnimation`，结束 `destroy()` 或对象池。

### 6.6 卡翻面 showpiece 详解（锚定 `MemoryCard.qml`）

设计稿：`.card-inner` `transform-style:preserve-3d`，`.card.is-flipped .card-inner{ rotateY(180deg) }` .68s 柔落，
`.card` 各自 `perspective:1100px`，`.face{ backface-visibility:hidden }`。

`MemoryCard.qml` 的高保真实现，三处精华值得复用：

1. **`Flipable` + `Rotation{ axis.y:1 }`**，角度由卡片级属性 `flipAngle` 的 `Behavior` 驱动（680ms，
   `bezierCurve:[0.2,0.8,0.2,1,1,1]` = 柔落）。

2. **底灯随 3D 转动守恒**（`ambientGlow`）：用 `|cos θ|` 做透视收束——
   `foreshorten = Math.abs(Math.cos(flipAngle*π/180))`（正面=1、侧面=0、背面=1），侧面观时把柔光水平压成一道竖直光芯
   （`xScale: 0.14 + 0.86*foreshorten`），同时亮度绽放、色相 **aqua→violet 偏移 0.7**（仿光线穿过转动卡片折射）。
   这就是「光像卡片自己发出」而非「呆板亮方块」的关键。

3. **抗锯齿圆角合成**：整张面（底色+封面+文本+**顶层描边**）先按方角合进一张 `layer.samples:4` 的 FBO（`faceContent`），
   再用单一圆角遮罩（`faceMask`）经 `MultiEffect{ maskThresholdMin:0.5; maskSpreadAtMin:0.28 }` 一次裁切。
   **描边进同一张被裁合成、与内容共用同一条圆角边**——内容绝不会越过描边漏到边缘光外（修复棱角漏边）。
   `layer.enabled: card.selected` 只给会翻面的选中卡建 FBO，**不给 9 张卡都挂**（性能）。

> 这套「FBO 合成 + 单一圆角遮罩 + 描边同层」就是 `RoundedFrame.qml` 的通用版（§5.7）。新组件要圆角裁切直接复用它。

---

## 7. HTML 技法 → 现有 QML 组件映射

| HTML / CSS 技法 | 现有 QML 组件 | 状态 |
|---|---|---|
| `:root --ml-*` token 全集 | `MemoryLakeStyle.qml` | ✅ 大部分（建议补深度坡 + 阴影 token，§2） |
| 窗口级四层环境光 | `AmbientBackground.qml` + `GlowCircle.qml` | ✅ 角落光居中规避硬角 clip |
| 毛玻璃面板（tier-1） | `GlassPanel.qml` | ✅ 偏移色块投影；建议补底沿亮边 + 选配 MultiEffect |
| tier-2 霜膜内层卡 | `style.cardBg/cardBorder` + `Rectangle` | ✅ |
| 角落/节点小辉光 | 叠低透圆（`TimeRiver`）/ `GlowCircle` | ✅ |
| 圆角裁切（防漏边） | `RoundedFrame.qml` / `MemoryCard` mask | ✅ `maskThresholdMin .5` |
| 3D 卡翻面 + 底灯守恒 | `MemoryCard.qml` | ✅ showpiece |
| 卡轨道/选中/预览 | `CardCarousel.qml` | ✅ |
| 甜甜圈占比 | `DailyUsageShare.qml`（Canvas destination-out） | ✅ |
| 时间河流（轴+节点+涟漪） | `TimeRiver.qml` | ✅ 轴用 3 停线性渐变 |
| 惯性滚动 + 橡皮筋 | `SilkyFlickable.qml` | ✅ |
| 生成式封面（替代海报） | `GenerativeCover.qml` | ✅ appColor 渐变 + 图标 |
| 右栏详情 / 排行 / 日历同步 | `DetailPanel` / `UsageRankList` / `CalendarSyncList` | ✅ |
| 月度回顾 deck | `RecapOverlay.qml` / `RecapSlide.qml` | ✅ |
| 今日结论卡 | `TodayConclusionCard.qml` | ✅ |
| **ElevatedSurface 四档高度** | —— | 🆕 建议新增（§3.4），统一阴影气质 |
| **发光文字（accent Glow）** | —— | 🆕 建议（§3.7，Qt5Compat Glow） |
| **程序化网格/点板纹理** | —— | 🆕 建议（§5.3，回顾/设置页用） |

---

## 8. 保真天花板与性能预算

**三大 🔴（无法全复刻，详见 `memory-lake-fidelity-gaps.md`）**
1. `backdrop-filter` 实时背景模糊 —— 无逐元素 backdrop blur，用更实叠色近似（`panelBg` α=0.94）。
2. `mix-blend-mode: screen` —— 用近黑底上的低透亮层近似（§5.4），仅两处。
3. **同时多重 + inset 阴影** —— `MultiEffect` 每元素**只有一个外阴影、无 inset**；多层光晕靠叠圆/叠层拼。

**性能预算（务必守）**
- **实时高斯模糊层全局 ≤ 3**（窗口 backdrop、app-bg、选中卡底灯就基本用满）。其余「模糊感」用叠色/烘焙。
- `layer.enabled`（FBO）**只给会翻面的选中卡 + 必须圆角裁切的容器**；别给整列卡 / 每个小面挂。
- 小 `box-shadow` 辉光一律**叠 2 层低透圆**，不挂 MultiEffect。
- 甜甜圈/饼用 **Canvas 一次绘制**，不用实时 conic shader。
- 环境循环 **gate 在设置开关后**（§6.4），后台/省电时停。

---

## 9. 落地顺序（建议）与组件清单

**自底向上建设序**（每步可独立验收）：

1. **Token 层**：补全 `MemoryLakeStyle.qml`（深度坡 bg0–3 + 阴影 token）。→ §2
2. **材质层**：`GlassPanel` 补底沿亮边；新增 `ElevatedSurface`（四档高度）。→ §3.4 / §3.5 / §5.1
3. **光照层**：`AmbientBackground` 四层叠层就位；`GlowCircle` 角落/底灯。→ §3.2 / §3.3
4. **纹理层**：新增蓝图网格 / 点板（ShaderEffect 或 Canvas，回顾/设置页）。→ §5.3
5. **排版层**：Inter 字体 + 重字重 + 负字距 + tabular-nums + accent Glow 文字。→ §5.5 / §3.7
6. **构件层**：卡舞台（`CardCarousel`/`MemoryCard`）、甜甜圈、时间河流、右栏数据件——多数已就位。→ §4 / §7
7. **动效层**：三缓动 token 化；环境循环统一 gate；入场 RevealBehavior。→ §6
8. **主题层**：`night/day` 全量过一遍——阴影黑↔蓝灰、accent aqua↔teal、text-shadow→none、`glowStrength`。→ §2

**验收建议**：用 MEMORY 里记的「qml.exe + grabToImage 快循环 + 放大 3× 超采样 + magenta 背景逐像素门」核对
圆角漏边 / 边缘光对齐 / 辉光强度（普通截图会假阳性）。

---

### 附：值速查（最常用，最终值）

```
窗口体   bg rgba(7,10,17,.82)  border .105  shadow 0 34px 110px black .72 / inset 0 1px white .055  blur 30 sat 118%
tier-1   bg rgba(11,16,27,.72) border .075 底 .13  shadow inset 0 1px .04 + 0 24px 80px black .46
tier-2   bg rgba(255,255,255,.035) border .065  shadow inset 0 1px .035（无投影）
卡面     bg rgba(13,18,29,.92)=#0D121D  border .08  radius 18  rest shadow:none
选中卡   --ml-shadow-focus 0 34px 90px black .62  translateY(-6) scale1.01  face inset .06 + aqua 环 .06
角落光   aqua 8%0% .065→t28%   violet 95%5% .055→t30%
湖舞台   radial 50%68% aqua .055→t34% , rgba(8,12,20,.58)  水位线 64% aqua .12
进度填充 linear 90° aqua .82 → violet .72   轨 rgba(255,255,255,.055)
品牌渐变 linear 145° #9FE7EE → #9B8BFF
缓动     柔落(.2,.8,.2,1)  弹入(.18,.9,.2,1)  英雄(.16,.9,.2,1)
圆角     lg28 md22 sm16 / 控件8–14 / 胶囊999    遮罩 maskThresholdMin .5  maskSpreadAtMin .28
```

---

*本文聚焦「怎么复刻」的正向配方；「能复刻到几分 / 哪些做不到」请配合 `docs/memory-lake-fidelity-gaps.md` 一起读。*
