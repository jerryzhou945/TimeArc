# 记忆湖 1:1 复刻实施计划

> 目标：把 `MemoryLakeDesign/memory_lake_v25_win11_style.html` 的**排版、灯光、动效、交互系统**完整搬进
> `qml/desktop/pages/DesktopMemoryLakePage.qml` 这个占位符，做到视觉与交互 1:1。
>
> 本文档同时满足 `.harness/rules/07-product-ai-cards.md` §6 的文档要求。开工走 **Track B**：
> 先 `python .harness/tools/preflight.py --track B`，收尾 `python .harness/tools/harness_check.py`。
>
> **三条硬要求（贯穿全程，验收一票否决）**
> 1. **所有丝滑交互必须复刻**：流畅翻卡、缓动滚动、自定义滚动条、边界回弹，手感逐参数对齐设计稿，且全程 60fps。
> 2. **所有灯光尽力复现**：毛玻璃、模糊大背景、角向光晕、霓虹辉光、流光、节点/涟漪发光，尽可能逼近。
> 3. **做不到的必须如实记录**：凡 QML 无法 100% 还原 HTML 的地方，写进 `docs/memory-lake-fidelity-gaps.md`，
>    说明差在哪、能到几成、折中方案——不许假装做到了。

---

## 0. 已锁定的范围决策

| 决策点 | 结论 | 含义 |
|---|---|---|
| 窗口外壳 | **只复刻窗口内部三栏** | 丢弃 HTML 里的假桌面、桌面图标、任务栏、Win11 标题栏与三按钮。三栏内容 + 月度回顾覆盖层直接铺进现有内容区（`pageLoader` 的 22px margin 之内）。 |
| 数据来源 | **先写死演示数据 → 后接真实数据** | 阶段一用设计稿原样的演示数据（8幡出口/千恋万花/ELDEN RING…）把视觉/动效/交互 1:1 跑通；阶段二换成 `usageStatManager` / `frontmostRepository` 的真实数据。 |
| 主题 | **跟随白天/夜晚** | 夜晚模式 = 设计稿深色霓虹配色（1:1）；白天模式 = 派生一套浅色映射。动效/排版/交互两套主题完全一致，只换色板。 |

> 注意：本计划**不复刻**这些纯演示外壳：`.desktop / .desktop-icons / .taskbar / .titlebar / .traffic / .win-controls / .hint`。
> 它们是浏览器 demo 的包装，不属于 App 内嵌页面。窗口拖动/最大化/最小化逻辑一并丢弃（App 主壳已负责窗口）。

---

## 1. 复刻要素清单（必须 1:1 的内容）

### 1.1 排版（Layout）
- **三栏**：`300px / 1fr / 310px`，列间距 18，内边距 18，铺满内容区。
- **左栏**：用户卡 → 「使用总览」+「今日主题」双列 → Monthly Recap CTA → APP 使用排行（9 项，可滚动）。
- **中栏**：`cards-zone`（中线、左上角 wheel-tip、卡牌水平轨道、选中卡放大居中、底部锁定徽标）。
- **右栏**：详情卡（封面图+类别+心情+分析）→ 使用时间图/时间河流（纵轴+节点条+涟漪+刻度）→ 两条 note。
- **月度回顾**：11 屏 + 右侧步骤目录 + 底部进度条 + 点击提示。

### 1.2 灯光（Lighting / 质感）— 尽力 100% 复现
> 目标是把下列每一处灯光都还原。受 QML 能力限制无法 100% 的（如 backdrop 实时模糊、mix-blend-mode），
> 已逐条记录在 **`docs/memory-lake-fidelity-gaps.md`**，实现时按该文档的折中方案处理并保持诚实。

- 毛玻璃：窗口、三栏、各卡、pill 的 `backdrop-filter: blur` 质感。
- 大图氛围：窗口背后跟随当前 APP 的**大尺寸模糊背景图**（`--selected-bg`，opacity≈.34，blur≈42）。
- 渐变光晕：窗口 `::before/::after` 的角向 radial 光、`cards-zone` 中心 radial、卡牌选中 drop-shadow 辉光。
- 霓虹色板：`--ml-aqua #9FE7EE / --ml-violet #9B8BFF / --ml-pink #D88AAC`，深底 `#05070D`。
- 时间河流：节点条辉光、节点圆点 glow、涟漪圈 box-shadow。
- 回顾层：`summary-wave` 流光、`summary-glow-ring` 底部光环、`summary-bg-app` 模糊主角图。

### 1.3 动效（Animation）— 含「丝滑」硬要求
- **卡牌**：宽高/位移/滤镜/透明度 .32s 过渡；翻面 `rotateY(180deg)` .68s `cubic-bezier(.2,.8,.2,1)`；选中放大上浮；悬停 `is-previewed` 预览。**翻卡必须顺滑无撕裂、无跳帧**。
- **卡轨**：选中后整轨 `translate` .42s `cubic-bezier` 居中。
- **丝滑滚动（重点）**：rAF 缓动（每帧逼近 0.22）+ 到边界回弹（左栏/右栏/排行/回顾内滚动）。
  - 自定义**滚动条**外观（细霓虹 thumb、半透明 track）要一并复刻，滚动条随内容平滑移动。
  - 鼠标滚轮要走缓动而非瞬跳；统一封装 `SilkyFlickable`，四处复用，逐参数对齐设计稿手感。
- **回顾开/关**：覆盖层 opacity+scale；shell `translateY`+blur；glow-ring scale；wave skew 平移；topbar/stage/side/progressbar **错峰**入场（transition-delay 0.08→0.28s）。
- **分屏转场**：`zoom / wipe / rise / rotate / ticket` 五种 keyframes；屏内元素按 `--d` 错峰 `recapRise`；离场 `leaving-left/right`。
- **自动播放**：前两屏 3.2s、其后 4.2s 推进；进度条 fill；步骤目录 active + `scrollIntoView`。
- **主角特写**：`appCardHero`(rotateY) / `posterReveal`(scale+rotate) / `stripSlide` / `orbitPop` 等 hero 动画。
- **CTA**：`recap-launching` 脉冲。

### 1.4 交互系统（Interaction）
- 切换当前记忆：滚轮 / 点排行项 / 点卡牌。
- 点中心卡牌 → 翻面看分析；**翻面即锁定**：滚轮、排行点击、其它卡牌全部禁用，wheel-tip 文案切换。
- 悬停预览态。
- 回顾：CTA 打开 → 自动播放 → 点画面=下一屏 → 暂停/继续 → **看完后**解锁目录、支持滚轮/方向键/点目录自由回看 → ESC/返回关闭。
- 全局丝滑滚动 + 边界回弹。

---

## 2. HTML → Qt6/QML 技术映射（Qt 6.11，已确认可用）

| 设计稿手法 | QML 实现 |
|---|---|
| `backdrop-filter: blur()` 毛玻璃 | 面板：半透明 `Rectangle` 叠色近似；需要真实背景模糊处 用 `MultiEffect{ blurEnabled:true }` 作用于 `ShaderEffectSource` 快照。 |
| 模糊大背景图 `--selected-bg` | `Image` + `MultiEffect{ blur, brightness, saturation }`，`source` 绑定当前卡封面。 |
| 卡牌 `rotateY` 翻面 | `Flipable`（front/back + `Rotation{ axis.y:1 }`）或 `transform: Rotation`；`Behavior`/`NumberAnimation` 控时长缓动。 |
| `transition: cubic-bezier(.2,.8,.2,1)` | `NumberAnimation{ easing.type: Easing.Bezier; easing.bezierCurve: [...] }` 或 `Easing.OutCubic` 近似。 |
| `@keyframes`（zoom/wipe/rise/rotate/ticket） | 每种转场一个 `ParallelAnimation`（opacity+scale+translate+blur），由 `active` 状态触发。 |
| 错峰 `--d` / `transition-delay` | `SequentialAnimation{ PauseAnimation; NumberAnimation }` 或各动画 `startDelay`。 |
| 卡轨水平居中 + 滚轮切换 | `ListView{ orientation:Horizontal; highlightRangeMode: StrictlyEnforceRange; preferredHighlightBegin/End }` + `WheelHandler`。 |
| 丝滑滚动 + 回弹 | 统一封装 `SilkyFlickable.qml`：`Flickable{ boundsBehavior: DragAndOvershootBounds; flickDeceleration调参 }` + `WheelHandler` 做缓动滚动；边界做轻量回弹动画。 |
| 渐变/光晕 | `Gradient` / `RadialGradient`(QtQuick.Shapes 或叠图) / 半透明发光 `Rectangle` + `MultiEffect` glow。 |
| 趋势折线 SVG | `Qt6::Svg` 已链接 → `Image{ source:"...svg" }`，或用 `Shape{ ShapePath }` 画曲线（推荐 Shape，便于主题换色）。 |
| `::before/::after` 装饰层 | 额外 `Rectangle`/`Item` 兄弟层，`z` 排序。 |
| `position:absolute` 定位 | `anchors` + 显式 `x/y` + `z`。 |

> **现成起点**：`MemoryLakeDesign/memory_lake_qml/Main.qml` 已把三栏、翻面、滚轮切换、回顾覆盖层用 QML6 `component` 写了一版骨架，可直接拆解复用——去掉其中的 Win11 假外壳，补齐主题、丝滑滚动、11 屏回顾与全部灯光动效即可。

---

## 3. 文件结构与组件拆分

新增目录 `qml/desktop/memorylake/`（页面级私有组件，与通用 `components/` 区分）：

```
qml/desktop/
├── pages/DesktopMemoryLakePage.qml      # 重写：根容器，持模型 + 三栏 + 回顾 Loader
└── memorylake/
    ├── MemoryLakeMock.js                 # 阶段一演示数据（appData / recap 数据）
    ├── MemoryLakeStyle.qml (QtObject)    # 由 nightMode 派生的两套色板/尺寸常量
    ├── GlassPanel.qml                    # 毛玻璃面板基座
    ├── SilkyFlickable.qml                # 丝滑滚动 + 边界回弹（复用）
    ├── UsageRankList.qml / UsageRankRow.qml
    ├── CardCarousel.qml                  # 卡轨 + 滚轮 + 居中 + 锁定
    ├── MemoryCard.qml                    # 翻面卡（front/back）
    ├── DetailPanel.qml
    ├── TimeRiver.qml                     # 时间河流（轴/节点/涟漪/刻度）
    ├── RecapOverlay.qml                  # 回顾根（自动播放/进度/目录/键鼠）
    ├── RecapSlide.qml                    # 单屏壳（转场 + 内滚动 + has-scroll 提示）
    └── slides/…                          # 11 屏各自内容（封面/月历/主角/轨迹/趋势/关键词/对比/票根）
```

- 每个新 `.qml` 都要登记到 `qml/CMakeLists.txt` 的 `TIME_ARC_QML_FILES`。
- 全部声明主题契约属性（`nightMode / themeTextPrimary / …`，见 rule 04 §2），白天默认值合理、独立预览不崩。

---

## 4. 数据契约与 mock → real 映射

**阶段一**：`MemoryLakeMock.js` 原样照搬设计稿的 9 个 APP（名称/类别/时长/进度/心情/分析/`data-nodes` 时段）与 11 屏回顾文案、月历 7 柱、关键词、对比数字、票根。封面图用已就位的 `resources/memorylake/{exit8,senren,elden,p3r,desktop}.png`。

**阶段二**：换成真实数据（**不改服务端磁盘契约**，只读现有只读接口）：

| UI 字段 | 真实来源 |
|---|---|
| APP 排行 / 卡牌列表 | `usageStatManager.softwareForRange("day")` → `{name, seconds, time, appId, path, foregroundSeconds, audioSeconds}`；进度条 = `seconds / maxSeconds`。 |
| 卡牌图标 | `image://appicon/<path>`（`AppIconImageProvider`，rule 04 §5），勿入库。 |
| 时间河流节点 | `frontmostRepository.getSessionsByRange(dayStart, dayEnd)` 按 `appId` 过滤 → 区间 `{start,end}`，y 按时刻、宽按时长映射。 |
| 月度总量/最高类别/最活跃时段 | `softwareForRange("month")` + `softwareSecondsForRange("month")` 聚合。 |
| 心情/分析文案 | **本地确定性模板**（按类别/连续时长/启动次数生成，参考 `DailyCardService`）。**禁止把原始日志喂 AI**（rule 07 §5）。 |

> **需要补的 C++（阶段二 follow-up，先在 `.harness/state/open-issues.md` 记一笔，不阻塞阶段一）**：
> 1. 月度**按天**时长序列（月历 7 柱 + 趋势折线）——`usageStatManager` 目前是 range 桶聚合，需加 `dailySecondsForMonth()` 之类。
> 2. **环比上月**——需上月 range 聚合对比。
> 3. **大封面图策略**——真实 APP 没有游戏海报，需按类别给一套通用艺术图或用模糊放大的应用图标兜底。
> 4. 关键词生成——本地模板，非 AI。

---

## 5. 主题适配（白天/夜晚，保持 1:1）

- **夜晚** = 设计稿原值：深底 `#05070D`、玻璃 `rgba(255,255,255,.03~.07)`、霓虹 aqua/violet/pink、文字 `rgba(255,255,255,.88/.56/.34)`。
- **白天** = 派生映射（接现有 `themeTextPrimary` 等注入）：浅奶杏底、降低发光强度、文字用 `themeTextPrimary/Secondary`、强调色用 `themeAccentColor`。
- `MemoryLakeStyle.qml` 用 `nightMode` 三元集中产出两套色板；**布局尺寸、动画时长/曲线、交互逻辑两套主题完全相同**，只换颜色与发光强度。
- 回顾覆盖层即使白天也保持较暗的沉浸基调（仅小幅提亮），保证"记忆回放"氛围。

---

## 6. 分阶段实施步骤

**阶段 A — 骨架与排版（静态 1:1）**
1. 重写 `DesktopMemoryLakePage.qml` 为根容器，铺三栏 grid，接主题契约属性。
2. 落 `GlassPanel / MemoryLakeStyle`，把左/中/右三栏静态结构与配色按稿摆好（用 Mock 数据静态渲染）。
3. 验收：三栏排版、配色、玻璃质感与设计稿截图逐栏对齐。

**阶段 B — 中栏卡牌交互**
4. `MemoryCard`（翻面）+ `CardCarousel`（滚轮/点击切换、居中、选中放大、预览、翻面锁定、锁定徽标、wheel-tip 文案）。
5. 右栏 `DetailPanel` + `TimeRiver` 跟随当前卡更新；窗口背后模糊大图 `MultiEffect` 跟随。
6. 验收：切换/翻面/锁定/预览四态、时间河流节点动态、背景图过渡，与稿一致。

**阶段 C — 丝滑滚动**
7. `SilkyFlickable` 接入左栏、右栏、排行、回顾内滚动；边界回弹。

**阶段 D — 月度回顾叙事**
8. `RecapOverlay` 开/关动画（错峰入场/离场）、自动播放（3.2/4.2s）、进度条、点击下一屏、暂停/继续。
9. 11 屏 `RecapSlide` + 五种转场 + 屏内 `--d` 错峰 + hero 动画（poster/orbit/strip/app-focus/ticket/趋势 SVG/关键词云/月历/对比）。
10. 看完解锁目录、滚轮/方向键/点目录回看、ESC 关闭、`has-scroll` 长内容滚动提示。
11. 验收：与设计稿逐屏对照（转场类型、错峰节奏、目录解锁、键鼠导航）。

**阶段 E — 真实数据接入**
12. 把 Mock 替换为 §4 的真实接口；补 mood/分析本地模板；空数据兜底（复用现有空态文案）。
13. 月历/趋势/环比/关键词：依赖的 C++ 扩展若未就绪，先用真实日数据 + 占位标注，按 open-issues 跟进。

**阶段 F — 收尾**
14. 更新 `docs/`（本文件状态）、必要时 `README.md`；`harness_check.py`；冒烟路径写入 session log；如有踩坑 `record_error.py`。

---

## 7. 资源与构建改动

- `qml/CMakeLists.txt`：登记所有新增 `.qml`。
- `resources/CMakeLists.txt`：确认 `resources/memorylake/*.png`（已就位）打进资源；如新增类别封面图在此追加（rule 04 §5）。
- 趋势折线优先用 `Shape`（无新增依赖）；若用 SVG 文件则放 `resources/memorylake/` 并登记。
- **不新增第三方依赖**（rule 07 §4）。**不碰 `src/service/` 磁盘契约**（CLAUDE.md）。

---

## 8. 1:1 验收清单

- [ ] 三栏排版、间距、圆角、配色（白天+夜晚两套）逐栏对齐截图。
- [ ] 毛玻璃 + 模糊大背景图 + 各处光晕/辉光质感到位。
- [ ] 卡牌：切换/翻面(.68s rotateY)/选中放大/悬停预览/翻面锁定 四态一致，**翻卡顺滑无撕裂**。
- [ ] 卡轨居中过渡(.42s cubic-bezier)、滚轮节流、排行联动。
- [ ] 时间河流：节点位置/宽度/辉光/涟漪/刻度跟随当前卡。
- [ ] **丝滑滚动**：缓动滚轮 + 四处边界回弹 + 自定义霓虹滚动条平滑移动，**全程 60fps**。
- [ ] 回顾开/关错峰动画、自动播放节奏(3.2/4.2s)、进度条。
- [ ] 11 屏内容、五种转场、屏内错峰、hero 动画逐屏对照。
- [ ] 看完解锁目录、滚轮/方向键/点目录/ESC 全部可用。
- [ ] 灯光逐处对照设计稿；无法 100% 的项已在 `docs/memory-lake-fidelity-gaps.md` 如实标注。
- [ ] App 能启动，记忆湖页可见、无报错（QML warning 清零）。

---

## 9. 风险与对策

> 完整的「做不到/做不全」清单见 **`docs/memory-lake-fidelity-gaps.md`**（含每项可达几成 + 折中）。下表只列实施风险。

| 风险 | 对策 |
|---|---|
| QML 无 CSS 真·backdrop blur（最大灯光差距） | 面板用半透明叠色近似；只在背景大图/回顾层用 `MultiEffect` 真模糊，控制开销。详见 gaps 文档 🔴1。 |
| 多层 MultiEffect 模糊拖慢帧率，反而不丝滑 | 真模糊层 ≤3、不逐帧刷新；翻卡/滚动等高频交互不叠 blur。**丝滑优先于逐像素灯光**。 |
| `cubic-bezier(.2,.8,.2,1)` 精确还原 | 用 `Easing.Bezier` + 原始控制点；卡顿则退 `Easing.OutCubic`。 |
| 11 屏 hero 动画工作量大 | 阶段 D 按屏推进，先转场+错峰，再逐个 hero；每屏独立 `.qml` 便于对照。 |
| 真实数据缺月度日序列/封面图 | 阶段一不受影响；阶段二按 open-issues 补 C++，先占位标注，不阻塞主流程。 |
| 主题适配偏离设计稿 | 夜晚严格对齐设计稿原值；白天仅做派生，布局/动效/交互不变。 |
| MultiEffect 性能 | 限制模糊层数量与刷新频率；切换卡牌时只更新一处大图。 |

---

## 10. 不做的事（防跑偏，rule 07 §4）

- 不复刻假桌面/任务栏/Win11 标题栏与窗口三按钮。
- 不加 IPC/socket/共享内存，不碰 `src/service/` 磁盘契约。
- 不在 MVP 引入 AI 文案、截图、OCR、原始音频、浏览器历史。
- 不新增第三方库；不顺手重构其它页面。
