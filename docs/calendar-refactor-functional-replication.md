# 日历页 · 功能复刻规范（行为 / 状态 / 复刻规则·标准·步骤）

> 配套文档：`docs/calendar-refactor-render-pipeline-replication.md`（像素/打光/技法）。
> 本文只管「日历做什么、状态怎么流、数据存哪、法规是什么、怎么验收」。美术在配套文档。
> 设计稿真值：`MemoryLakeDesign/TimeArcDesign_v88.stripped.html`：日历标记 **14167–14241**，
> 日历 JS **18015–18362**（页面逻辑）、**14977–15229**（备忘→日历工具）。
> 重构目标：`qml/desktop/pages/DesktopCalenderPage.qml`（注意拼写 `Calender`）。

> **实现进展（2026-06-06，commit 8616b48 等）— 本规范是首切片计划，下列原「占位/暂缓」项现已实装，读 §2.5 / A4 / A5 / B1 / B2 / C9 / C12 时以此为准：**
> - **周计划 / 今日议程 / 专注记录** 三视图已真渲染（不再是 toast 占位）：周=选中周周一起始 7 列（复用月格，点列选日）；今日=只读时间线（纪念全天置顶 + 定时/未定待办 + 专注，按时间合并排序）；专注=本周 7 柱（weekFocusModel 缓存）+ 逐项目计时条 + 按标签聚合。
> - **专注块 / 本周任务** 2×2 统计芯片现绑真值（model 全 `real:true`，`占位` 徽标不再出现）。
> - 同期另加（超出本 v88 复刻范围）：便签「成为待办」投影进 `savedTodos`、tag 语义色系（`TagPalette`/`TagChip`）、侧栏 v88 配色对齐。
> - 实装细节与踩坑见记忆 `timearc-calendar-refactor.md`。

---

## §0 概览：日历页是什么 + 两条已定决策

**本质**：日历是按「日期 → 当天事项/事件/专注/纪念日/照片/计时记录」组织时间上下文的整页视图。
它是 TimeArc 里**唯一仍停留在旧奶油主题**的大页；v88 把它并入与首页、备忘同源的 memory-lake 暗玻璃语言。

**因此这是「重皮 + 行为保持」，不是绿地。** 后端数据通路（`calendarManager` + `QtCore Settings` + `projectManager`）
**已正确且合规**，几乎原样保留；活主要在 UI 层。

**两条已由用户拍板、贯穿全文的决策：**
- **D-ROUTE = 路由页**：保持侧栏导航进入的整页 Loader（不改 overlay）。背景用不透明暗玻璃替代真实毛玻璃
  （配套文档 §0.2）。→ 入口语义**不**照搬备忘「入口=动作非路由」的教训。
- **D-KEEP = 全保留**：v88 没有为现有的**纪念日/倒数日、当日照片、记录(番茄计时)Tab** 预留位置，
  但它们都有可用后端且独立持久化。**全部保留**，在 v88 三栏布局上**有意扩展**（偏离稿件以不丢功能）。

**数据边界**：日历自身状态全部 UI 私有（`calendarManager`→`SettingsRepository`/SQLite settings；纪念日另在
`QtCore Settings` 类目 `DesktopCalendarAnniversaryData`），**绝不**碰服务的 `usage_records.jsonl/usage_current.json`
磁盘契约，**绝不**用 QML `localStorage`（rule 04 §4）。v88 用 `localStorage`，QML 端**改走 `calendarManager`**。

---

## §1 QML 组件架构（重皮 · 复用优先）

```
DesktopCalenderPage.qml  (路由页 root，保留文件名 Calender，保留 startTodoProject 信号)
├─ MemoryLakeStyle (注入或本地实例；新增日历 token)              [§3.4]
├─ RoundedFrame(r26)  ── 暗玻璃整页基底
│   ├─ Rectangle(竖直渐变)  + 2×GlowCircle(角晕)  + GridTexture(42)   ← 配套 §4.1
├─ GridLayout 三栏 [280 | 1fr | 310]
│   ├─ 左栏 GlassPanel
│   │   ├─ FrostCard  brand card                                 (净增·装饰)
│   │   ├─ 视图 Tab ×4  (月真 / 周·今日·专注 占位)  ButtonGroup     [§2.5]
│   │   └─ 2×2 统计芯片 (今日事项/完成率/专注块/本周任务)            [§2.7]
│   ├─ 中栏
│   │   ├─ GlassPanel(无阴影) 顶栏: 月标题 + ‹/今天/› + 返回首页      [§2.1]
│   │   └─ 月视图: 周一表头 + 42 格发丝栅格 (抬 MemoDatePicker)       [§2.2/§2.3]
│   └─ 右栏 GlassPanel  ── 选中日卡 + 模式区
│       ├─ FrostCard 选中日卡 (+可选照片 hero)                      [§2.8 照片]
│       ├─ 模式切换:  待办 / 记录 / 纪念   (保留现三态)              [§2.6]
│       │   待办 = event-form(标题/时间/类型) + day-agenda(SilkyFlickable)  [§2.4]
│       │   记录 = projectManager 计时条                            [§2.9]
│       │   纪念 = 纪念日/倒数日 增删 + 状态                          [§2.10]
│       └─ EventChip 类型色 map
└─ Toast (净增反馈)                                               [§2.11]
```
**保留不动（后端/逻辑）**：`calendar_manager.{h,cpp}`、`DesktopAppShell` 接线、`projectManager` 集成、
`DesktopCalendarAnniversaryData` Settings、所有 JS 助手（`buildCalendarCells`/`daysBetween`/`anniversaryStatus`/
todo (反)序列化/`secondsToDisplay`/照片解析）——可几乎原样搬进新页。

---

## §2 功能子系统逐项规格（复刻规则 / 标准 / 步骤）

> 每项三段：**规则**（v88/现状行为 + 行号）/ **标准**（必须·应当·可选）/ **步骤**（QML 落地序）。

### §2.1 月导航（‹ / 今天 / ›）
- **规则**：v88 prev/next 改月并**只重渲染栅格**（18319–18327）；`今天` 重置 `selectedCalendarDate=今天` 且
  `calendarViewDate=本月1号`（18329–18333）。现页 `previousMonth/nextMonth/今天`（448–463,576–590）已等价。
- **标准**：必须保留三键行为；必须 `今天` 同时重置视图月与选中日；应当顶栏月标题 `YYYY年 M月`。
- **步骤**：保留现有函数，仅重皮按钮（配套 §1.7）。纯本地 `Date` 状态，无后端调用。

### §2.2 月历栅格构建（42 格）
- **规则**：v88 `firstDay=(first.getDay()+6)%7`→**周一起始**；`start=1-firstDay`；42 格；`muted=非本月`、
  `today=今天`、`selected=选中`（18181–18227）。现页是**周日起始**（92 行无偏移；表头 `日一二…`）。
- **标准**：**必须改为周一起始**（与 v88 + `MemoDatePicker` 一致）——这是**可观察行为变更**→Track B（见 §4 G8）。
  必须 42 格、`muted/today/selected` 三态。点击 cell：选中该日；跨月点击则切到该月并重渲染。
- **步骤**：抬 `MemoDatePicker` 的 `_firstWeekday/_daysInMonth/_two` 与 cell delegate；改表头为 `Mon..Sun`/或 `一..日`；
  `buildCalendarCells` 改周一偏移并**复验所有 per-cell 徽标坐标**。

### §2.3 cell 内容（事件胶囊 + 保留徽标）
- **规则（v88）**：每格取**前 3** 条事件 `time+title` 胶囊（类型色），超出 `+N more`（18203–18215）。
  **规则（现状保留）**：现 cell 显示**计数徽标**（待办 pill + `倒/纪` pill + 照片点）。
- **标准（D-KEEP 调和）**：必须显示事件胶囊（v88）；必须**同时保留** `倒/纪` 纪念徽标与待办计数（现状）；
  应当：事件胶囊在上、纪念徽标在下角，避免拥挤；可选：照片态见 §2.8。
- **步骤**：cell delegate = 日号 + `Column{ EventChip×≤3 + moreChip }` + 角标 `倒/纪`。事件来自 §3 的 `savedTodos`
  扩展（含 time/type）；纪念计数来自 `anniversaryCountForDate/countdownCountForDate`（225–233）。

### §2.4 事件/待办 CRUD（增 / 删 / 勾选完成）+ 持久化
- **规则**：v88 `eventAddBtn` push `{id,title,time,type,done}` 到当天 → `setEventsFor`→`saveCalendarEvents`（18261+）；
  议程项 `×` 按 `id` 过滤删除（18250–18256）；勾选 toggle `done`（18110+）。
  现页 `addTodo/saveTodosForSelectedDate/todoModel`（322–405,1091–1208）已做整段（反）序列化 CRUD + 持久化。
- **标准**：必须 增/删/勾选 均经 `calendarManager.setSavedTodos` 落盘（**禁** `localStorage`）；
  必须保留**整段当天数组替换**契约（非 v88 的 push-别名模式，见 §4 G6）；
  必须保留 `text` 字段与 `completeTodo(dateKey,text)` 文本匹配（否则计时回路断，§4 G5）。
- **步骤**：复用现有 CRUD；**采纳 v88 时间+类型（已定 A3）**——向 todo 对象**加 `time/type` 字段**（§3.2，自由 JSON，无 .h 改）。

### §2.5 视图 Tab（月真 / 周·今日·专注 占位）
- **规则**：v88 四 tab `month/week/today/focus`（14176–14180）；**仅 `month` 真渲染**，其余 3 个仅 toast
  `已切换到X` + 切 `.active`（18335–18343）——**占位**。
- **标准**：必须 `月视图` 绑真栅格；`周计划/今日议程/专注记录` 首切片做**装饰占位**（toast + active 切换），
  **不得**对外承诺稿件本就没实现的真实周/议程/专注视图。真实周/专注视图= 独立**未来 Track B** 任务。
- **步骤**：`ButtonGroup` 4 pill；`onClicked` 切 `activeView`；非 month 仅触发 toast。
- ⚠ **命名冲突**（§7-B5）：占位的「今日议程」tab ≠ 右栏常驻「当天议程」`dayAgendaList`，勿误接。

### §2.6 右栏模式（待办 / 记录 / 纪念）— D-KEEP 的承载处
- **规则**：v88 右栏只有 `选中日卡 + 加日程表单 + 当天议程`（14213–14238）。现页右栏是 `待办/记录/纪念` 三态分段开关
  （`sidePanelMode`，938–982）。
- **标准（D-KEEP）**：必须在 v88 右栏框架内**保留三态**：`待办`=v88 的 选中日卡+event-form+议程；
  `记录`=计时条（§2.9）；`纪念`=纪念日/倒数日（§2.10）。模式开关用暗霓虹分段控件。
- **步骤**：右栏 = 选中日卡（常驻）+ 模式开关 + 三 `ColumnLayout`（`visible: mode===key`）。待办态采 v88 表单/议程视觉。

### §2.7 统计芯片（今日事项 / 完成率 / 专注块 / 本周任务）
- **规则**：v88 仅 `calendarStatToday/calendarStatDone` 有 id 并由 JS 更新；`专注块=3`、`本周任务=14` 是**写死 demo**
  （14184–14188，§7-B3）。v88 日历**无真实 deadline 功能**（稿件里 deadline/countdown 只属番茄钟，17726+）；
  现有 app 的 **倒数日/countdown** 才是「把 deadline 放到日历格」的概念，且已由 D-KEEP 保留（§2.10）。
- **标准（已定 A5 = 暂缓）**：必须 `今日事项/完成率` 由真数据算（现 done/total 逻辑已具备，`CalendarSyncList.remaining` 同源）；
  **`专注块/本周任务` 及任何「deadline 上日历」的内容先做诚实占位**（不得伪装成真值），**待重构出最终渲染效果后由用户选择性补内容**。
  无新后端——届时如要补真值，从 `savedTodos`/`projectManager`/倒数日 在 QML 端聚合。
- **步骤**：4 芯片中 今日事项/完成率 绑真计算属性；专注块/本周任务 先静态占位（标 TODO，留接口），效果确认后再决定数据源。

### §2.8 当日照片 / 背景（保留）
- **规则**：现页 `backgroundForDate`（手动 `calendarManager.dayPhotos` 优先，回退当天 chat 图）→ cell 铺图 + 选中日 hero；
  `FileDialog` 选图 `setManualPhotoForSelectedDate`（117–164,656–743,848）。v88 **零照片概念**。
- **标准（D-KEEP）**：必须保留照片 hero 与 cell 可选照片态；照片态与「发丝账本」基态并存；
  照片圆角必须迁到 `RoundedFrame`（旧 `Image+Rect mask+MultiEffect` 圆角漏边，§4 G7）。
- **步骤**：选中日卡承载 hero（FrostCard 内 Image）；cell 增「有图则铺图+渐变压暗+日号底片」分支。
- **产品边界提醒**（§8）：chat 图自动上墙是此面最接近「私密内容」的点；属既有 UI 私有本地数据、不破契约，但保留即沿用此路。

### §2.9 记录 Tab（计时记录 / 进度条）（保留）
- **规则**：`dayProjects()`=`projectManager.timeEntriesForDate(选中日)` 滤 `source=='calendar_todo' && seconds>0` 降序；
  `maxDaySeconds/selectedDateTotalSeconds` 驱动总计 pill 与每行进度条（407–446,1211–1289）。
- **标准（D-KEEP）**：必须保留；`calendar_todo` 计时条目由 `projectManager` 拥有（与 USM/SQLite 用量管线无关，不受其不稳定性影响）。
- **步骤**：原逻辑搬入「记录」模式；进度条/总计重皮为 `ml` token + `trackBg`。

### §2.10 纪念日 / 倒数日（保留）
- **规则**：`allAnniversaries/anniversariesForDate` over `DesktopCalendarAnniversaryData` Settings JSON 数组
  `{id,title,dateKey,type}`；`anniversaryKind`（`countdown|yearly`→倒数，否则 since）；`anniversaryStatus` 算日差
  `还有/已经 N 天`；行点击跳到该日（49–53,195–320,1291–1478）。v88 **零纪念概念**。
- **标准（D-KEEP）**：必须保留；**必须原样保留 Settings 类目 `DesktopCalendarAnniversaryData`**（否则用户已存纪念日丢失，§4 G4）。
  v88 无对应视觉 → 按 `ml` **自拟**暗霓虹纪念卡（有意偏离稿件）。
- **步骤**：纪念态搬入「纪念」模式；增删/状态逻辑保留，仅卡片重皮。

### §2.11 Toast（变更反馈）
- **规则**：v88 `showCalendarToast` 每次变更触发底中胶囊（9571–9595, JS 18081）。现页**静默无 toast**。
- **标准**：应当在 增/删/勾选/同步 后 toast；可选复用 `AchievementToast`。净增反馈，低风险。
- **步骤**：底中 `Rectangle` + `Behavior` + 自动隐藏 `Timer`，或 `AchievementToast`。

### §2.12 备忘→日历同步工具（延后，Track B）
- **规则**：v88 浮动 `openCalendarEventTool` 把备忘转日历事件，含 success 粒子爆 + 关闭（14977–15229）。
- **标准**：可选/延后批次；复用**同一** `addEvent` 路径（后端已覆盖）。这是**备忘页之上的净增能力** → 独立 Track B。
- **步骤**：见配套文档 §6（conic 光环可选 shader）+ 本文 §6 F-B7。

---

## §3 持久化与数据模型

### §3.1 现有后端契约（保留）
`CalendarManager`（`src/services/calendar_manager.{h,cpp}`，**未冻结**）= 极薄 JSON-字符串桥：
| 成员 | 含义 |
|----|----|
| `Q_PROPERTY savedTodos` | `map dateKey→[{text,done,tag,linkedProject}]` |
| `Q_PROPERTY dayPhotos` | `map dateKey→图片路径` |
| `Q_PROPERTY selectedDateKey` | 持久化选中日 |
| `Q_INVOKABLE setSavedTodos/setDayPhotos/setSelectedDateKey` | QML 整段写回 |
| `Q_INVOKABLE completeTodo(dateKey,text)` | 计时停后按 text 标记完成 |
| `signal calendarDataChanged` | QML `Connections` 重载刷新 |
落盘：`SettingsRepository` keys `calendar_saved_todos/day_photos/selected_date`（无注入则回退 `QSettings('TimeArc','CalendarManagerData')`）。
纪念日另存：`QtCore Settings` 类目 `DesktopCalendarAnniversaryData`（UI-only）。计时：`projectManager` 自有存储（只读引用）。

### §3.2 v88 模型 → QML 映射（含字段合并）
| v88 (localStorage) | QML（落到 `calendarManager`） |
|----|----|
| `calendarEvents[dateKey] = [{id,title,time:'HH:MM',type:todo\|event\|focus,done}]` | 扩展 `savedTodos` 的 todo 对象：**加 `time`、`type` 字段**，**保留 `tag`、`linkedProject`** |
| `saveCalendarEvents()` localStorage | `calendarManager.setSavedTodos(JSON)` |
| `getEventsFor/setEventsFor` 活引用 push | **整段当天数组替换**（`saveTodosForSelectedDate`），勿照搬别名 push（§4 G6） |
- **合并规则**：`{text/title, done, tag, linkedProject, time?, type?}`。**不得**为采纳 v88 而丢 `tag/linkedProject`
  （它们驱动 `startTodoProject→timer→completeTodo` 回路）。`time/type` 为**加性自由 JSON 扩展，零 .h/.cpp 改**。

### §3.3 在 QML 端新算（无后端改）
- `今日事项/完成率`：现 done/total 已可推。
- `专注块/本周任务`：今天无聚合 API → 从 `savedTodos`/`projectManager` 在 QML 算，或诚实占位。
- 事件胶囊 cap3+more、周一 42 格矩阵、`today/selected/muted` 旗标：纯视图逻辑绑既有信号（`MemoDatePicker` 已有矩阵数学）。

### §3.4 token 持久化策略
日历专属色（`calPageTop/Bottom`、`cellHair`、`todayWash`、`selectedRing`、`chipEvent/Todo/Focus*`）**追加到
`MemoryLakeStyle.qml` 末尾**（仿 memo token 150–187），night/day 双值。Tag 固定色 `tagColor()` 保留不随夜间变。

---

## §4 复刻规则总纲（全局条款 · 法规）

> 关键词：**必须 (MUST) / 应当 (SHOULD) / 可选 (MAY)**。违反「必须」即不合格。

- **G1（token 单源，MUST）**：零内联 hex/rgba/radius/easing；全部 `MemoryLakeStyle.*`。删当前页 `#FBF8F4`/mint/lavender/blush 写死色。
- **G2（不越技法字典，MUST）**：只用 cookbook 列出的技法/组件；不引入字典外新画法。
- **G3（持久化 UI 私有，MUST）**：经 `calendarManager` + `QtCore Settings`；**禁** QML `localStorage`/`LocalStorage`/阻塞文件 I/O（rule 04 §4）。
- **G4（磁盘契约边界，MUST）**：UI 是消费者；**禁** 改/写 `usage_records.jsonl`、`usage_current.json`、schema；
  **禁** IPC/socket/共享内存/直链服务内部；**禁** 反转 service→disk→UI 流向（CHARTER I1/I2，rule 01/03）。
- **G5（信号契约，MUST）**：保持 `startTodoProject(projectName, tagName, dateKey, linkedProjectName)` 四参签名不变；
  `completeTodo(dateKey,text)` 文本匹配不变（`DesktopAppShell` 791–804/842–861 已接，改签名即静默断回路）。
- **G6（整段替换，MUST）**：当天事项以「整段数组替换」落盘，勿照搬 v88 的 push-then-save 活引用别名。
- **G7（圆角裁剪，MUST）**：圆角 + 内部图/渐变/栅格/填充一律 `RoundedFrame`（FBO+单 mask，`maskThresholdMin:0.5`）；
  **禁** `clip:true` 当圆角裁剪（只裁矩形，漏方角）。
- **G8（轨道纪律，MUST）**：周一起始、time/type 加字段、新左栏/视图 tab/统计/事件胶囊 = **可观察变更/新面** → **Track B**。
  纯视觉零行为差的子批可 Track A，但**一次提交一个轨道**，不混轨。
- **G9（保留契约，MUST）**：D-KEEP 下不得静默删除 纪念日/倒数日、照片、记录 Tab；
  **必须**原样保留 `DesktopCalendarAnniversaryData` 类目。
- **G10（冻结文件，MUST）**：scope 内无冻结文件；唯一触发变更提案的是**新增 C++ 源**（动到冻结 `src/CMakeLists.txt`）——
  本重构应零新 C++。新拆分 QML 组件写进**未冻结**的 `qml/CMakeLists.txt`，资产写 `resources/CMakeLists.txt`。
- **G11（双壳，N/A→MUST 记录）**：`qml/mobile/` **无**日历页；本重构**桌面专属**，故 rule 04 §1「新页注册两壳」不触发；
  必须在文档**明确移动端日历超范围**（否则升级为更大 B 任务）。

---

## §5 复刻标准 / 验收（Conformance）

| ID | 验收项 | 级别 |
|----|----|:--:|
| C0 | kill exe → `build.py` 干净（exit 0），启动无新 QML warning（`scan_qt_log`） | 必须 |
| C1 | 整页暗玻璃基底 + 42px 栅格 + 双角晕，圆角不漏（magenta 门，仅不透明层） | 必须 |
| C2 | 三栏 280/1fr/310；左 brand+tab+stat、中 顶栏+月视图、右 选中日+模式 | 必须 |
| C3 | 月历 **周一起始** 42 格，`muted/today/selected/hover` 四态正确 | 必须 |
| C4 | 事件胶囊 cap3+`+N more`，三类型色（event/todo/focus） | 必须 |
| C5 | 增/删/勾选经 `calendarManager` 落盘并 `calendarDataChanged` 刷新；重启留存 | 必须 |
| C6 | `startTodoProject` 四参签名不变，计时回路（开始→停→completeTodo）仍通 | 必须 |
| C7 | 纪念日/倒数日 保留且 `DesktopCalendarAnniversaryData` 类目不变；旧数据可读 | 必须 |
| C8 | 记录 Tab 计时条保留；照片 hero/cell 保留且圆角不漏 | 必须 |
| C9 | 视图 tab：月真，周/今日/专注 占位（toast+active），不伪装真视图 | 必须 |
| C10 | 全色走 `ml` token，无内联 hex；夜/日双模一致 | 必须 |
| C11 | 开合动效 easeSnappy；toast 反馈 | 应当 |
| C12 | 今日事项/完成率 真值；专注块/本周任务 **静态占位**（A5 暂缓，效果确认后再补） | 应当 |
| C13 | 备忘→日历同步工具 + success 光环 | 可选（延后 B） |
| C14 | 真机 `run.cmd` 走查开合/hover/选中（Win32 自动化不稳，静态 grab 兜底） | 应当 |

**PR 三联**：每条款 → `文件:行` → 截图/录屏证据（仿 home-spec 法规体）。

---

## §6 复刻方式步骤（F-B 批次，与渲染 M-B 咬合）

> 收尾每批：kill `TimeArc.exe` → `build.py` → 启动 → `scan_qt_log`（无新 warning，必要时 `git checkout HEAD -- .harness/journal/INDEX.md`）→ `record_error.py`（任何 L1/L2/L3）→ `harness_check.py`（冻结 sha256 门）。`DesktopCalendarAnniversaryData` 全程字节不变。

- **F-B0 预检（无码）**：`preflight.py --track B`（周一起始/新面=可观察变更→B）。确认 scope 内无冻结文件（已核：均未冻结）。
  锁定 D-ROUTE/D-KEEP（已定）。默认：保留全部旧功能、3 占位 tab、采纳 time/type 加字段。
- **F-B1 基底 + token（可跑切片）**：迁色到 `ml`（最大机械活），root 换暗玻璃（咬合 M-B1）。旧布局仍跑但已暗霓虹。
- **F-B2 月视图（核心切片）**：抬 `MemoDatePicker` 月格 + **周一起始改造** + 顶栏导航，绑真 `calendarManager` 数据（咬合 M-B2）。
- **F-B3 事件 + 右栏待办**：cell 事件胶囊 + 右栏 选中日卡/表单/议程；CRUD 仍经 `calendarManager`；time/type 加字段（咬合 M-B3）。
- **F-B4 左栏**：brand + 4 tab（3 占位）+ 2×2 统计（今日事项/完成率 真值；专注块/本周任务 **静态占位**，A5 暂缓）（咬合 M-B4）。
- **F-B5 保留态**：右栏 记录/纪念 两态搬入并重皮；照片 hero/cell 态；动效 + toast + light-mode（咬合 M-B5）。**D-KEEP 验收点 C7/C8**。
- **F-B6 收尾验收**：跑 C0–C12；真机走查 C14。
- **F-B7（延后/可选 B）**：备忘→日历同步工具 + success 光环（咬合 M-B6）。

---

## §7 GAPS / 待补充

> 分两类：**A=需产品/设计决策**（多数已由 D-ROUTE/D-KEEP 解）；**B=v88 稿件本身的 bug/不一致（复刻时顺手修）**。

**A 类（决策）**
- A1 ~~路由 vs overlay~~ → **已定路由页**（D-ROUTE）。背景毛玻璃降级为不透明暗玻璃。
- A2 ~~纪念日/倒数日/照片/记录 去留~~ → **已定全保留**（D-KEEP），在 v88 右栏扩展承载。
- A3 是否采纳 v88 time/type 类型 → **已采纳（用户确认）**：todo 对象加 `time/type` 字段，保留 `tag/linkedProject`（§2.4/§3.2）。
- A4 周/今日/专注 真视图 vs 占位 → **建议首切片占位**；真视图列未来独立 B。
- A5 `专注块/本周任务` + 「deadline 上日历」内容 → **已定暂缓（用户）**：先诚实静态占位，**等重构出最终效果后由用户选择性补内容**；
  不在首批硬接数据源。注意 v88 日历无真 deadline 功能，现有倒数日（D-KEEP 保留）是 deadline-like 显示的现成载体。
- A6 `@max-width:1200px` 折叠列 → 桌面定宽基本不触发；列为**可选/超范围**。
- A7 移动端日历 → **明确超范围**（mobile 无日历页，G11）。

**B 类（v88 稿件瑕疵，复刻时修正）**
- B1 视图 tab 周/今日/专注 **仅占位**（toast，无真渲染，18335–18343）——别从标签推断真视图。
- B2 `专注块=3`/`本周任务=14` **写死 demo**（14184–14188）——复刻给真值或诚实占位。
- B3 「今日议程」**tab** 与右栏「当天议程」`dayAgendaList` **同名不同物**——勿误接（§2.5 警告）。
- B4 v88 表头写 `Mon..Sun` 而其 JS 确为周一起始（`(getDay()+6)%7`）——一致；但**现页是周日起始**，必须切周一（C3）。
- B5 v88 议程空态用一条 `暂无日程` 占位项（18238）——复刻保留空态文案。

---

## §8 产品边界核对（charter）

- v88 日历本身**无私密内容捕获**：纯用户键入 todo/事件 + 静态 demo；不碰 chat 内容/截图/OCR/原始音频/浏览历史。守「记录时间上下文，非私密内容」。
- **唯一边界关注点 = 当日照片的 chat 图回退**（`settingsRepository 'local_memo_chat_messages'`）：把备忘/chat **图片**铺到日历格。
  此为**既有**、UI 私有本地数据、不破磁盘契约；D-KEEP 保留即沿用。若你介意自动上墙，可在 §2.8 关掉 chat 回退、只留手动选图。
- **无 AI over 原始日志**：记录 Tab 读的是用户**自己经计时器启动**的 `calendar_todo` 条目；不加任何对日历事件的 AI 摘要（除非本地过滤 + 用户确认，charter）。
- 持久化全程 UI 私有，合规（§3.1，G3/G4）。

---

## §9 与既有文档关系

- 配套美术文档：`docs/calendar-refactor-render-pipeline-replication.md`。
- 法规/技法母版：`docs/memory-lake-{memo,home}-functional-replication.md`、`docs/memory-lake-home-art-implementation-spec.md`（本文沿用其 §0–§9 文法、复刻规则/标准/步骤三段、G 条款、C 验收、F-B/M-B 咬合、GAPS A/B 分类）。
- 技法字典 + 诚实天花板：`docs/memory-lake-art-lighting-qml-cookbook.md`、`docs/memory-lake-fidelity-gaps.md`。
- 复用组件：`qml/desktop/memorylake/{MemoDatePicker,CalendarSyncList,GlassPanel,FrostCard,RoundedFrame,GlowCircle,GridTexture,SilkyFlickable}.qml`；token `MemoryLakeStyle.qml`。
- 后端契约：`src/services/calendar_manager.{h,cpp}`；接线 `qml/desktop/DesktopAppShell.qml`（nav 131 / loader 169 / 主题注入 181–198 / `startTodoProject` 791–804 / `timerStopped` 842–861）。
- 重构目标：`qml/desktop/pages/DesktopCalenderPage.qml`（拼写 `Calender`）。
- 收尾建议：重构完成后，把这两份文档登记进 `CLAUDE.md`「Product Context」与（如需）`.harness/rules/04` 的 UI 法条索引，与备忘文档并列。
