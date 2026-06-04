# 记忆湖备忘页（黑板 / 便签 / 番茄钟）· 渲染管线完全复刻分析

> 备忘页专题的「美术 / 合成层」文档。沿用首页三件套确立的分工——
> `memory-lake-art-lighting-qml-cookbook.md`（技法 / token 字典）说"用什么值、
> 摆什么灯、复用哪个组件"；`memory-lake-home-art-implementation-spec.md`（条款式
> 法规）说"必须达到什么 + 怎么验收"；首页的 `memory-lake-home-render-pipeline-
> replication.md` 说"管线上逐层怎么 1:1 搭、哪里上 shader、能到几成"。**本文是后者
> 在备忘页上的对应物**，与之配套的 `memory-lake-memo-functional-replication.md`
> 负责"功能 / 状态 / 复刻规则·标准·步骤"。
>
> 调查对象：`MemoryLakeDesign/TimeArcDesign_v88.html`，**仅**备忘覆盖层
> `#memoOverlay`（DOM 14674–14881 + 完成弹层 18367–18377）及其全部子面。CSS 跨
> V21→V88 版本层层覆盖，**后写的 + `!important` 胜**；行号均取自 v88 原文件。

---

## §0 核心结论（先给判断，再给证据）

1. **备忘页与首页本质不同：首页是"纯静态合成 + CSS 过渡"，备忘页是全文件唯一
   拥有真实 `<canvas>`（事件驱动即时绘制——pointermove 即画 `ctx.stroke`，非 RAF
   循环）+ 大量 `@keyframes`/计时器动画的页面。** 复刻难点因此分两类：
   - **静态合成类（黑板底、各玻璃面板、像素番茄精灵）**——和首页同性质，QML 场景图
     原生可逼近 ~95–100%，无需重武器。
   - **动态类**——又分两小类：①**自由手绘画布**（pen/eraser），是真正需要 QML
     `Canvas`（即时栅格化）或自写绘制项的部分；②**编排动画**（番茄钟运行光效、
     档案袋开合 3D、像素番茄抖动、完成庆祝弹层），全部是 CSS `transition`/
     `@keyframes`，在 QML 中 1:1 映射为 `Behavior`/`NumberAnimation`/`SequentialAnimation`
     + `Easing.Bezier`，**不需要逐帧 JS**。

2. **黑板那层"模糊磨砂质感"= 1 道 backdrop 模糊 + 4 层半透贴 + 1 层点阵**，全部
   静态。具体配方见 §1.1。这是利好：黑板底复刻是"合成 + 一次重模糊"问题，不是
   实时渲染问题。

3. **备忘页是全新地基（greenfield）。** `qml/desktop/memorylake/` 现有组件里
   **没有任何** memo/blackboard/sticky/pomodoro/canvas-drawing 组件（已 grep 确认）。
   最接近的可复用基元是 `GridTexture.qml`（需加"点阵"变体）+ `GlassPanel` /
   `RoundedFrame` / `GlowCircle` / `FrostCard` / `SilkyFlickable`。因此本文不写
   "现状为何廉价"（首页那种返工清单），改写**"从零搭就要一次搭对的管线"**（§2）。

4. **诚实天花板：黑板底 + 玻璃 chrome ~98%；编排动画 ~95%（QML 缓动可 1:1，唯
   `mix-blend-mode:screen`、`conic-gradient` 旋转光环需近似或 shader）；自由手绘
   画布 ~90%**（栈式栅格无矢量模型，缩放会重采样——见 §4.3、§7）。需要 shader 的
   只有黑板磨砂一次成型去 banding、番茄运行态的 conic 光环这最后几个百分点，且走
   **不冻结**的 `resources/CMakeLists.txt` 资产/着色器路径（§6）。

5. **像素番茄是 box-shadow 像素画**（~80 个偏移点拼一颗番茄，§5.3 找到的 F 报告）。
   CSS `box-shadow` 多投影在 QML **没有原生等价**——必须改用 8px/10px 网格的
   `Image`(导出 PNG sprite) 或 `Canvas`/`Repeater<Rectangle>` 重绘。这是备忘页里
   唯一"做法要换、不能照搬属性"的美术点。

---

## §1 HTML 备忘页渲染管线 · 全层解剖

### §1.1 黑板底 = 覆盖层 `.memo-overlay`（终值在 V41，行 4253–4266）

黑板**不是** `<canvas>`。暗色模式下整张磨砂点纸由 `.memo-overlay`（一个
`position:fixed; inset:0` 全屏 div）绘制，`<canvas class="memo-canvas">` 是浮在其上的
**全透明墨水层**。背后的首页窗口透过 `backdrop-filter` **被模糊**地透出来。

**终值（V41，4253–4258 + ::before 4261–4266）：**
```css
.memo-overlay {                                   /* 4253 */
  position: fixed; inset: 0; z-index: 120;        /* 2580–2582 */
  display: none; opacity: 0;                       /* 2583/2586 → .open: block/1 (2589) */
  transition: opacity .26s ease;                   /* 2587（开合唯一计时，无后续覆盖）*/
  background:
    radial-gradient(circle, rgba(255,255,255,.105) 1px, transparent 1.15px),  /* 点阵：白点 10.5%，1px 半径 */
    linear-gradient(180deg, rgba(9,11,18,.82), rgba(6,8,14,.86)) !important;   /* 近黑蓝竖渐变 #090B12→#06080E */
  background-size: 24px 24px, auto !important;     /* 点阵 24×24 平铺 */
  backdrop-filter: blur(10px) saturate(105%) contrast(108%) !important;        /* 模糊背后的首页 */
}
.memo-overlay::before {                            /* pointer-events:none 的辉光罩，4261 */
  background:
    radial-gradient(circle at 18% 12%, rgba(142,223,255,.06), transparent 38%),  /* aqua 左上 #8EDFFF @6% */
    radial-gradient(circle at 76% 72%, rgba(155,139,255,.055), transparent 42%), /* violet 右下 #9B8BFF @5.5% */
    rgba(0,0,0,.10) !important;                    /* 整体压暗 10% */
}
```

**磨砂暗黑配方（"质感怎么来的"的答案）= 1 道 backdrop 模糊 + 4 层半透贴：**
1. `backdrop-filter: blur(10px)` 把活动的首页内容糊掉；
2. 覆盖层自身 ~82–86% 不透明的近黑竖渐变压在模糊之上（首页被重压暗、未全遮）；
3. `::before` 再加 10% 黑罩 + ~6% aqua/violet 角辉光；
4. 顶层 10.5% 白点阵 24px 平铺。

> 暗色模式下 **`.memo-canvas` 自身无 background**（行 2593–2599，仅
> `position:absolute; inset:0; cursor:crosshair; touch-action:none`）——点阵纯属
> 覆盖层，墨水层透明。光色模式（`body.light-mode`）把点阵搬到 canvas 上，但其触发
> 类 `.active` 从未被 JS 添加（JS 只切 `.open`）——**光色黑板实际不生效**，见 §2 与
> 功能文 GAPS。复刻时**统一一个开合类、把点阵画在黑板底层（不分主题）**。

### §1.2 顶部工具条 `.memo-toolbar`（终值 V53，行 6116–6124）

居中悬浮玻璃药丸，开合时从上方 10px 滑入。

```css
/* 几何（3325 块 + base）：position:absolute; top:22px; left:50%;
   z-index:126; min-height:48px; padding:6px 8px; gap:6px; border-radius:12px; display:flex */
.memo-toolbar {                                   /* V53 皮肤，6116 */
  background: linear-gradient(180deg, rgba(28,32,42,.94), rgba(16,19,28,.92)) !important;
  border: 1px solid rgba(142,223,255,.14) !important;             /* aqua 描边 */
  box-shadow: 0 18px 48px rgba(0,0,0,.46), inset 0 1px 0 rgba(255,255,255,.08) !important;
  backdrop-filter: blur(18px) saturate(125%) !important;          /* 在已磨砂黑板上再局部糊一次 */
}
/* 入场（2616–2622，无覆盖）：滑入 + 淡入 */
.memo-toolbar          { transform: translateX(-50%) translateY(-10px); opacity: 0;
  transition: transform .28s cubic-bezier(.2,.8,.2,1), opacity .24s ease; }
.memo-overlay.open .memo-toolbar { transform: translateX(-50%) translateY(0); opacity: 1; }
```

按钮 `.memo-tool`：38×38、`border-radius:8px`，静止透明；hover **抬升 6px + 放大 1.06**
（`transform: translateY(-6px) scale(1.06)`，3558）+ aqua 洗背 `rgba(142,223,255,.10)`；
选中 `.active` 用招牌 **aqua→violet 135° 渐变** `linear-gradient(135deg, rgba(142,223,255,.94),
rgba(155,139,255,.92))` + 近黑字 `rgba(4,8,14,.94)`（6139–6141）。退出键 `.exit`（文字"退出"）
hover 转**破坏红** `rgba(255,95,95,.22)`（6163）。"更多工具"弹层 `.memo-more-popover`
宽 210px（9965 覆盖 188px），开合 `opacity .18s + transform .20s cubic-bezier(.18,.9,.2,1)`、
`scale .96→1`（6616/6620）。

> **画笔图标是纯 CSS 伪元素**（`<svg>` 为空，14692；`::after` 用 `clip-path` 铅笔
> 轮廓 + 两道渐变带 + `filter:invert()` 重着色，3736–3760 / 6172–6186）。QML 无 CSS
> filter，须手绘两套配色（暗态/选中态）的铅笔。其余图标（便签方块、文字 T、橡皮、
> 更多三点+加号、时钟）是标准 `viewBox="0 0 24 24"` 描边 SVG，可直接转 `Shape`/`PathSvg`
> 或导出。路径数据见工具条提取报告 §2。

### §1.3 便签 `.sticky-note`（终值 V55，行 6486–6502）

```css
/* 几何：position:absolute; z-index:124; width:310px; min-height:285px;
   border-radius:0; min-width:210px; display:flex; flex-direction:column（4137/4302/4139/3823）*/
.sticky-note {                                    /* V55 皮肤，6486 */
  background: #FFE6A3 !important;                  /* 扁平暖黄便利贴（早期渐变全被覆盖）*/
  color: #1E1E1E !important; border: none !important;
  box-shadow: 0 22px 34px rgba(0,0,0,.34), 0 7px 15px rgba(0,0,0,.18) !important;
}
.sticky-note::before {                            /* 接触软阴影，左右内缩 16px，bottom:-9px，blur(9px) */
  background: rgba(0,0,0,.22) !important; z-index: -1; }
.sticky-note.selected-note {                      /* 选中 = aqua 描边环 */
  outline: 2px solid rgba(142,223,255,.58) !important; outline-offset: 2px !important; }
.sticky-note.is-resizing {                        /* 拖拽尺寸时 aqua 2px 光圈 */
  box-shadow: 0 24px 38px rgba(0,0,0,.40), 0 0 0 2px rgba(142,223,255,.25) !important; }
```

结构（终态模板 16382）：隐藏的拖拽 header（`opacity:0`，hover/选中时升到 .22）、
3 行 grid 字段（大标题 input `font-size:24px/820`、正文 textarea `18px/500`、静态署名
"JusTin D"）、4 个自绘缩放把手（左/右/下/右下角，**无上把手**，3920–3968）。**便签的
× 删除键在终态 `display:none`**（4180），删除靠键盘 Backspace/Delete。

> `.sticky-title`/`.sticky-subtitle`/`.sticky-close` 是死选择器（display:none + 不在
> 模板里）；署名 "JusTin D" 写死且**不持久化**。详见功能文 §2.4 与 GAPS。

### §1.4 文字层 `.memo-text-layer`（终值 V52，行 6412–6426）

```css
/* base：position:absolute; z-index:123; min-width:120px; min-height:36px;
   border-radius:10px; font-size:18px; line-height:1.4; backdrop-filter:blur(8px) */
.memo-text-layer {                                /* V52 皮肤，6412 */
  background: linear-gradient(180deg, rgba(35,40,52,.88), rgba(18,22,32,.86)) !important;  /* 暗玻璃卡 */
  border-color: rgba(142,223,255,.16) !important; color: rgba(245,250,255,.94) !important;
  padding: 10px 38px 10px 12px;                    /* 右侧留 × 按钮槽（V29 3042）*/
  box-shadow: 0 14px 40px rgba(0,0,0,.28); }
.memo-text-layer.selected-note {                  /* ⚠ 仍是旧蓝 rgba(13,153,255,.65)，未迁 aqua（bug）*/
  outline: 2px solid rgba(13,153,255,.65); outline-offset: 2px; }
```

文字层 `contenteditable`、自带可点 × 删除键（与便签不同，**不隐藏**）；默认黄色便签
变了主题、文字层留暗玻璃。选中环未统一到 aqua（复刻时应统一）。

### §1.5 页面档案袋 `.memo-page-control`（终值 V53，行 6205–6352）

右上角 3D 档案袋。整体 `transform: scale(.88); transform-origin: top right`（6206），
`right:18px; top:18px; width:292px`（6019），`perspective:1100px`（5707）。开合全靠
`#memoPageControl` 上的 `.open` 类，**纯 CSS 过渡，无 JS 补间**。开态是 5 个同时过渡 +
3D 倾斜的合成（详表见 §1.5 末）：

```css
/* 档案袋本体抽屉式长高 + 后仰 */
.memo-page-control.open .memo-folder-stack {
  height: calc(100px + var(--page-count, 1) * 38px) !important;     /* 6033 */
  transform: rotateX(5deg) rotateZ(-.25deg) !important; }           /* 5721 */
.memo-folder-stack { transition: height .36s cubic-bezier(.18,.9,.2,1),
                                 transform .24s ease, filter .24s ease; }  /* 5138 */
/* 前盖玻璃卡（V53 6210）：linear-gradient(180deg,rgba(34,39,50,.96),rgba(19,23,33,.94))
   + 1.5px aqua 描边 rgba(142,223,255,.16) + 0 22px 55px rgba(0,0,0,.52)；
   开态阴影涨到 0 34px 82px rgba(0,0,0,.62)（6238），height .34s cubic-bezier(.18,.9,.2,1)（4887）*/
/* 厚度层 .memo-folder-layer（每多一页加一片，--i 递减）：
   translateZ(--i*-18px) translateY(--i*-2px) scale(1 - --i*.012) rotateX(2deg)（5853–5856），
   阶梯下移 top:60px+--i*32px（6067）、内缩 16px+--i*3px——经典扇开档案袋。整捆从 -14px
   落入、淡入（5824）。*/
/* 弹出体 .memo-folder-pages：transform translateY(-9px) scale(.985)→0/1，
   transition opacity .22s + transform .24s ease .05s（5027，滞后壳体 50ms）*/
/* 雪佛龙 ⌄ 开态 rotate(180deg)，.22s ease（5017）；前盖 ::after 抽屉暗影 opacity 0→.8（5774）*/
```

页面行 `.memo-page-row`（V53 6309）是迷你索引卡：`border-radius:8px 8px 10px 10px`、
带 `::before` 升起的"标签页"（按 `nth-child(3n)` 左/中/右错位，5974）、`0 7px 0
rgba(0,0,0,.24)` 卡边硬阴影。`.active` 行 = aqua→violet 135° 渐变（6333）。

| 元素 | 属性 | 闭 → 开 | 时长 | 缓动 |
|---|---|---|---|---|
| folder-stack | height | 56px → `100px+n*38px` | 360ms | `cubic-bezier(.18,.9,.2,1)` |
| folder-stack | transform | 无 → `rotateX(5°) rotateZ(-.25°)` | 240ms | ease |
| folder-front | height | 56px → `100px+n*38px` | 340ms | `cubic-bezier(.18,.9,.2,1)` |
| folder-front | box-shadow | 55px → 82px 模糊 | 220ms | ease |
| folder-front::after | opacity | 0 → .8 | 220ms | ease |
| folder-layers | opacity / translateY | 0/-14px → 1/0 | 220/300ms | ease / bezier |
| folder-pages | opacity / transform | 0/Y-9px → 1/0（**+50ms 延迟**） | 220/240ms | ease |
| folder-chevron | rotate | 0 → 180° | 220ms | ease |

### §1.6 番茄钟悬浮窗 `.pomodoro-widget`（V58 base 6693 + V59 运行态 6878）

`position:absolute; right:24px; top:86px; z-index:128; width:278px; border-radius:20px`，
背景 `radial-gradient(circle at 15% 0%, rgba(142,223,255,.12), transparent 44%),
linear-gradient(180deg, rgba(31,36,48,.94), rgba(14,18,28,.92))`，悬浮阴影 `0 28px 80px
rgba(0,0,0,.48)`，`backdrop-filter: blur(22px) saturate(125%)`。开态 `opacity 0→1 +
translateY(-10px) scale(.96)→0/1`，transition（V59 终值 6880）`opacity .22s + transform
.24s cubic-bezier(.18,.9,.2,1) + box-shadow/border/filter .28s`。进度是**横向填充条**
（`<span>` width%，渐变 `#9FE7EE→#9B8BFF`，`.22s linear`）——**没有环形进度环**（GAP）。

**运行态 `.running` 的 8 套 `@keyframes`（V59，全部 `infinite`）：**
旋转 conic 光环 `pomodoroAura 2.8s`（6925）、扫描线 `pomodoroScan 1.8s`（6939）、红点
脉冲 `pomodoroDotPulse 1.05s`（6958）、读数面呼吸 `pomodoroDisplayBreath 1.6s`（6981）、
时间字脉冲 `pomodoroTimePulse 1s`（6998）、进度条流光 `pomodoroProgressGlow 1.3s`
（7028）；加触发态：开始迸发 `pomodoroStartBurst .46s`（7049）、完成双闪
`pomodoroFinishFlash .9s ×2`（琥珀色 `rgba(255,230,163,.34)`，7065）。粒子
`pomodoroParticle 900ms`（7099，`--dx/--dy` 由 JS 设）。

**像素番茄精灵**（紧凑态 `.compact-tomato`）：`.pixel-tomato::before/::after` 用约 80 个
`box-shadow` 偏移在 8px 网格上拼出红番茄 + 绿叶（调色板见番茄提取报告 §5.3），
`image-rendering:pixelated`；紧凑入场 `tomatoCompactIn .42s`、待机 `tomatoTechWiggle
1.1s steps(2)`（7378/7385），电路闪 `tomatoCircuitBlink`、高光 `tomatoShineTech`。
完成弹层 `.pomodoro-complete-overlay`（`z-index:2147483000`，盖一切）大番茄走 10px 网格
（`completeTomatoBounceV65`，8152），卡片 conic 光环 `completionAuraSpinV65 4.8s`、扫光
`completionScanV65`、入场 `completionCardInV65 .72s`，粒子 `completionParticleV65 1.45s`
（含 `.line` 流星变体）。

> **关键复刻警示**：`box-shadow` 像素画在 QML 无等价。像素番茄（mini 8px / 大 10px /
> 完成弹层大番茄）一律改用**导出 PNG sprite（`Image` + `smooth:false`）**或
> `Canvas`/`Repeater<Rectangle>` 在网格上重绘；`conic-gradient` 旋转光环用
> `ConicalGradient`(QtGraphicalEffects/自绘) 或一张 conic PNG `RotationAnimation`，必要
> 时 shader。`mix-blend-mode:screen`（番茄电路覆盖）QML 无原生，近似加色或 shader。

---

## §2 从零搭就要搭对的管线 · 根因清单（greenfield 版）

备忘页无历史 QML，故不是"返工"而是"一次搭对"。下列是若按 CSS 直译会踩、必须从一
开始就处理的管线点：

| # | 管线点 | 直译会出的问题 | 正确做法 | 详见 |
|---|------|--------------|---------|------|
| **M0** | backdrop-filter（黑板糊首页） | QML `MultiEffect` 只能糊*源 item*，糊不了"身后已绘内容" | 备忘覆盖时**首页是已知的**——对首页内容快照（或共享同一被模糊的背景层）做一次重模糊，黑板半透叠其上 | §4.1 |
| M1 | 自由手绘画布 | 直接每帧重绘全画布会卡 | QML `Canvas` 增量 `markDirty`/分段 stroke，destination-out 橡皮，DPR 由 `Canvas.canvasSize`/`renderTarget` 处理 | §4.3 |
| M2 | 点阵底纹 DPR | CSS 点阵是逻辑 px，QML 纹理不自动按 DPR | 点阵纹理按 `Screen.devicePixelRatio` 超采样绘制，`smooth` 关（点要硬） | §4.2 |
| M3 | 脏辉光边 | 渐变/角辉光停止点写 `"transparent"`(=黑@0) | 终点用**同色 α0**（`Qt.rgba(r,g,b,0)`） | §4.4（同首页 §4.4） |
| M4 | 暗部大渐变 banding | QML 渐变默认不抖动，黑板 `.82–.86` 近黑大面 | 叠极淡蓝噪声 PNG(.02) 或背景一次成型 shader 内建 dither | §4.5 / §6 |
| M5 | box-shadow 像素画 | QML 无多投影像素画 | 导出 PNG sprite 或网格 Rectangle 重绘 | §1.6 / §4.6 |
| M6 | conic 旋转光环 / screen 混合 | QML 无原生 conic-gradient/screen | ConicalGradient + RotationAnimation 或 conic PNG 旋转；screen 近似加色 | §1.6 / §4.6 |
| M7 | 双描边 bevel + 边缘光对 | 只给顶高光会"平、糊" | 亮 border + 内陷暗 stroke + 顶/底内高光（复用 `GlassPanel`） | §4.7（同首页 §4.7） |

---

## §3 复刻管线对照表（HTML 层 → QML 技法 → 需 shader？）

| HTML 层 / 面 | CSS 手段 | QML 复刻手段 | 需 shader？ |
|---|---|---|---|
| 黑板底色 + 角辉光 | 竖渐变 + 2 角 radial + 黑罩 | 半透 `Rectangle`/竖 `Gradient` + 2× `GlowCircle`(同色 α0) + 压暗 Rect | 否 |
| 黑板点阵 | repeating radial-gradient 24px | `GridTexture` **点阵变体**（`ctx.arc` 填点，DPR 超采样） | 否 |
| backdrop 磨砂 | `backdrop-filter: blur(10px)` | 首页背景层/快照整体 `MultiEffect blur` 一道（等效） | 否 |
| chrome 玻璃（工具条/番茄窗/档案袋/弹层） | 渐变 + aqua 描边 + inset 高光 + backdrop blur | 复用 `GlassPanel`（半透 + 边缘光对 + 顶高光），局部模糊用 `MultiEffect` | 否 |
| 便签纸 | 扁平 `#FFE6A3` + 接触软阴影 | `FrostCard`/`RoundedFrame` 着 `stickyPaper` 色 + 离屏软阴影 Rect | 否 |
| 文字层 | 暗玻璃渐变 + aqua 边 | `FrostCard` 暗态 | 否 |
| 自由手绘墨水 | `<canvas>` 即时栅格 | QML `Canvas`（pen/eraser，§4.3） | 否 |
| 工具/状态过渡（滑入、弹层、雪佛龙） | CSS transition | `Behavior on x/opacity/rotation` + `Easing.Bezier` | 否 |
| 档案袋开合 3D | rotateX/Z + perspective + 多层过渡 | `transform: Rotation{axis.x/z}` + `NumberAnimation`（height/opacity），层片用 `Repeater` 设 `--i` 等价属性 | 否 |
| 番茄运行光效（脉冲/呼吸/扫描/流光） | 6 套 keyframes | `SequentialAnimation{loops:Infinite}` 驱动 opacity/scale/letterSpacing/glow | 否 |
| 番茄运行 conic 光环 | conic-gradient 旋转 | ConicalGradient + `RotationAnimation` 或 conic PNG 旋转 | 可选 |
| 像素番茄精灵 | box-shadow 像素画 | 导出 PNG sprite（`Image smooth:false`）或网格 Rectangle | 否（资产） |
| 暗部 anti-banding | 浏览器自动 dither | 蓝噪声 PNG(.02) **或** dither shader | 可选(premium) |
| 黑板一次成型（角辉光+竖渐变+dither） | — | 单张全屏 `ShaderEffect` | 是(premium) |

**两条路径**（同首页）：
- **务实（零 shader、零冻结改动）**：M0–M7 全用原生 + 复用组件 + 蓝噪声 PNG +
  PNG 番茄 sprite。→ 黑板/chrome **~92–95%**，动画 **~95%**，手绘 ~90%。
- **高保真（+ `.qsb`）**：黑板一次成型 shader（自带 dither）+ conic 光环 shader。
  → 补到 **~97–98%**。

---

## §4 核心技法详解（含代码）

### §4.1 黑板磨砂底（M0）：半透黑板叠在"已重模糊的背景"上
和首页 §4.1 同理——`backdrop-filter` 在 QML 无原生等价，但备忘覆盖时身后内容（首页）
是已知的。两种落地：
- **共享背景层**：备忘覆盖与首页**共用同一张已模糊的氛围背景**（`AmbientBackground`/
  Shell 的模糊层），覆盖层只叠"近黑竖渐变 + 角辉光 + 点阵"，不再单独糊。最省。
- **快照重模糊**：进入备忘时对首页内容 `grabToImage` 一张，`MultiEffect blur(blurMax≈40)`
  后作覆盖层底。切换/退出按 §1.1 的 `opacity .26s` 淡入淡出。

```qml
Item {                                   // 黑板覆盖层
    id: memoOverlay
    anchors.fill: parent; visible: opacity > 0; opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }

    // L0 已模糊的首页（共享层或快照）——略
    Rectangle {                          // L1 近黑竖渐变
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(9/255,11/255,18/255, 0.82) }
            GradientStop { position: 1; color: Qt.rgba(6/255,8/255,14/255, 0.86) }
        }
    }
    GlowCircle { /* aqua 左上 18%,12% */ glowColor: ml.glowCyan; glowOpacity: 0.06 }
    GlowCircle { /* violet 右下 76%,72% */ glowColor: ml.violet;  glowOpacity: 0.055 }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.10) }   // 10% 黑罩
    MemoDotTexture { anchors.fill: parent; dotColor: Qt.rgba(1,1,1,0.105); pitch: 24 }  // L2 点阵（§4.2）

    Canvas { id: inkLayer; anchors.fill: parent }   // 透明墨水层（§4.3），在点阵之上
}
```

### §4.2 点阵底纹（M2）：`GridTexture` 的点阵变体
现有 `GridTexture.qml` 画的是**交叉网格线**（moveTo/lineTo）；备忘要的是**填充圆点**。
复用其结构（`Canvas` + `lineColor`/`cell`/`textureOpacity` 属性 + resize 时 `requestPaint`），
把绘制改成点：
```qml
// MemoDotTexture.qml（基于 GridTexture 的点阵变体）
Canvas {
    property color dotColor: Qt.rgba(1,1,1,0.105)   // 终值白 10.5%
    property real pitch: 24                          // 24px 平铺
    property real dotRadius: 1                        // 1px 半径
    onPaint: {
        var ctx = getContext("2d"); ctx.reset()
        ctx.fillStyle = dotColor
        for (var y = pitch/2; y < height; y += pitch)
            for (var x = pitch/2; x < width; x += pitch) {
                ctx.beginPath(); ctx.arc(x, y, dotRadius, 0, Math.PI*2); ctx.fill()
            }
    }
    onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
}
```
DPR：让 `canvasSize = Qt.size(width*dpr, height*dpr)`、`tileSize` 同步，使点不糊。
点要硬边——别开 `smooth`。`pitch`/`dotColor` 进 `MemoryLakeStyle` 作 token
（`memoDotColor`/`memoDotPitch`），勿内联。

### §4.3 自由手绘画布（M1）：QML `Canvas` 即时栅格
1:1 对齐 v88 的栈式栅格模型（无矢量）。要点：DPR 缩放、`destination-out` 橡皮、
分段 stroke、节流保存。
```qml
Canvas {
    id: ink; anchors.fill: parent
    renderTarget: Canvas.FramebufferObject; renderStrategy: Canvas.Cooperative
    property real dpr: Screen.devicePixelRatio
    canvasSize: Qt.size(width*dpr, height*dpr)     // 背存按 DPR（对齐 16266–16270）
    property string tool: "pen"                      // pen|eraser|none|note|text
    property real lastX; property real lastY; property bool drawing: false

    function strokeTo(x, y) {
        var ctx = getContext("2d")
        ctx.lineCap = "round"; ctx.lineJoin = "round"           // 16273–16274
        ctx.globalCompositeOperation = tool === "eraser" ? "destination-out" : "source-over"  // 16570
        ctx.strokeStyle = tool === "eraser" ? "rgba(0,0,0,1)" : "rgba(255,236,150,.96)"        // 16571 暖粉笔黄
        ctx.lineWidth   = tool === "eraser" ? 28 : 4                                            // 16572
        ctx.beginPath(); ctx.moveTo(lastX, lastY); ctx.lineTo(x, y); ctx.stroke()
        lastX = x; lastY = y; ink.markDirty(Qt.rect(0,0,width,height))
    }
    MouseArea {
        anchors.fill: parent; enabled: ink.tool === "pen" || ink.tool === "eraser"
        onPressed: (e) => { ink.drawing = true; ink.lastX = e.x; ink.lastY = e.y }
        onPositionChanged: (e) => { if (ink.drawing) ink.strokeTo(e.x, e.y) }
        onReleased: { ink.drawing = false; memoStore.saveCanvas() }   // 节流细节见功能文 §2.3
    }
}
```
墨水色 `rgba(255,236,150,.96)`（暖粉笔黄 #FFEC96）+ 黑板暗底 = 字面意义的"粉笔黑板"。
**橡皮 destination-out 只擦墨水层、不擦点阵底**（点阵是独立背景层，正确）。墨水色/笔宽
进 `MemoryLakeStyle`（`memoInk`/`memoPenWidth=4`/`memoEraserWidth=28`）。栈式栅格的缩放
重采样软化是 v88 既有行为（§7）；要更脆可加矢量 stroke 模型（v88 没有，属增强）。

### §4.4 干净辉光（M3）—— 同首页 §4.4
角辉光、便签软阴影、番茄光环的渐变停止点一律用**同色 α0**，不用 `"transparent"`。
`GlowCircle`（Canvas radial）边缘本就干净，优先复用。

### §4.5 anti-banding（M4）—— 同首页 §4.5
黑板 `.82–.86` 近黑大面最易出带状。务实：全屏叠 64×64 蓝噪声 PNG `opacity:0.02`
（资源文件，进不冻结的 `resources/CMakeLists.txt`）。高保真：黑板一次成型 shader 末尾
`color.rgb += (hash(fragCoord)-0.5)/255.0`（§6）。

### §4.6 像素番茄与运行光效（M5/M6）
- **像素番茄**：把 v88 的 box-shadow 像素画**离线渲成 PNG sprite**（mini/大/弹层三尺寸，
  按 8px/10px 网格 1:1），QML 用 `Image { smooth: false }`（保持像素硬边）。或用
  `Repeater` 按调色板偏移表摆 `Rectangle`（更可主题化但更重）。放 `resources/memorylake/`。
- **运行光效**：6 套 keyframes 映射为 `SequentialAnimation{loops:Infinite}` 控
  opacity/scale/`Text` 的 letterSpacing/glow 强度；时长照搬（2.8/1.8/1.05/1.6/1/1.3s）。
  开始迸发/完成双闪用 `SequentialAnimation` 一次性触发（参 cookbook §6.5 微交互）。
- **conic 光环**：`ConicalGradient`（自绘/QtGraphicalEffects）或一张 conic PNG
  `RotationAnimation { loops:Infinite; duration:2800/4800 }`。`mix-blend-mode:screen`
  的电路覆盖近似为加色叠层或 shader。

### §4.7 玻璃 chrome 的边缘光对 + 双描边（M7）—— 复用 `GlassPanel`
工具条/番茄窗/档案袋/弹层全是同一套暗玻璃（aqua 描边 + inset 顶高光 + 外投影 +
backdrop blur）。直接用 `GlassPanel`（已含顶高光 + 更亮底沿 + 可选离屏阴影），按各面
调 `radius`/描边 alpha；局部 backdrop 模糊用 `MultiEffect`（番茄窗 blur22、工具条
blur18、档案袋随玻璃）。便签/文字层/页面行用 `FrostCard`（tier-2 frost + accent tint）。

---

## §5 架构决策（最高杠杆）

### §5.1 覆盖层与首页的合成关系（对应 M0）
**裁决**：备忘是**模态覆盖层**，盖在首页之上、`z-index:120` 之上再排 chrome
（toolbar 126 / save-status 127 / 番茄 128 / 档案袋 129 / 完成弹层最高）。背后首页的
"磨砂"用**共享已模糊背景层**（首选，零额外开销）或进入时 `grabToImage` 快照重模糊。
**不要**试图实时 backdrop-filter。

### §5.2 黑板背景层 vs 透明墨水层 vs DOM 对象层（三层分离）
1:1 对齐 v88 的关键架构：**点阵/角辉光/竖渐变是背景层；`Canvas` 墨水是透明中间层
（橡皮 destination-out 只作用于此）；便签/文字是其上的独立交互对象层（z 123/124）。**
三层分离保证"擦墨水不擦点阵、不擦便签"。每个**页面**owns 三样：标签、画布 PNG、对象
JSON（详见功能文 §3 数据模型）。

### §5.3 像素美术走资产管线，不走属性直译（对应 M5）
像素番茄是本页唯一"CSS 做法在 QML 无等价"的点。**定为资产决策**：离线导出 PNG sprite
进 `resources/memorylake/pomodoro/`（不冻结），而非试图用 QML 模拟 box-shadow 像素画。
这把"像素保真"从渲染问题降为打包问题。

---

## §6 自写 Shader：清单、可行性、构建路径

可行性同首页（已核实）：顶层 `CMakeLists.txt` 冻结，但 `resources/CMakeLists.txt`
**不冻结**（flat `TIME_ARC_RESOURCE_FILES` + `PARENT_SCOPE`）。**不走** `qt6_add_shaders`
（会动冻结文件），改走预编译资源：写 `.frag` → 离线 `qsb` 编译 → 放
`resources/memorylake/shaders/` 并加进 `TIME_ARC_RESOURCE_FILES` → `ShaderEffect {
fragmentShader: "qrc:/qt/qml/time_arc/resources/memorylake/shaders/…qsb" }`。**零冻结
改动、零 change-proposal。**

**建议自写（按收益）：**
1. **黑板一次成型 shader**（首选 premium）：单张全屏 `ShaderEffect`，片元算 2 角辉光
   + 竖向近黑渐变 + 点阵 + **内建 dither**，一次绘制取代多层叠加，天然无 banding/脏边。
2. **番茄 conic 光环 shader**（可选）：运行态旋转 conic + 径向辉光，比 ConicalGradient
   旋转更可控、无锯齿。
3. （可选）便签/弹层 inset 多重阴影合成器——收益小，优先级最低。

> 原则：能用务实路径（§4）达标就别上 shader。Shader 只补黑板去 banding 与 conic 光环
> 这最后 ~3%。

---

## §7 复刻分级与诚实天花板

| 维度 | 可达 | 说明 |
|---|---|---|
| 黑板底色/角辉光/点阵/玻璃 chrome/圆角/投影/边缘光对 | **~98%** | 纯参数对齐 + 复用组件，QML 原生足够 |
| backdrop 磨砂（"backdrop-filter"） | **~98%** | 共享/快照重模糊=等效；非真·实时但覆盖层不需要 |
| 编排动画（滑入/弹层/档案袋 3D/番茄 6 光效/完成弹层） | **~95%** | QML 缓动 1:1；唯 conic 旋转、screen 混合需近似/shader |
| 像素番茄精灵 | **~97%** | 走 PNG sprite 资产，像素 1:1；唯 box-shadow 做法不可照搬 |
| 自由手绘画布（pen/eraser） | **~90%** | 栈式栅格 1:1，但无矢量模型→缩放重采样软化（v88 既有缺陷，非 QML 短板）；DPR 处理到位即与浏览器同级 |
| anti-banding / 干净辉光边 | **~95%** | 蓝噪声/同色 α0 / dither shader 到位即与浏览器同级 |
| `mix-blend-mode:screen`（番茄电路覆盖） | ~85% | QML 无原生 screen，近似加色 |

**结论：黑板 + chrome ~98%，动画 ~95%，手绘 ~90%。** 需要 shader 的只有黑板去
banding 与 conic 光环这最后几个百分点，且走不冻结的资源路径。像素番茄走 PNG 资产即可
1:1，不是渲染瓶颈。

---

## §8 实施顺序（建议批次）

1. **M-B1 黑板底（§4.1/4.2/5.1/5.2）**：覆盖层 + 共享/快照磨砂 + 近黑渐变 + 2 角辉光
   + 点阵纹理 + 三层分离骨架（背景/透明 Canvas/对象层）。← 最大杠杆，先做。
2. **M-B2 玻璃 chrome（§4.7）**：用 `GlassPanel` 搭工具条/番茄窗/档案袋/弹层；
   `FrostCard` 搭便签/文字/页面行；补 backdrop 局部模糊。
3. **M-B3 工具与过渡（§3 过渡行）**：toolbar 滑入、tool active aqua→violet、hint pill、
   更多弹层、保存状态 pill；雪佛龙旋转等微过渡。
4. **M-B4 手绘画布（§4.3）**：pen/eraser `Canvas`，DPR，destination-out，节流保存（细节
   交功能文 §2.3）。
5. **M-B5 像素番茄资产（§4.6/5.3）**：导出 mini/大/弹层三 PNG sprite，落资源。
6. **M-B6 编排动画（§4.6）**：档案袋开合 3D、番茄 6 运行光效、开始/完成触发、完成弹层
   conic 光环 + 粒子。
7. **M-B7 干净辉光 + anti-banding（§4.4/4.5）**：同色 α0 全面清查；蓝噪声 PNG 叠层。
8. **M-B8 premium（§6）**：若仍见 banding/conic 锯齿，上黑板一次成型 shader / conic shader。

每批用既有验证法（kill TimeArc.exe → qml.exe + grabToImage → 品红底 3× 超采样逐像素门）
对照 v88 截图比对。动画批用录屏逐帧/关键时刻截图比对时长与缓动。

---

## §9 与既有文档关系

本文是 TimeArc 美术复刻文档族中**备忘页（memo / 黑板点纸 / 便签 / 番茄钟 / 画布）**
专题的「管线 / 合成层」一员，沿用首页三件套确立的分工：
`memory-lake-art-lighting-qml-cookbook.md` 是**技法 / token 字典**（用什么值、摆什么灯、
复用哪个组件——本文所有技法尽量 `→ §x.y` 引它，不重新推导）；
`memory-lake-home-art-implementation-spec.md` 是**首页条款式法规**；
首页 `memory-lake-home-render-pipeline-replication.md` 是首页的管线复刻文，**本文与之
同构（§0–§9）**，是它在备忘页上的对应物。

配套的 `memory-lake-memo-functional-replication.md` 负责**功能 / 交互 / 状态 / 持久化
+ 复刻规则·标准·步骤**，并集中列出 v88 设计稿尚未实现/待用户补充的功能缺口。二者共享
同一套 `MemoryLakeStyle` 令牌与既有 `qml/desktop/memorylake/*` 组件（GlassPanel /
RoundedFrame / GridTexture / GlowCircle / FrostCard / SilkyFlickable），不引入手册之外
的新做法。

实施时：法规验收（功能文 §5）→ 手册查技法 → 本文查合成与 shader → 功能文查行为与状态。

> 新增 token 建议（落 `MemoryLakeStyle.qml`，勿内联）：`memoInk = #FFEC96 @.96`、
> `memoPenWidth = 4`、`memoEraserWidth = 28`、`memoDotColor = rgba(1,1,1,.105)`、
> `memoDotPitch = 24`、`stickyPaper = #FFE6A3`、`pomodoroRed = #FF5B5E 家族`、
> `pomodoroAmber = rgba(255,230,163,*)`。aqua/violet 复用既有 `glowCyan`/`violet`。
