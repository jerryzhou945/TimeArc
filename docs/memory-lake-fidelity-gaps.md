# 记忆湖 1:1 复刻 — 保真度差距清单（HTML/CSS → Qt6 QML）

> 配套 `docs/memory-lake-implementation-plan.md`。
> 这里诚实列出**哪些设计稿效果在 QML 里无法 100% 还原、能还原到几成、用什么折中**。
> 基线：Qt 6.11.1（mingw），项目已在用 `QtQuick.Effects` / `MultiEffect`
> （见 `AchievementToast.qml`、`DesktopCalenderPage.qml`），所以模糊/阴影/遮罩是已验证能力。
>
> 评级：🟢 可达 ~1:1 ｜ 🟡 高度接近、细节有差 ｜ 🔴 无法完全一致、需折中。

---

## 一句话结论

你最关心的两块——**丝滑翻卡 + 丝滑滚动条**——属于 🟢，可以逐参数调到和 HTML 一致。
**灯光**绝大部分可还原；唯一真正还原不了的是 CSS 的**实时背景模糊（backdrop-filter）多层叠加**
和 **mix-blend-mode 混色**，这两项是 Web 引擎独有、QML 无对等原生能力，只能高质量近似。

---

## 🟢 可达 ~1:1（放心，包含你点名的丝滑交互）

| 设计稿效果 | QML 实现 | 能到几成 |
|---|---|---|
| **翻卡** rotateY(180°) .68s cubic-bezier + backface-visibility | `Flipable`（front/back）+ `Rotation{ axis.y:1 }`（Qt Quick 的 3D 旋转**自带透视前缩**）+ `NumberAnimation{ easing.bezierCurve }` | ~95%，顺滑无撕裂 |
| **丝滑滚动 + 自定义滚动条 + 边界回弹** | 自封装 `SilkyFlickable`：`Flickable` + `WheelHandler` 做缓动滚动（复刻 rAF lerp 0.22）+ 自绘细霓虹 `ScrollBar` + 越界回弹动画 | ~100%，可逐参数对齐手感 |
| 卡轨水平居中过渡 .42s | `ListView` StrictlyEnforceRange + `Behavior` | ~100% |
| 选中放大 / 悬停预览 / 翻面锁定 / wheel-tip 文案切换 | 状态属性 + `Behavior` 属性动画 | ~100% |
| 回顾：错峰入场/离场、自动播放(3.2/4.2s)、进度条、目录解锁、键鼠/滚轮导航 | `ParallelAnimation`+`startDelay` / `Timer` / 逻辑绑定 | ~100% |
| 趋势折线、关键词云、月历柱、票根 | `Shape`(ShapePath) / Flow / Rectangle | ~100% |
| 单层投影、亮度/饱和/对比滤镜、线性渐变、圆角图片遮罩、模糊大背景图 | `MultiEffect`(shadow/brightness/saturation/contrast/blur) + `Gradient` + maskSource | ~100%（项目已验证） |

---

## 🟡 高度接近，但细节有差

### 1. 多层 radial-gradient 叠加光晕
- **设计稿**：一个元素叠 2–3 层 `radial-gradient(circle at X% Y%, color, transparent N%)` 做角向柔光。
- **QML**：`Gradient` 只有线性；radial 要靠 `QtQuick.Shapes` 的 `RadialGradient`，或预渲染一张发光 PNG，或堆叠半透明 `Item`。
- **差距**：柔边衰减曲线与 CSS 的 `transparent N%` 不完全一致，需手调 stop。视觉 ~90%。

### 2. clip-path: inset(... round) 的圆角擦除式 wipe 转场
- **设计稿**：`slideWipeIn` 用圆角 inset 裁剪从右往左擦出。
- **QML**：裁剪原生只有矩形 `clip`；圆角动画擦除要用 `MultiEffect maskSource` + 动画遮罩矩形。
- **差距**：能做出擦除，圆角边缘动画成本略高；可退化为「位移+透明度」wipe。视觉 ~85%。

### 3. 关键帧中途的 blur 过渡（filter: blur 0→x→0）
- **设计稿**：多个入场动画结尾带 `filter: blur(...)`（recapRise、posterReveal、appCardHero 等）。
- **QML**：`MultiEffect.blur` 可被 `NumberAnimation` 驱动，但**逐帧模糊较吃 GPU**，高频/多元素同时模糊可能掉帧。
- **折中**：hero 大图保留 blur 过渡；小元素去掉 blur、只留 opacity+scale+translate。观感 ~90%。

### 4. transform-style: preserve-3d 的 orbit 节点 / rotate 转场
- **设计稿**：`orbit-layout` 与 `slideRotateIn` 依赖保留三维空间。
- **QML**：2D 变换 + `Rotation` 可伪三维，但嵌套层级的真 3D 保持不了（需 Quick3D，过重，不引入）。
- **差距**：单层旋转/环绕视觉接近；多层穿插透视略平。~85%。

### 5. 字体度量（Inter / 自定义字重 / 负字距）
- **设计稿**：`Inter`，`font-weight: 760/850`，`letter-spacing: -2.4px` 等。
- **QML**：`font.letterSpacing`、`font.weight` 支持；但**非标准字重需变体字**，否则吸附到最近权重；不打包 Inter 会回退系统字（微软雅黑等）。
- **折中**：把 Inter 变体字打进 `resources/` 并 `FontLoader`，否则接受字形微差。文字排版 ~90%。

---

## 🔴 无法完全一致（Web 引擎独有，只能近似）

### 1. backdrop-filter: blur() —— 实时「背景模糊」多层玻璃 ⚠️ 最大差距
- **设计稿**：窗口、三栏、各小卡、pill、状态条都各自 `backdrop-filter: blur(...)`，**实时模糊各自身后的内容**（窗口模糊桌面、面板模糊窗口大图、pill 模糊面板…层层叠加）。
- **QML 现实**：**没有原生 backdrop blur**。要真模糊背景，得对背景做 `ShaderEffectSource` 快照再 `MultiEffect` 模糊，**坐标对齐麻烦、不随背景实时更新、每层一份快照成本很高**；十几个玻璃层各自实时模糊在 QML 里不现实（会严重掉帧）。
- **折中方案**：
  - 绝大多数玻璃面板：用**半透明叠色 + 细高光描边**模拟磨砂质感（肉眼在静态/慢动时接近）。
  - 仅对**最关键的 1–2 层**（窗口背后的 APP 大图、月度回顾背景层）用真 `MultiEffect` 模糊。
- **结论**：静态观感可做到 ~85%；但「拖动/滚动时背景被玻璃实时模糊跟动」这个动态特征**无法复刻**。

### 2. mix-blend-mode: screen —— 流光叠加混色
- **设计稿**：`summary-wave` 用 `mix-blend-mode: screen` 与背景做滤色混合，产生发光流光。
- **QML 现实**：`Item` 没有「与任意背景按 screen 混合」的属性；要精确实现得自写 `ShaderEffect` 采样背景做 screen 公式。
- **折中**：用**加色半透明渐变**（高亮度、低不透明）叠加近似。亮部观感接近，暗部混色规律和真 screen 有差。~80%。

### 3. 多重阴影 + inset 内阴影同时
- **设计稿**：大量 `box-shadow: 0 0 0 1px ..., 0 0 38px ..., inset 0 1px 0 ...`（外发光 + 描边 + 内高光叠在一起）。
- **QML 现实**：`MultiEffect.shadow` 一次**只有一个外投影**，**没有 inset**。
- **折中**：外发光用 MultiEffect；内高光/内描边用**额外内描边 Rectangle / 顶部 1px 高光层**叠出；多重外阴影叠两个 effect。边缘叠加规律与 CSS 略不同。~85%。

### 4. （次要）原生 `::-webkit-scrollbar` 视觉
- 实际**不算差距**：QML 滚动条本就全自定义，能把细霓虹滚动条做得和设计稿一致甚至更好。列此仅为说明实现方式不同。

---

## 性能注意（影响「丝滑」的真正风险）

QML 的 `MultiEffect`（尤其 blur）是 GPU 开销项。设计稿那种**十几处同时模糊**若照搬，会掉帧、反而不丝滑。
因此保真与流畅要平衡：

- 限制**真模糊层数**（建议 ≤ 3：APP 大背景、回顾背景，外加至多一处重点玻璃）。
- 模糊层**不随每帧动画刷新**；切卡时只更新一处大图。
- 翻卡/滚动等高频交互**不叠 blur**，靠属性动画保证 60fps。
- 这正是「丝滑」优先于「逐像素灯光」的取舍——你点名的流畅翻卡/滚动会被优先保证。

---

## 需实测确认（实现期验证，不阻塞开工）

- [ ] `MultiEffect.blur` 动画化在目标机型的帧率（决定 §🟡3 取舍范围）。
- [ ] `Flipable` 透视前缩与设计稿 `perspective:1100px` 的视觉差是否可接受。
- [ ] 半透明叠色玻璃 vs 真 backdrop blur 在你眼里的接受度（决定 §🔴1 投入多少真模糊）。
- [ ] 是否打包 Inter 字体（决定 §🟡5 字形保真度）。
- [ ] 多层 radial 光晕用 Shapes 还是预渲染发光图（决定 §🟡1 做法与性能）。

---

## 汇总

| 维度 | 可达程度 |
|---|---|
| 丝滑翻卡 | 🟢 ~95% |
| 丝滑滚动 / 滚动条 / 边界回弹 | 🟢 ~100% |
| 交互逻辑（切换/锁定/回顾/键鼠） | 🟢 ~100% |
| 排版 / 渐变 / 投影 / 滤镜 / 折线图 | 🟢 ~95–100% |
| 多层 radial 光晕 / 圆角擦除 / hero blur / 伪3D / 字体 | 🟡 ~85–90% |
| **backdrop 实时背景模糊（动态跟动）** | 🔴 静态 ~85%，动态不可复刻 |
| **mix-blend-mode 混色流光** | 🔴 ~80% 近似 |
| **多重 + inset 阴影叠加** | 🔴 ~85% 近似 |

整体：**交互与排版可做到几乎不可分辨；灯光约 85–95%**，差在 CSS 合成器独有的实时背景模糊与混合模式。

---

## 精修轮（2026-06-02，对齐 v25 override 层）

> 复刻初版按设计稿的**早期字面 CSS**实现；但 `memory_lake_v25_win11_style.html`
> 在 CSS ~1514–2089 行有一整套 **v25 "win11" `!important` 覆盖层**（`--ml-*` 皮肤），
> 才是真正的最终观感。本轮把实现对齐到该覆盖层。

**已修正（对齐 v25）**
- 月度回顾开/关：补**错峰入场**（shell translateY(28)+缩放；glow-ring scale .82→1；
  wave opacity/skew/scale；topbar .08 / stage .16 / side .22 / progressbar .28s 延迟）。
  shell 的 `filter: blur(10→0)` 按性能取舍以位移+缩放+透明近似（不逐帧模糊整壳）。
- 回顾单屏：补 `recapRise` 内容错峰上浮（kicker 先、正文随后）；新增 `playing`
  触发，修复"打开瞬间当前屏不重播入场"。
- 卡牌几何：选中 310×440、翻面 360 宽、translateY(-6)、scale 1.01、封面 196、圆角 28；
  修正 `centerOffset()` 用错宽度导致的卡轨居中偏移。
- 时间河流：轴心 46→52px；轴渐变 1 段→3 段(transparent→rgba(133,237,255,.38)→transparent)；
  节点条由 12px 粗条改为设计稿 **2px 细线**（aqua .84→violet .66）；补节点圆点柔晕、轴心对齐。
- 排行项：补 `:hover` translateX(2px) + 悬停描边。
- 大背景图：模糊 64px→**42px**、不透明度 .32→**.34**、scale 1.16→1.18、亮度/饱和对齐。
- 详情分析行高 1.35→1.6；丝滑滚动条回弹去掉二次过冲（OutBack→OutCubic）。

**🔴 实现期发现并修复：自定义霓虹滚动条此前并未真正生效**
- App 使用 Qt 原生 **Windows Controls 样式**，该样式**不支持 `ScrollBar` 的
  `contentItem` 自定义**（运行时刷 "The current style does not support customization"
  告警），即 `SilkyFlickable` 里的霓虹 thumb 被忽略、并未绘制。
- 修复：`SilkyFlickable` 改为**手绘 `Rectangle` 滚动条**（常显、随内容平滑移动、可拖拽），
  绕开样式系统，既真正渲染霓虹滚动条，又消除该类告警。

**本轮仍为近似（保持诚实）**
- 回顾**逐项**微错峰（orbitPop 单节点、月历单柱依次弹入）未做，仅做了**整块** recapRise；
  属 🟡 细节，留待后续。
- 时间河流节点/圆点/涟漪辉光用低透叠圆近似 `box-shadow 0 0 18/30px`（无原生外发光），非逐像素一致。
- 设计稿 `.overview::after "点击查看月度总结"` 提示**有意未复刻**：v25 标记里总览卡无
  点击绑定（专门的 `.recap-cta` 才是入口，已实现），该 ::after 是早期版残留，加之反而误导。

**验证状态**：`build.py` 干净；记忆湖三栏页（含细线辉光时间河流）已截图确认渲染；
新代码运行期零新增 QML 告警。回顾覆盖层打开态与新滚动条因本环境 Win32 输入自动化不稳定
（见早期 session journal）未截图确认，建议用 `run.cmd` 真机走查。
