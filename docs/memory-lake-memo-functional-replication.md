# 记忆湖备忘页 · 功能复刻规范（行为 / 状态 / 复刻规则·标准·步骤）

> 备忘页专题的「功能 / 交互 / 状态」文档，与美术管线文
> `memory-lake-memo-render-pipeline-replication.md` 配套。美术文管"黑板那层质感怎么
> 1:1 合成"；**本文管"点进去之后那块黑板能做什么、状态怎么流转、数据怎么存、QML 怎么
> 搭、验收到什么程度，以及 v88 设计稿里哪些功能尚未实现需用户补充"。**
>
> 行为事实源：`MemoryLakeDesign/TimeArcDesign_v88.html` 的 `<script>`（备忘相关
> 16236–17750 + 完成弹层 IIFE 18380–18533），行号均取自原文件、JS 逐字摘录。CSS 终值
> 见美术文。本文遵循首页法规的条款体例：**【必须】**（验收硬条件）/ **【应当】**
> （强烈建议，偏离须在 PR 说明）/ **【可选】**（加分项）。

---

## §0 概览：备忘页是什么

点击左导航「备忘录」（`#openMemoBtn`，DOM 13704）后，弹出一块**模态黑板覆盖层**
（`#memoOverlay`）。它是一个**有状态的交互系统**，与首页（基本静态）根本不同。能力清单：

- **顶部工具条**（topbar）：创建便签 · 文字 · 画笔 · 橡皮擦 · 更多工具（番茄钟 / 日历）·
  退出。工具互斥，再点当前工具即取消。
- **黑板画布**：画笔自由手绘（暖粉笔黄墨水）、橡皮擦（destination-out）；逐页持久化。
- **便签**：点画布生成，可拖动、编辑（标题 + 正文）、四向缩放、键盘删除、逐页持久化。
- **文字层**：点画布生成，可直接编辑、Alt 拖动、× 删除、逐页持久化。
- **右上档案袋**（top-right bar）：**页面管理**——切换 / 新增 / 删除 / 重命名备忘页，每页
  owns 自己的画布 + 对象；开合是 3D 抽屉动画。
- **番茄钟**（浮窗）：标题 + 分/秒自定义，开始/暂停/重置，运行时**自动收缩成像素番茄**
  + 大量运行光效动画，完成时全屏庆祝弹层。

> **数据边界**：备忘内容是 **UI 本地状态**，v88 用 `localStorage`。它**不属于**
> 服务-UI 磁盘契约（`usage_record`/`data_bridge` 等冻结契约），**不得**写进 JSONL/服务
> 路径，也**不得**让服务读它。QML 端用 `Qt.labs.settings`/独立 JSON 文件/本地 SQLite
> 之类的 **UI 私有持久化**即可（见 §3）。这条是硬边界。

---

## §1 QML 组件架构（greenfield 组件树）

`qml/desktop/memorylake/` 现**无任何**备忘组件（grep 确认）。建议新增（均放该目录，
`qml/` 不冻结；新组件经可编辑的 `qml/CMakeLists.txt` 注册）：

```
MemoOverlay.qml            模态覆盖层壳：开合、三层分离骨架、键盘路由、聚焦守卫
├─ (背景层)                黑板底：近黑渐变 + 2 角辉光 + 点阵（详见美术文 §4.1/4.2）
├─ MemoInkCanvas.qml       透明墨水层：pen/eraser（QML Canvas，美术文 §4.3）
├─ (对象层 Repeater)       便签 + 文字层，绑定 MemoPageModel.objects
│   ├─ StickyNote.qml      便签：拖动/缩放/autosize/选中/删除
│   └─ TextLayer.qml       文字层：编辑/Alt 拖动/删除
├─ MemoToolbar.qml         顶部工具条：工具互斥、hint、更多弹层
│   └─ MemoMorePopover.qml 番茄钟 / 日历入口
├─ MemoPageFolder.qml      右上档案袋：开合 3D、页面列表、增删切换
├─ PomodoroWidget.qml      番茄浮窗：计时状态机、收缩/展开、运行光效
└─ PomodoroCompleteOverlay.qml  完成庆祝弹层
状态 / 持久化层（非可视）：
├─ MemoPageModel           当前页内存模型：objects[] + 画布引用 + 标签
└─ MemoStore（C++/QML 单例）  逐页持久化：画布 PNG + 对象 JSON + 页列表（§3）
```

**【必须】** 所有颜色 / 圆角 / 缓动取自 `MemoryLakeStyle`（见美术文 §9 的新增 token），
不内联 hex。**【必须】** 玻璃面复用 `GlassPanel`，圆角裁切容器复用 `RoundedFrame`，
软辉光复用 `GlowCircle`，滚动列表复用 `SilkyFlickable`，tier-2 卡复用 `FrostCard`。

---

## §2 功能子系统逐项规格（规则 / 标准 / 步骤）

> 每节给三块：**复刻规则**（v88 的确切行为，逐字事实）、**复刻标准**（验收口径）、
> **复刻步骤**（QML 落地次序）。

### §2.1 覆盖层开合

**复刻规则**（`openMemoMode` 16363 / `closeMemoMode` 16372）：
- 开：① **若当前卡片处于翻面态则拒绝打开**（`isCurrentFlipped()` 守卫，16364；锁定时
  `#openMemoBtn` 也被禁用并改 title 为"当前卡牌翻面时不可打开备忘录"，16596）；
  ② `resizeMemoCanvas()` 先按 DPR 重建画布并恢复本页墨迹；③ 加 `.open` 类（触发工具条
  滑入）；④ `renderMemoPages()`；⑤ 设保存状态文案（有存档→"已恢复 {页名} 笔迹"，否则
  "笔迹会自动保存"）；⑥ **强制 `setMemoTool("pen")`**（每次打开都重置为画笔）；
  ⑦（V52 包裹 17077）`loadMemoObjects(当前页)`。
- 合：① `saveMemoCanvas()`；②（V52 包裹 17083）先 `saveMemoObjects`；③ 移除 `.open`。
- 过渡：`opacity .26s ease`（`display:none↔block` 瞬时，淡的是 opacity）。
- `N`/`n` 键也切换备忘模式（17146，受"正在输入"守卫）。

> **⚠ 入口 = 动作，不是路由（与现有 QML 导航的关键差异，必须改）。** v88 里
> `#openMemoBtn`（DOM 13704）点击 → `openMemoMode()`，**只是把模态覆盖层盖上来**，
> 底下页面原样保留、关闭后退回原处，**全程不换页、不路由**。但现有
> `DesktopAppShell.qml` 把「备忘」接成了**页面路由**：nav 项 `{title:"备忘", page:"notes"}`
> （行 125）→ 点击 `selectedIndex = navIndex`（行 500）→ `currentPageSource` 的
> `case "notes": DesktopChatPage.qml`（行 158）= **进入一个独立界面**。这是错的，
> **必须改**：把「备忘」nav 项的点击从"切 `selectedIndex`/路由到 notes 页"改成
> **`memoOverlay.open = true`（触发覆盖层）**；`selectedIndex`/底层 `pageLoader`
> 保持不动（首页仍在覆盖层之下）。`"notes"→DesktopChatPage.qml` 路由分支随之移除
> （或 DesktopChatPage 弃用）。**不要为备忘新建一个"页面"。**

**复刻标准**：
- 【必须】点「备忘」nav **直接打开黑板覆盖层（动作）**，不切换 `selectedIndex`、不经
  `pageLoader` 加载任何"备忘页面"；关闭覆盖层后底层页面原样还在（对应上面 ⚠）。
- 【必须】卡片翻面时点击备忘入口**无反应**（与 v88 一致），且入口呈禁用态。
- 【必须】每次打开默认工具 = 画笔；打开即加载当前页墨迹 + 对象。
- 【必须】关闭前完成一次画布 + 对象保存（不丢笔迹/便签）。
- 【应当】开合用 `NumberAnimation duration:260`（淡出后再隐藏，勿用 `visible` 瞬切）。

**复刻步骤**：MemoOverlay 暴露 `open` 属性 + `Behavior on opacity`；`onOpenChanged`
触发 model 的 load/save；翻面守卫接首页 `MemoryCard`/CardCarousel 的 flipped 状态。

### §2.2 工具条 + 工具互斥

**复刻规则**（`setMemoTool` 16289 / `toggleMemoTool` 16316 / 接线 16542）：
- 工具集 `pen | eraser | note | text | none`，状态 `let memoTool="pen"`（16255）。
- `setMemoTool(tool)`：先清 4 个工具键的 `.active`，再给当前唯一一个加回；`tool==="none"`
  时给 4 个加 `.is-cancelled`；改 `#memoHint` 文案（每工具一句，16301–16307）；改画布
  光标：text→`text`、note→`copy`、none→`default`、pen/eraser→`crosshair`（16312）。
- `toggleMemoTool(tool)`：再点当前工具→`"none"`（取消），点别的→切换。
- 接线（16542）：4 个工具键各 `toggleMemoTool(自身)`；退出键→`closeMemoMode`。
- **画布 pointer-events 从不切换**——绘制纯靠 pointer 处理器里的 `memoTool` 守卫
  （16560），note/text 创建走覆盖层 click 路径（16549）。
- 更多弹层（17368）：点 `#memoMoreTool` 切 `.open`；点番茄项→关菜单 + 番茄窗 `.open` +
  `resetPomodoroFromInputs()`；捕获相点击外部关菜单。打开辅助工具**不改 `memoTool`**。

**复刻标准**：
- 【必须】任一时刻最多一个工具 active；再点 active 工具取消（→ none）。
- 【必须】hint 文案随工具变（5 句逐字对齐，见美术文 §1.2 引）。
- 【必须】光标随工具变（4 态）。
- 【应当】保留"画布始终命中、靠工具态守卫"的行为，勿用 `enabled` 关画布命中
  （否则 note/text 创建路径会变）。

**复刻步骤**：MemoToolbar 暴露 `currentTool` 信号；MemoOverlay 据此设 `inkCanvas.tool`、
hint 文本、光标；更多弹层用 `Popup`/自管 `open` + 点击外部关闭。

### §2.3 黑板手绘引擎（画笔 / 橡皮）

**复刻规则**（`resizeMemoCanvas` 16261 / pointer 16559 / `saveMemoCanvas` 16333）：
- **DPR**：背存 = `floor(innerW*dpr) × floor(innerH*dpr)`，CSS 尺寸 = 逻辑 px，
  `ctx.setTransform(dpr,0,0,dpr,0,0)` 使绘制用逻辑坐标；`lineCap/lineJoin="round"`
  在此设一次（16273）。
- **stroke**（pointermove 16567）：每个 move 事件 `moveTo(last)→lineTo(cur)→stroke()`
  一段（**无贝塞尔平滑、无点缓冲、无 rAF**，即时同步绘）。pen：`source-over` +
  `rgba(255,236,150,.96)`(#FFEC96 暖粉笔黄) + `lineWidth 4`；eraser：`destination-out`
  + `lineWidth 28`（色无意义）。坐标 = `clientX/Y`（画布全屏 inset:0，无偏移）。
- **持久化**：`toDataURL("image/png")` → `localStorage[memoCanvasKey()]`（逐页键
  `memoryLakeMemoCanvas_page_${i}`，16782）；配额溢出→状态"画布过大，无法保存"。
  **节流**：拖动中 `_lastSave` 每 >1200ms 存一次（16580）；pointerup/cancel 各强存一次
  （16587）；关闭 / 切页 / 加页前也存。
- **保存状态 pill**（`setMemoSaveStatus` 16323）：设文案、opacity→1，900ms 后→.72
  （**无 CSS transition，是硬切**，见 GAPS）。
- **逐页**：`loadMemoCanvasForPage` 16830 清画布后异步 `drawImage` 本页 PNG（identity
  变换、拉伸到背存全幅）；`clearMemoCanvasOnly` 16822 只清位图不动存储。

**复刻标准**：
- 【必须】pen/eraser 参数 1:1（色 #FFEC96@.96、宽 4 / 28、round cap/join、橡皮
  destination-out 只擦墨水层不擦点阵/便签）。
- 【必须】DPR 缩放到位（高 DPI 下笔迹清晰）。
- 【必须】逐页墨迹隔离、自动保存（拖动 1200ms 节流 + 抬笔/切页/关闭强存）。
- 【应当】保存状态有真实淡出（修 v88 的硬切，加 `Behavior on opacity`）。
- 【可选】矢量 stroke 模型以避免缩放重采样软化（v88 无，属增强）。

**复刻步骤**：MemoInkCanvas 见美术文 §4.3；`MemoStore.saveCanvas(pageIndex, image)`
落 PNG；切页时 store 先存旧页再 load 新页位图。

### §2.4 便签（创建 / 拖动 / 缩放 / 自适应 / 选中 / 删除 / 持久化）

**复刻规则**（`createStickyNote` 16377 等）：
- **创建**：note 工具下点覆盖层（16549）→ `createStickyNote(clientX-110, clientY-22)`
  （横向居中、落在 header 下）。默认 310×285、暖黄 `#FFE6A3`。建后立即选中 + 50ms 后
  聚焦标题（16498）。
- **拖动**：拖 header（默认 `opacity:0`，hover/选中升到 .22）；位置钳制
  `left∈[8, innerW-w-8]`、`top∈[84, innerH-h-8]`（顶 84 让位工具条/档案袋）；pointer
  capture；note 自身 pointerdown/click `stopPropagation`（否则 note 模式下点已有便签会
  再生一个，16432）。
- **缩放**：4 把手 = 左 / 右 / 下 / **右下角**（**无上把手 / 无上角**，高度只向下长，顶边
  钉死）；min 210×190、max `min(520,innerW-40)×min(620,innerH-120)`；left 把手长宽同时
  移左边；缩放中加 `.is-resizing`，window 捕获相监听，结束后 120ms 清
  `_suppressNextCanvasClick`（防尾随 click 再生便签）。
- **自适应**（`autosizeStickyText` 16343）：总文本 >110 字 **或** 面积 <72000px² 时加
  `.compact-text`（缩小字号）；`ResizeObserver` + input 触发。
- **选中 / 删除**：捕获相 document pointerdown（16712）点 note/text→选中、点空白画布→
  取消选中；Backspace/Delete 删选中对象（16721），但**正在该对象内编辑字段时不劫持**
  （16733）。**便签的 × 删除键终态 `display:none`，删除靠键盘**。

**复刻标准**：
- 【必须】创建偏移、拖动钳制（top≥84）、四向缩放（无顶向）、min/max 1:1。
- 【必须】autosize 阈值 1:1（>110 字 或 <72000px²）。
- 【必须】选中环 aqua `rgba(142,223,255,.58)`；键盘删除且不劫持编辑中输入。
- 【应当】统一删除入口（v88 便签靠键盘、文字层有 ×；建议两者都给可见删除 + 键盘）。
- 【应当】署名"JusTin D"参数化/可编辑（v88 写死且不存，见 GAPS）。

**复刻步骤**：StickyNote 暴露 `objectData`（见 §3 结构），拖动/缩放写回 model，model
变更触发 §2.x 的防抖保存；对象层用 `Repeater` 绑 `MemoPageModel.objects`。

### §2.5 文字层（编辑 / Alt 拖动 / 删除 / 持久化）

**复刻规则**（`createTextLayer` 16501）：
- 创建：text 工具下点覆盖层 → 在点击处建 `contenteditable` div，初值"输入文字"+ 可点 ×；
  建后选中 + 聚焦。
- **拖动需按住 Alt**（16524；非 Alt 时点击=落光标编辑）；**无位置钳制、无缩放把手**
  （靠 min-width/min-height + 内容增长）。
- 删除：自带 × 键（**不隐藏**，与便签不同）+ 键盘 Delete/Backspace（选中时）。

**复刻标准**：
- 【必须】默认点击进入编辑；拖动 Alt-gated（或在 QML 给更可发现的拖动方式 + on-screen
  提示——见 GAPS，v88 无提示）。
- 【必须】× 删除可见、可点。
- 【应当】reload 后文字层**可拖动**（修 v88 回归 bug：`recreateTextLayerFromData`
  未重新挂 Alt 拖动监听，17040，重载后无法拖）。
- 【应当】`html` 字段按纯文本 + 换行处理（v88 存原始 innerHTML，富文本回填 QML
  TextEdit 复杂，见 GAPS）。

**复刻步骤**：TextLayer 用 `TextEdit`（`textFormat: PlainText` 推荐）；拖动用
`DragHandler { acceptedModifiers: Qt.AltModifier }` 或显式拖柄。

### §2.6 页面管理（右上档案袋：多页模型 / 开合 / 增删切换）

**复刻规则**（状态 16776 / `renderMemoPages` 16790 / `switchMemoPage` 16850 /
`deleteMemoPage` 16906）：
- **一页 owns 三样**：标签 `memoPages[i]`（字符串）、画布 PNG
  `memoryLakeMemoCanvas_page_${i}`、对象 JSON `memoryLakeMemoObjects_page_${i}`。**页 = 数组
  下标**（非稳定 id）。
- 状态：`memoPages`（默认 `["Page 1"]`）、`memoCurrentPage`、`memoSelectedPageForDelete`；
  meta 存 `memoryLakeMemoPages` + `memoryLakeMemoCurrentPage`（`saveMemoPagesMeta` 16785）。
- **开合**：点 `#memoPagePill` 切 `#memoPageControl.open`（16858），外部点击关（16874）。
  开态是纯 CSS 3D 抽屉动画（详见美术文 §1.5 表）。`--page-count` 驱动长高 calc；
  `renderMemoPages` 按 `pages-1` 造厚度层（`--i` 递减喂 Z/scale/位移），按数组造页面行
  （点行→`switchMemoPage` + 关档案袋）。
- **切页**（V52 包裹 17070）：① 存旧页对象 → ② 存旧页画布 → ③ 设 index → ④ 存 meta →
  ⑤ render → ⑥ load 新页画布 → ⑦ load 新页对象。
- **加页**（16863）：存旧画布 → push `Page ${len+1}` → 设为当前 → 存 meta → render →
  **清画布**（新页空白）。⚠ **未包裹对象层**（见 GAPS：旧页便签会残留并被串写进新页）。
- **删页**（16906 + V52 包裹 17089）：**保底"至少留 1 页"**（16907）；删当前页 canvas 键
  + 对象键，把所有更高 index 的两类键**下移一位**重对齐，splice 标签，重算
  `memoCurrentPage`（钳到新长度、若在删除点之后则 -1），render + load。**标签不重命名**
  （删"Page 2"得 `["Page 1","Page 3"]`，"Page 3"名留、仅 index/键移）。
- **键盘删页**（16940）：仅"备忘开 + 档案袋开 + 非输入态 + Backspace/Delete"→
  `deleteMemoPage(memoSelectedPageForDelete)`，捕获相。
- **重命名**（QML 扩展，2026-06-05，设计稿无）：每页行 ✎ → 内联 `TextInput` 改标签
  （进入即 selectAll；回车 / 失焦 / 点前盖·行·新建 提交，Esc 取消）→ `MemoOverlay.renamePage(i,name)`
  改 `pagesData[i].label`（空 / 未变忽略）+ `scheduleSave()`。提交集中在 `folder.commitEdit()`，
  由各点击主动调（`MouseArea` 不抢键焦点，靠输入框自身失焦会丢改名）。

**复刻标准**：
- 【必须】每页隔离画布 + 对象；切页正确存旧/载新（七步序）。
- 【必须】删页保底留 1 页 + 键重对齐 + index 重算 1:1。
- 【必须】加页清空新页画布**且清空/隔离对象**（修 v88 的对象串写 bug）。
- 【应当】用**稳定页 id**（非数组下标）做存储键，避免删中间页的键漂移
  （v88 用 index，删页靠手动移键，脆弱——见 GAPS）。
- 【应当】开合 3D 动画 1:1（长高 360ms bezier、后仰 rotateX5°、层片扇开、弹层滞后 50ms、
  雪佛龙 180°）；闭合也要有过渡（v88 闭合多为 display 瞬切，建议补对称淡出）。

**复刻步骤**：MemoPageModel 持页数组 + 当前页；MemoPageFolder 用 `Repeater` 造厚度层
（每片绑 `index` 算 Z/scale/位移）+ 页面行列表（`SilkyFlickable`）；开合用 `state` +
`transitions`（`NumberAnimation` height/opacity + `Rotation{axis.x}`）。

### §2.7 番茄钟（计时状态机 + 收缩/展开 + 运行光效 + 完成弹层）

**复刻规则** —— 计时核心（V58，17311–17441）：
- 状态：`pomodoroTotal=25*60`、`pomodoroRemain`、`pomodoroTimer`、`pomodoroRunning`
  （闭包 `let`，**未挂 window**——见 GAPS 跨 IIFE bug）。
- `readPomodoroDuration`（17322）：分 clamp[1,180]、秒 clamp[0,59]。
- `startPomodoroTimer`（17352）：已跑则 return；remain≤0 先重置；`setInterval 1000ms`
  每 tick `remain-=1`，到 0 → 钳 0 + `stopPomodoroTimer` + 状态"番茄钟已完成"。
- `stopPomodoroTimer`（17345）：清 interval + `running=false` + render。**暂停=重置都走它**
  （无独立 paused 标志，paused == 停且 remain>0）。
- `renderPomodoro`（17328）：时间文本、副标题=标题值、**进度=已耗比 → 填充条 width%**
  （**非环形**）、开始键文案"开始"↔"进行中"。
- 编辑分/秒（未运行时）实时重置；浮窗可拖（17405，钳 `x∈[8,innerW-w-8]`、
  `y∈[72,innerH-h-8]`，从按钮/输入起拖忽略）。

**复刻规则** —— 收缩/展开 + 动画驱动（V59/V60/V61，17447–17646）：
- `setPomodoroVisualRunning`（17447）切 `.running`（驱动 6 套运行 keyframes）。
- `burstPomodoroParticles(count)`（17452）：均匀角 `2π·i/count`、距 42–84px、0–80ms 错峰、
  1100ms 后移除。
- 开始（V59 17472）：18 粒迸发 + `.pomodoro-start-burst` 520ms + Web-Animations 按压 squish。
- 到 0（V59 render）：24 粒 + `.pomodoro-finished` 1900ms（琥珀双闪）。
- **自动收缩**（V60 17537）：开始后 **180ms** `collapsePomodoroToTomato`（加
  `.compact-tomato`，body/titlebar `display:none`，显像素番茄 + 紧凑时间）；V61 再加 **260ms**
  兜底 `forceCompactTomatoAfterStart`（因早期监听捕获了 V58 旧 start）。500ms interval
  resync 紧凑时间。
- **展开**（`expandTomatoToPomodoro` 17549）：去 `.compact-tomato` + `.expand-burst`
  480–560ms + 18 粒；点像素番茄（mini 或壳）= **暂停 + 展开** + 状态"番茄钟已暂停"。
- 紧凑到 0 自动展开（`finished:true`）并去 running。停止（暂停/重置）总是展开。

**复刻规则** —— 完成弹层（V63/V64 主 IIFE 17649 + V65 独立 IIFE 18380）：
- 4 套文案变体（FOCUS COMPLETE/GOOD SESSION/MEMORY SAVED/WELL DONE）随机选。
- 全屏弹层 `z-index:2147483000`，卡片入场 `completionCardInV65 .72s`、conic 光环旋转、
  扫光、大像素番茄弹跳、粒子迸发（V65 88+54 粒，含 `.line` 流星）。
- 多重探测器（V63 300ms / V64 120ms / V65 100ms）轮询 `remain===0` 触发；`Ctrl+Shift+F`
  调试热键直接弹。关闭键"回到备忘录"或点背景关闭；手动重置不弹庆祝。

**复刻标准**：
- 【必须】计时状态机 1:1：idle→running(收缩)→paused(展开)→complete(展开+弹层)；tick 1Hz；
  分[1,180]/秒[0,59] clamp；开始后约 180ms 收缩成番茄；点番茄=暂停展开。
- 【必须】运行 6 套光效（aura/scan/dot/display/time/progress）时长 1:1
  （2.8/1.8/1.05/1.6/1/1.3s）；开始迸发 + 完成双闪 + 粒子。
- 【必须】完成全屏弹层（随机文案、conic 光环、大番茄弹跳、粒子）盖在一切之上。
- 【必须】像素番茄走 PNG sprite（美术文 §4.6/5.3），不照搬 box-shadow。
- 【应当】**单一干净探测器**（QML 用计时信号，弃 v88 的 3 探测器 + 跨 IIFE 残骸）。
- 【应当】进度条保持横向填充（v88 无环形）；若要环形须新设计（GAP）。
- 【可选】计时持久化 / 完成音效 / 工作-休息循环（v88 全无，见 GAPS）。

**复刻步骤**：PomodoroWidget 用 `Timer{interval:1000;repeat:true}` 计时 + 状态属性
（`running`/`remain`/`total`）；运行光效 `SequentialAnimation{loops:Infinite}`；收缩/展开
用 `state`+`transition`；粒子用 `Repeater`/`ParticleSystem`；完成弹层独立组件、`z` 最高、
进入即播一次性 `SequentialAnimation`。**只用一个 `onRemainChanged: if(remain===0) complete()`**。

---

## §3 持久化与数据模型

**v88 localStorage 键全表：**

| 键 | 内容 |
|---|---|
| `memoryLakeMemoPages` | 页标签 JSON 数组 |
| `memoryLakeMemoCurrentPage` | 当前页 index |
| `memoryLakeMemoCanvas_page_${i}` | 逐页画布 PNG dataURL |
| `memoryLakeMemoObjects_page_${i}` | 逐页对象 JSON 数组 |
| `memoryLakeMemoPagesReset_v50/_v51` | 一次性迁移标志（**勿复刻**，throwaway） |
| `memoryLakeMemoCanvas` | 旧版单画布兜底键 |

**对象序列化结构**（`serializeMemoObject` 16966；v88 存 px 字符串）：
```
sticky → { type:"sticky", left, top, width, height, title, content }
text   → { type:"text",   left, top, width, height, html }   // html 已去掉 × 按钮
```

**QML 数据模型（建议——typed，比 px 字符串更健壮）：**
```
MemoObject { string type;  real x, y, w, h;
             string title, content;   // sticky
             string text }            // text（纯文本 + 换行，替代原始 html）
MemoPage   { string id;              // ★稳定 id，非数组下标★
             string label;
             url   canvasImage;       // PNG 路径/blob
             list<MemoObject> objects }
MemoDoc    { list<MemoPage> pages; string currentPageId }
```

**复刻标准**：
- 【必须】每页画布 + 对象隔离持久化；切页/关闭/编辑后不丢。
- 【必须】持久化走 **UI 私有存储**（QSettings/JSON 文件/本地 SQLite），**不碰**服务-UI
  磁盘契约与冻结路径（§0 边界）。
- 【应当】用**稳定页 id** 而非 index 作键，规避删中间页的键漂移（v88 用 index + 手动移键，
  脆弱）。
- 【应当】合并 v88 那堆 0ms/250ms/同步混杂的保存计时为**单一 model-backed 防抖自动保存**。

---

## §4 复刻规则总纲（全局条款）

- **G1【必须】令牌单一源**：所有色/圆角/缓动取 `MemoryLakeStyle`（含美术文 §9 新增
  token：`memoInk`/`memoPenWidth`/`memoEraserWidth`/`memoDotColor`/`memoDotPitch`/
  `stickyPaper`/`pomodoroRed`/`pomodoroAmber`）。
- **G2【必须】复用既有组件**：`GlassPanel`(chrome 玻璃) / `RoundedFrame`(圆角裁切) /
  `GridTexture`→点阵变体(黑板点) / `GlowCircle`(软辉光) / `FrostCard`(便签/文字/页面行) /
  `SilkyFlickable`(列表)；不引入手册之外新做法。
- **G3【必须】三层分离**：背景层(点阵/辉光/渐变) / 透明墨水 `Canvas` 层 / DOM 对象层
  （便签 z 高于文字）。橡皮 destination-out 只作用墨水层。
- **G4【必须】数据边界**：备忘是 UI 本地状态，不写服务契约、不加 IPC/socket/共享内存、
  不让服务读。
- **G5【必须】一个开合类**：统一用一个 `open` 状态（修 v88 `.active` vs `.open` 分裂——
  v88 光色黑板与 source-pill 因绑 `.active`(JS 从不加) 而**永不生效**）。
- **G6【必须】三缓动**：用 `MemoryLakeStyle` 的三条品牌缓动；备忘大量动画的
  `cubic-bezier(.18,.9,.2,1)` 对应 `easeSnappy`，`cubic-bezier(.2,.8,.2,1)` 对应 `easeSoft`。
- **G7【应当】单一计时/探测器**：番茄钟用一个 `Timer` + `onRemainChanged`，弃 v88 的
  3 探测器 + 三重包裹函数 + 跨 IIFE window 残骸。
- **G8【应当】实时模糊预算**：遵 cookbook ≤3 路实时模糊；黑板磨砂优先共享首页已模糊背景，
  勿叠加新大模糊。
- **G9【应当】像素美术走资产**：像素番茄导出 PNG sprite，勿模拟 box-shadow 像素画。
- **G10【应当】night/day 一致**：黑板点阵不分主题画在底层；修 v88 光色失效问题。

---

## §5 复刻标准 / 验收（Conformance）

逐子系统验收清单（对照 v88 截图/录屏，品红底 3× 超采样逐像素门见 UI 验证笔记）：

| # | 验收项 | 级别 |
|---|---|---|
| C0 | 点「备忘」nav **直接进黑板覆盖层**（动作触发 `memoOverlay.open`），不路由/不换页；关闭退回底层原页。移除 `notes→DesktopChatPage` 页面路由 | 必须 |
| C1 | 黑板磨砂底（1 backdrop 模糊 + 近黑渐变 + 2 角辉光 + 10.5% 白点 24px）与 v88 同 | 必须 |
| C2 | 工具条滑入(280ms bezier)、工具互斥、aqua→violet active、hint 5 句、4 态光标 | 必须 |
| C3 | 画笔 #FFEC96@.96 宽4 / 橡皮 destination-out 宽28，DPR 清晰，逐页墨迹 | 必须 |
| C4 | 便签创建偏移/拖动钳制(top≥84)/四向缩放(无顶)/autosize(>110 或 <72000)/aqua 选中环/键删 | 必须 |
| C5 | 文字层编辑/删除/拖动；reload 后仍可拖（修 v88 回归） | 必须 |
| C6 | 档案袋开合 3D(长高360/后仰5°/层扇开/弹层滞后50/雪佛龙180°)，切页七步序，删页保底+重对齐 | 必须 |
| C7 | 加页隔离对象（修串写 bug） | 必须 |
| C8 | 番茄状态机(收缩180ms/点番茄暂停展开)、6 运行光效时长、开始迸发+完成双闪 | 必须 |
| C9 | 完成全屏弹层(随机文案/conic 光环/大番茄弹跳/粒子)盖一切 | 必须 |
| C10 | 像素番茄 PNG sprite 像素 1:1（mini/大/弹层三尺寸） | 必须 |
| C11 | 保存状态 pill 真实淡出（修 v88 硬切） | 应当 |
| C12 | 稳定页 id 持久化（非 index） | 应当 |
| C13 | 单一番茄探测器、单一防抖保存 | 应当 |
| C14 | night/day 黑板点阵一致 | 应当 |

---

## §6 复刻方式步骤（建议批次，与美术文批次咬合）

1. **F-B1 壳与状态骨架**：MemoOverlay 开合 + 翻面守卫 + 三层分离 + MemoPageModel/
   MemoStore（稳定 id、UI 私有持久化）。（配美术 M-B1）
2. **F-B2 工具条**：MemoToolbar 工具互斥 + hint + 光标 + 更多弹层。（配 M-B2/M-B3）
3. **F-B3 手绘画布**：MemoInkCanvas pen/eraser + DPR + 节流保存 + 逐页墨迹。（配 M-B4）
4. **F-B4 便签**：StickyNote 创建/拖动/缩放/autosize/选中/键删 + 持久化。
5. **F-B5 文字层**：TextLayer 编辑/Alt 拖动(+提示)/删除 + 持久化(修 reload 拖动)。
6. **F-B6 页面管理**：MemoPageFolder 开合 3D + 列表 + 切/增/删（修加页对象串写、键漂移）。
   （配 M-B6）
7. **F-B7 番茄钟**：PomodoroWidget 计时状态机 + 收缩/展开 + 6 运行光效 + 拖动；像素番茄
   PNG sprite。（配 M-B5/M-B6）
8. **F-B8 完成弹层**：PomodoroCompleteOverlay 随机文案 + conic 光环 + 大番茄 + 粒子；
   **单一探测器**收束。

每批先过功能验收（§5 对应项），再过美术像素门。番茄/档案袋批用录屏逐帧比时长与缓动。

---

## §7 GAPS / 待补充（v88 设计稿尚未实现或不一致——用户将进一步填充）

> 用户已说明"有一部分功能在设计稿中尚未完全实现，将进一步填充"。下表是从 script 逐字
> 排查出的**确切缺口与 bug**，分"功能缺失（需产品决策补）"与"实现 bug（复刻时应修正）"。

**A. 功能缺失（设计稿没做，待用户补产品决策）**
_（2026-06-06 校对：#1–#10 已全部在 QML 落地，逐条标 ✅；剩 #11 番茄音效 / #12 工作-休息循环 / #13 环形进度环 / #14 键盘快捷切换 仍待办。）_
1. ✅ **已实现（QML）**——快照式撤销/重做（`_hist`/`undo()`/`redo()`，Ctrl+Z / Ctrl+Shift+Z）。
   〔原设计稿缺口：栈式栅格无 stroke 历史，唯一"撤销"是橡皮。〕
2. ✅ **已实现（QML，2026-06-06）**——画笔工具弹层 6 色粉笔调板（`MemoryLakeStyle.memoInkPalette`
   → `MemoInkCanvas.penColor`），存 `pen.color`。〔原缺口：墨水写死 #FFEC96，无色板。〕
3. ✅ **已实现（QML，2026-06-06）**——同弹层细/中/粗三档（笔 2.5/4/7、橡皮 16/28/44；
   `penWidth`/`eraserWidth`），存 `pen.pw/ew`。〔原缺口：宽 4/28 写死，无滑块。〕
4. ✅ **已实现（QML，2026-06-06）**——工具条垃圾桶按钮 → 确认弹层 → `clearCurrentCanvas()`
   （clearAll + 存盘 + 入撤销栈，Ctrl+Z 可恢复）。〔原缺口：`clearMemoCanvasOnly` 仅内部调用，无 UI。〕
5. ✅ **已实现（QML，2026-06-05）**——档案袋每页行 ✎ 内联改名（`MemoOverlay.renamePage`，
   存 `memoryLakeMemoDoc`；回车/失焦/点别处提交、Esc 取消）。〔原设计稿缺口：标签只 `Page N`，
   `.memo-page-more`("···") 渲染却零处理器。〕
6. ✅ **已实现（QML，2026-06-06）**——档案袋每行 ⠿ 手柄拖拽重排（`MemoOverlay.movePage`，
   顺序即 pagesData 数组序，自动持久化；修正 currentPage）。〔原缺口：只 push/splice，无拖拽。〕
7. ✅ **上限已加（QML）**——10 页（`addPage` 守卫 + `MemoPageFolder.maxPages:10`）。〔原设计稿
   缺口：`memoAddPage` 无界 push；档案袋 `nth-child(3n)` 标签位只 3 档、>3 层重叠——QML 厚度层改用
   连续偏移。〕
8. ✅ **已实现（QML，2026-06-06）**——每页行内 40×24 墨迹缩略图（`MemoOverlay.pageThumbs` 取自
   每页 canvas PNG，`MemoPageFolder` 行内 `Image`）。〔原缺口：只显文字标签，无预览。〕
9. ✅ **已实现（QML，2026-06-06）**——便签右下可编辑署名，逐页持久化（objectModel `osign` 经
   _snapshotObjects/_applyRecords 往返；默认空，不复刻 v88 写死的"JusTin D"）。〔原缺口：写死且不持久化。〕
10. ✅ **已实现（QML，2026-06-06）**——番茄 total/remain/title 存单独键 `memoryLakeMemoPomodoro`，
   重启恢复为暂停态（无跨重启墙钟锚点）；标题可编辑。〔原缺口：内存 let，重载回 25:00 idle。〕
11. **番茄无音效**——完成纯视觉 + 文字 toast，无 audio/beep。
12. **番茄无工作-休息循环**——无短/长休、无轮次计数，单次倒计时。
13. **番茄无环形进度环**——只有横向填充条；若要环须新设计。
14. **文字工具/便签无键盘快捷切换**——只鼠标点（虽有 aria-label）。

**B. 实现 bug / 不一致（复刻时应修，勿照抄）**
15. **`.active` vs `.open` 分裂**：光色黑板 tint、source-pill 全绑 `.active`，但 JS 只加
    `.open`→ **光色黑板永不主题化、source-pill 永不显示**（11575/12653/13596）。统一一个开合类。
16. **保存状态 pill 无淡出过渡**：JS 设 opacity 1→.72 但无 CSS transition，是硬切（16323）。
17. **加页未隔离对象**（16863 未被 V52 包裹）：加页只清画布、不存旧页对象/不清新页对象→
    旧便签残留并被 250ms 自动保存串写进新页键（状态串写 bug）。
18. **逐页键用数组下标**（`_page_${index}`）：删中间页靠手动移键，脆弱，易键漂移。改稳定 id。
19. **文字层重载后不可拖**：`recreateTextLayerFromData`/`attachTextLayerDelete` 未重挂 Alt
    拖动监听（17040/17025）——回归 bug（便签因复用 createStickyNote 而正常）。
20. **文字层选中环未迁 aqua**：仍用旧蓝 `rgba(13,153,255,.65)`（4246），便签已用 aqua。统一。
21. **对象无 z-order 控制**：只存 DOM 顺序，便签恒 z124 盖文字恒 z123，无置顶/重排。
22. **番茄跨 IIFE 全局 bug**：V65 弹层 IIFE 读 `window.pomodoroRemain` 等，但 V58 用闭包
    `let` 未挂 window→V65 探测器实际从不由真实状态触发（靠 V63/V64 主 IIFE 探测器 + 调试热键）。
    QML 用单一探测器收束。
23. **三重包裹函数**（start/stop/render 经 V58→V59→V60 反复重赋值）+ 三探测器 + 两套变体数组
    （17657 / 18387）+ 两套 spawnParticles——版本残骸，QML 应合并为单一带信号的方法。
24. **像素番茄 box-shadow 像素画在 QML 无等价**（§4.6/5.3 已定走 PNG sprite）。
25. **便签 header 高度冲突**（V37 `flex:0 0 36px` vs V40 `height:26px` 皆 !important）；
    `.sticky-close` 死类、`.sticky-title/.sticky-subtitle` 死类——勿复刻，取 36px 拖拽条。
26. **缩放/切页恒重采样**（无矢量模型，identity drawImage 拉伸到背存）→ 反复缩放累积软化/
    纵横畸变。要脆需加矢量 stroke（增强）。
27. **拖动钳制用 `window.innerWidth/Height`**（16423）——QML 应改用覆盖层内容矩形。
28. **死 CSS**：V44 旧档案袋类（`.memo-page-pill` 等 4423–4511，V47 已 display:none 隐藏）、
    便签橙色 `::after`（opacity:0 死码）、`.is-cancelled` 暗色不可见(为光色写的)——勿复刻。

---

## §8 与既有文档关系

本文是备忘页专题的「功能 / 状态」一员，与美术管线文
`memory-lake-memo-render-pipeline-replication.md` 配套，二者共享同一套 `MemoryLakeStyle`
令牌与既有 `qml/desktop/memorylake/*` 组件。整个 TimeArc 美术/功能复刻文档族：
- `memory-lake-art-lighting-qml-cookbook.md` = 技法 / token 字典；
- `memory-lake-home-art-implementation-spec.md` = 首页条款式法规（本文的条款体例
  【必须】/【应当】/【可选】沿用之）；
- 首页 `memory-lake-home-render-pipeline-replication.md` = 首页管线复刻；
- 备忘美术文 = 备忘管线复刻；**本文 = 备忘功能 / 状态 / 规则·标准·步骤 + 缺口清单**。

实施总流程：**本文 §5 验收口径定"做到什么" → cookbook 查技法 → 美术文查合成与 shader →
本文 §2/§3 查行为与状态**。§7 的缺口清单是与用户协作的接口：B 类 bug 复刻时直接修正，
A 类功能缺失等用户进一步填充产品决策后再落地。
