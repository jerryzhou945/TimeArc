# 设置页 · 功能复刻规范（行为 / 状态 / 持久化 / 复刻规则·标准·步骤）

> 配套文档：`docs/settings-render-pipeline-replication.md`（同页渲染管线 / 美术）、
> `docs/settings-implementation-issues.md`（后端缺口 / 待决策 = 本页的「问题文档」）。
> 设计稿真值：`MemoryLakeDesign/TimeArcDesign_v88.html`
> ——设置页 DOM `13897–14165`、CSS（暗）`8194–8830`（+ 共享类 `prototype-status 11608`、
> `workflow-map 11689`、`theme-switch/chip 12313–12418`）、设置页 JS `17824–18008`、
> 白天模式 JS `18678–18740`、light 覆盖 `12420–13500`、导航「设置」项 `DesktopAppShell.qml:135`。
> 数据来源：设置持久化走 **`SettingsRepository`**（SQLite `settings` 表，UI 私有 KV，
> **非服务磁盘契约**）；数据概览走与首页/统计**同款只读路径**——`usageStatManager` /
> `projectManager` / `dailyCardService`，**不新开数据通道**（详见 §3 + 问题文档）。
> 重构目标：现「设置」路由 `DesktopAppShell.qml:171` → `qml/desktop/pages/DesktopProfilePage.qml`
> （奶油浅色简版，仅 外观/语言/资料/概览/数据位置 5 段）= **重皮 + 扩建，非绿地**。
> Track：**B（新能力 / 重皮）**。本文遵循首页/日历/统计法规体例：
> **必须 (MUST) / 应当 (SHOULD) / 可选 (MAY)**，违反「必须」即不合格。

---

## §0 概览：设置页是什么 + 已定决策

设置页是一个**全幅暗玻璃覆盖页**，结构 = 左导航面板（238px：标题块 + 5 标签 + 工作流页脚）+
右主区（动态顶栏 + 可滚动卡片网格）。5 个标签各对应一个分区（section），共 **15 张卡片、
约 30 个设置项**：

| 标签 key | 文案 | 卡片 |
|---|---|---|
| `general` | 通用 | 视觉外观（强调色/白天模式/恢复窗口/磨砂强度）· 首页行为（默认页/欢迎动画）· 语言与时间 |
| `tracking` | 追踪与应用 | 追踪范围（追踪开关/游戏识别/空闲超时）· 应用管理（逐应用显隐）· 分类规则（自动分类/合并窗口） |
| `privacy` | 隐私与数据 | 隐私保护（仅本地/隐藏标题/匿名化）· 存储空间（占用条/缓存·记录/清理·删除）· 权限状态 |
| `memo` | 备忘与番茄钟 | 备忘默认（N 开/自动保存/默认作者）· 番茄钟（默认时长/收缩/祝贺）· 快捷键（只读） |
| `export` | 导入导出 | 导入导出（导出 JSON/导入/复制摘要）· 数据概览（今日/切换/页数/番茄）· 恢复与重置 |

**v88 原型的设置 JS（`17824–18008`）几乎全是前端态**：开关只切 class + 弹 toast，强调色只改
CSS 变量，磨砂滑块只改 `backdrop-filter`，导入导出读写 `localStorage`，番茄/权限/通知**全无后端**。
所以本次复刻 = **视觉 1:1 搬到 QML 暗玻璃**（见美术文）+ **把每个设置项接到真实后端**：能接的接
（`SettingsRepository` / 各 manager），接不了的**诚实占位**并登记到问题文档（**G6：不造假**）。

### 已定决策（D-*，与美术文共享编号）

- **D-FULLBLEED**：设置页升为全幅暗玻璃，与日历/统计同列。仅改 `DesktopAppShell.qml`
  两处非冻结 .qml 体：`:61–62` `fullBleedPage` += `"settings"`；`:296` 栅格纹 `visible`
  += `selectedPage === "settings"`。**不**新增路由（navItems `:135` 已有「设置」、
  currentPageSource `:171` 已映射）。
- **D-EXTEND-IN-PLACE**：**就地重皮 + 扩建 `DesktopProfilePage.qml`**（保留文件名 + 路由 +
  既有 `nightModeToggled` 信号契约），**不新建** `DesktopSettingsPage.qml`。理由：(a) 路由/
  夜间信号/主题注入已连好（Shell `:822–830`）；(b) 避免编辑 `qml/CMakeLists.txt` 资源清单
  （虽**非冻结**但多一处触点）+ 避免改 Shell `:171` 路由 + 避免删旧页。**可选（MAY）**：若坚持
  正名为 `DesktopSettingsPage.qml`，须同改 `qml/CMakeLists.txt`（非冻结）+ Shell `:171` +
  删旧文件——登记为命名决策（问题文档 A-NAME）。
- **D-THEME=NIGHTMODE**：v88「暗玻璃 ⟺ 白天浅瓷」二态映射到既有 `nightMode`
  （驱动 `MemoryLakeStyle.night`）。通用页「白天模式色调」开关 = `!nightMode`，
  勾选 = 白天 → 发 `nightModeToggled(false)`；**页本身不持久化** `night_mode`，由 Shell
  `onNightModeChanged` 写盘（避免双写，R5 范式）。沿用 `DesktopProfilePage.applyThemeMode`
  既有实装。**注**：v88 原型默认暗、TimeArc 默认昼（`night_mode=false`）——保留 App 现默认昼，
  属产品默认值（问题文档 A-DEFAULT），非保真破坏。
- **D-PERSIST-KV**：所有「UI 偏好」型设置一律 `SettingsRepository`
  `getBool/getValue` 读默认 + 改动即 `setBool/setValue` 写盘（即时持久化范式，同
  `language_mode`）。**不**新增 C++ KV 类型；int/对象由 QML 自行 JSON 编码进 TEXT。
- **D-READONLY-DATA**：设置页对 usage 数据**只读**。绝不写/删 `usage_records.jsonl`、
  绝不碰服务磁盘契约/schema。「数据概览」只读现有 manager；「清理/删除」类危险动作受契约
  约束（D1 追加-only）→ 受限/产品决策（问题文档 §7）。
- **D-CLASSIFY-IS-UI**：游戏识别 / 自动分类 / 合并窗口**已在 UI 读层实装**
  （`usage_stat_manager.cpp classifyActivity/appGroupKey`，恒开、确定性）。故这三个「追踪」开关
  其实是 **UI 读层开关**（轻胶水），**不是**服务改动；只有「总追踪开关」「空闲超时」才真碰服务。

---

## §1 QML 组件架构（重皮 · 复用优先）

```
DesktopProfilePage.qml（Item，就地重皮为全幅暗玻璃；保留 nightMode + nightModeToggled 契约）
├─ MemoryLakeStyle { id: ml; night: nightMode }                 // 单一令牌源（同日历/统计）
│  // 背景三件套由 Shell 绘制（D-FULLBLEED）；本页根透明，只画前景
├─ RowLayout（238 左面板 + 1fr 右主区，spacing 18，padding 18）
│  ├─ 左面板 GlassPanel{ ml }                                    // §2.1
│  │   ├─ 标题块（kicker/标题/说明/原型提示条→改真实口径）
│  │   ├─ Repeater 标签×5（三态，复用统计 range-Tab 配方）        // §2.2
│  │   └─ 页脚（workflow-map 4 步 + sync-dot 发光点）
│  └─ 右主区 ColumnLayout
│      ├─ 顶栏（h3/p 动态 + GlassTextField 搜索 + ghost 返回按钮）// §2.3 / §2.4
│      └─ SilkyFlickable 滚动区
│          └─ 5×分区 Item（visible 切换 + 入场动画）
│              └─ GridLayout columns:2（wide 卡 columnSpan:2）
│                  └─ 卡片 GlassPanel/FrostCard（卡头+图标徽章+设置行…）
└─ 设置 Toast（复用日历 calToast，页内底部居中）                  // §2.10
```

**新建可复用控件（暗玻璃，无既有等价；详见美术文 §7 + 问题文档 UI-*）**：
- `GlassSwitch.qml` —— 轨+旋钮 pill 开关（**无既有**；港 `MobileSwitch` 位移范式重做暗皮）。
- `GlassComboBox.qml` —— 自绘下拉（**无既有**；关原生 Controls，仿日历自绘 dropdown）。
- `GlassTextField.qml` —— 玻璃输入（**无既有组件**；提取日历 inline 输入范式）。
- `GlassSlider.qml` —— 值滑块（**全无**；`DragHandler`/`MouseArea` over trackBg 轨 + 旋钮）。
- `KbdChip.qml`（MAY） —— 键帽芯片（中性 `calGhostBg` + mono 字）。

**直接复用**：`GlassPanel` / `FrostCard` / `RoundedFrame` / `GlowCircle` / `GridTexture` /
`SilkyFlickable` / `AppVisual.js`（应用图标主色/首字）/ 日历 `calToast` 范式 /
统计 range-Tab 三态范式。

---

## §2 功能子系统逐项规格（规则 / 标准 / 步骤）

> 每个子节三块：**规则**（v88 确切行为 + 行号，逐字事实）/ **标准**（必须·应当·可选）/
> **步骤**（QML 落地次序）。控件渲染配方在美术文 §7，此处只管**行为 + 状态 + 后端接线**。
> 每项的后端可达性（wired/ui-only/partial/service-change/none）见 §3 矩阵 + 问题文档 §3。

### §2.1 全幅入口与页壳
- **规则**：v88 `.settings-page` 由侧栏「设置」按钮 `openSettingsPage()` 加 `.open` 打开
  （`17851`），关闭 = 返回按钮 / Esc / 切到首页·回顾（`17861–18008`）。
- **标准**：
  - **必须**：复用 Shell 既有导航——点侧栏「设置」即 `selectedIndex = indexOf("settings")`，
    Loader 载入本页；**不**自造覆盖层开合（Shell 已管页切换）。
  - **必须**：`fullBleedPage` 与栅格纹 `visible` 均含 `"settings"`（D-FULLBLEED），否则非全幅。
  - **应当**：入场动画对齐 v88 `.open`（opacity+translateY+scale，`ml.easeSnappy`，`running:true` 自启）。
- **步骤**：① 改 Shell `:61–62` + `:296`；② 本页根 `Item` 透明 + `MemoryLakeStyle{ night:nightMode }`；
  ③ 加可选入场动画。

### §2.2 标签切换（5 分区）
- **规则**：点标签 → 该标签 `.active` + 对应 section `.active` + 顶栏标题/描述换成 `settingsCopy[key]`
  + **清空搜索** + 取消所有 `hidden-by-search`（`17887–17899`）。`settingsCopy` 5 套文案（`17835`）。
- **标准**：
  - **必须**：单选互斥，切换即换 section + 换顶栏 `settingsCopy`（下表逐字）+ 清空搜索框 + 复位卡片可见。
  - **必须**：分区入场动画 `settingsSectionIn`（美术文 §6.2）。
  - **应当**：默认进入 `general`（active）。
- **settingsCopy 文案表（逐字，`17835–17841`）**：

  | key | 顶栏标题 | 顶栏描述 |
  |---|---|---|
  | general | 通用设置 | 控制界面外观、启动行为和基础体验。 |
  | tracking | 追踪与应用 | 管理使用时间记录、应用分类和显示范围。 |
  | privacy | 隐私与数据 | 控制本地保存、敏感信息隐藏和缓存清理。 |
  | memo | 备忘与番茄钟 | 调整备忘录、便签、页面和番茄钟的默认行为。 |
  | export | 导入导出 | 备份设置、复制配置或恢复默认状态。 |
- **步骤**：① `property string activeTab: "general"`；② Repeater 标签 onClicked 设 activeTab + 清搜索；
  ③ 5 分区 `visible: activeTab===key`；④ 顶栏 `h3/p` 绑 settingsCopy[activeTab]。

### §2.3 顶栏标题/描述/返回
- **规则**：顶栏 `h3#settingsTopTitle`/`p#settingsTopDesc` 随标签变；返回按钮「返回首页」=
  `closeSettingsPage()` → 回首页（`17876`）。
- **标准**：**必须** 返回 = `requestNavigate("memorylake")`（须把 `"settings"` 加入 Shell
  `:810` requestNavigate 连接条件，否则信号不通）。**应当** Esc 亦返回（QML `Keys`/`Shortcut`）。
- **步骤**：① 声明 `signal requestNavigate(string pageKey)`；② 改 Shell `:810` 条件含 settings；
  ③ 返回按钮/Esc → `requestNavigate("memorylake")`。

### §2.4 搜索过滤
- **规则**：输入即把**当前 active 分区**内 `.settings-card` 按 `textContent + data-keywords`
  做包含匹配，不匹配加 `hidden-by-search`（`17927–17934`）。keywords 见各卡 `data-keywords`。
- **标准**：
  - **必须**：只过滤当前分区；匹配源 = 卡片可见文本 + 关键词集；空查询全显。
  - **应当**：大小写不敏感、去空白（同 v88 `trim().toLowerCase()`）。
  - **可选**：无命中时显示空态提示。
- **步骤**：① 每卡带 `property string keywords`（逐字搬 v88 `data-keywords`）；
  ② 搜索框 onTextChanged → 遍历当前分区卡片设 `visible`；③ 切标签清空（§2.2）。

### §2.5 通用·视觉外观卡
- **规则**：4 颗强调色点（`data-accent`，点击设 `--settings-accent` + toast「强调色已更新」`17908`）;
  白天模式开关（`#dayModeToggle` 切 `body.light-mode` + 持久化 `memoryLakeThemeMode` + toast `18696`）;
  「启动时恢复上次位置」开关（on）; 磨砂滑块 8–36 默认 24（live 改 `backdrop-filter` + change toast `17918`）。
- **标准**：
  - **必须（白天模式）**：开关态 = `!nightMode`；切换发 `nightModeToggled(!checked)`；**不**自持久化（D-THEME）。
  - **必须（强调色）**：选中态即时高亮 + `setValue("accent_color", hex)` 持久化。
    **全局应用**强调色需令牌可注入（**ui-only→架构改**，问题文档 G-ACCENT）；最小落地仅持久化 + 本页高亮。
  - **应当（恢复窗口）**：`setBool("restore_window", v)`；真正恢复窗口/侧栏几何 = partial（问题文档 G-WIN）。
  - **应当（磨砂强度）**：`setValue("blur_strength", v)` 持久化；**但 QML 无实时背景模糊**
    （D-NO-BACKDROP-BLUR）→ 映射为玻璃叠色近似或标注占位（问题文档 G-BLUR）。
- **步骤**：① 4 accent 点 Row + 选中 ✓ + setValue；② GlassSwitch(白天) 绑 `!nightMode` + 发信号；
  ③ GlassSwitch(恢复) + setBool；④ GlassSlider(磨砂) + setValue + toast。

### §2.6 通用·首页行为 / 语言与时间
- **规则**：默认页 select（首页/备忘录/记忆回顾）; 欢迎动画开关(on); 界面语言 select(简中/English/日本語);
  时间格式 select(24/12 小时制)。v88 全为前端态。
- **标准**：
  - **应当（默认页）**：`setValue("landing_page", key)`；Shell 启动读它并 `requestNavigate`（partial，G-LANDING）。
  - **应当（欢迎动画）**：`setBool("show_welcome", v)`；门控入场动画（ui-only）。
  - **应当（语言）**：复用 `language_mode`（已实装 zh/en）；**扩 `ja`**；全局生效需 i18n 层（partial，G-I18N）。
  - **可选（时间格式）**：`setValue("time_format","24"|"12")`；QML 时间格式化读取（ui-only，G-TIMEFMT）。
- **步骤**：① 4 个 GlassComboBox/项；② 各自 getValue 读默认 + onActivated 写盘；
  ③ 语言下拉沿用 `applyLanguage` + 加 ja 分支。

### §2.7 追踪·追踪范围 / 应用管理 / 分类规则
- **规则**：追踪开关(on); 游戏识别(on); 空闲超时 select(5/10/15/30 分); 应用清单(3 项各开关);
  自动分类(on); 合并窗口(on)。v88 全前端。
- **标准**：
  - **必须（诚实）**：游戏识别/自动分类/合并窗口**已在读层恒实装**（D-CLASSIFY-IS-UI）——开关落地为
    **UI 读层短路**（关 → 退回原始 app 分组 / 不归类），`setBool` 持久化（wired+胶水）。
  - **已实装（服务边界，H5 PR #42）**：「追踪正在运行的应用」总开关 + 「空闲超时」真改捕获行为属服务，
    经**磁盘配置通道**（非 IPC，守 I1）落地：UI 写 `usage_config.json`（`track_enabled`/`idle_threshold_ms`），
    服务启动读入；track 关＝服务真停采集并退出；「应用并重启采集」即时生效（编译期 `#define` 仍是缺省回退）。
    详见 `docs/h5-service-config-channel-kickoff.md` + `rules/03-data-contract.md`「Service config (H5)」。
  - **应当（应用显隐）**：`setValue("hidden_apps", JSON)` + `UsageStatManager` 聚合加排除过滤
    + 清单绑 `appRepository.getAllApps()`（partial，G-HIDEAPP）。
- **步骤**：① GlassSwitch×N + setBool；② 空闲超时 GlassComboBox + 标注服务受限；
  ③ 应用清单 Repeater(getAllApps) + 逐项 GlassSwitch → 写 hidden_apps 集。

### §2.8 隐私·隐私保护 / 存储空间 / 权限状态
- **规则**：仅本地(on); 隐藏敏感标题(on); 匿名化分享图(off); 存储条(47%)+缓存42MB/记录1283;
  清理缓存/删除历史(danger); 应用使用权限(OK 徽标); 系统通知权限(on)。
- **标准**：
  - **必须（标题处理）**：窗口标题**必须保留捕获**（驱动分类/站点识别）；「隐藏敏感标题」=
    **读出端脱敏**——`UsageStatManager` 输出前把 `windowTitle` 换成 `classifyActivity` 类别
    （partial，G-HIDETITLE）。匿名化分享图同理在导出端替换显示名（partial，G-ANON）。
  - **应当（仅本地）**：架构本就无上传/网络代码 → `setBool("privacy_local_only")` 为**安抚/占位**
    （ui-only，无可禁用项）。
  - **应当（存储）**：加只读 `Q_INVOKABLE` 返回 jsonl/db 文件字节 + 记录数（`m_records.size()`），
    QML 渲染占用条（partial，G-STORAGE）。
  - **必须（清理/删除）**：受契约 D1（追加-only）约束——**不可**由 UI 重写/删 jsonl/db。
    仅可清 UI 私有/派生缓存；真删历史 = 停服务 + 迁移工具（**service-change + 产品决策**，G-CLEAR）。
  - **应当（权限/通知）**：Windows 前台捕获无需正式授权 → 权限状态可恒「OK」或启发式探测；
    系统通知**无后端**（无 `QSystemTrayIcon`/无番茄）→ 开关为**占位**直至建通知能力（none，G-NOTIFY）。
- **步骤**：① 隐私开关×3 + setBool（标题/匿名走读出端脱敏）；② 存储条绑新 Q_INVOKABLE；
  ③ 清理/删除按钮**缩到安全范围** + 危险二次确认；④ 权限徽标 + 通知开关（占位+说明）。

### §2.9 备忘与番茄钟
- **规则**：N 开备忘(on); 自动保存笔迹便签(on); 默认便签作者(input "JusTin D");
  默认时长 select(25/30/45/60); 像素番茄收缩(on); 结束全屏祝贺(on); 快捷键格(N/Del/Esc/Wheel 只读)。
- **标准**：
  - **应当（备忘）**：N 开 = Shell 加 `Shortcut "N"` 门控 `getBool("memo_hotkey_n")`；自动保存 =
    门控既有保存调用（备忘已恒持久化 `memoryLakeMemoDoc`）；默认作者 = `setValue("memo_signature")`
    供便签读取（partial/ui-only，G-MEMO）。
  - **必须（番茄诚实）**：**当前无番茄钟引擎**（`timer_manager` 是手动正计时，非倒计时；全无
    pomodoro/收缩/祝贺/通知代码）。默认时长/收缩/祝贺三项**无可门控的功能**——持久化值可存，但
    **不得伪装成生效**（G6 不造假）。落地：要么本期**隐藏番茄卡**（推荐占位），要么标注「待番茄钟能力」
    （none，G-POMODORO，新能力 + 产品决策）。
  - **必须（快捷键格）**：纯静态展示，无持久化/后端。
- **步骤**：① N 开/自动保存 GlassSwitch + setBool；② 默认作者 GlassTextField + setValue；
  ③ 番茄卡按决策**隐藏或显式占位**（勿接假倒计时）；④ 快捷键 KbdChip 静态网格。

### §2.10 导入导出 / 数据概览 / 恢复重置 + Toast
- **规则**：导出设置 JSON / 导入设置(file) / 复制配置摘要（`17936–17987`）; 数据概览(今日8.9h/切换42/
  备忘页1+/番茄Ready); 恢复视觉默认(`17989`) / 清空本地缓存(confirm + 清 localStorage `17996`)。
- **标准**：
  - **应当（导出）**：加 `SettingsRepository.getAllSettings()`（`SELECT key,value`→QVariantMap），
    QML 序列化 JSON + **复用** `usageStatManager.exportReport(name, json)`（已写下载/文档目录，
    非契约文件）（partial，G-EXPORT）。
  - **应当（导入）**：`FileDialog` 选文件 + 读 JSON（`XMLHttpRequest file://` 或小 `Q_INVOKABLE`
    readTextFile）+ 逐键 `setValue`（partial，G-IMPORT）。
  - **可选（复制摘要）**：QML 拼摘要串 + 剪贴板（ui-only）。
  - **必须（数据概览·诚实）**：今日使用 = `usageStatManager` 今日属性 / `projectManager.todayProjectMinutes`
    （wired）；切换次数 = QML 从 `foregroundSegmentsForRange` 会话数派生（无需 C++，同统计 G-4）；
    备忘页数 = 从 memo doc 派生；**番茄态 = 无源**（无番茄）→ 显「—」或隐藏，**勿写死 "Ready"**（partial）。
  - **应当（恢复默认）**：把视觉键（accent/blur/welcome/theme）`setValue` 回默认 + 刷新绑定（ui-only）。
  - **必须（清空缓存）**：同 §2.8——仅清 UI 私有/派生缓存 + 二次确认；**不**碰服务 usage/db（G-CLEAR）。
  - **必须（Toast）**：所有写动作弹 toast（文案表见下），复用日历 `calToast`（1.3–1.6s 自隐）。
- **toast 文案表（逐字，v88 JS）**：开关 on/off →「功能已开启/已关闭」；强调色→「强调色已更新」;
  磨砂→「磨砂强度已保存」; 白天/黑夜→「已切换到白天/黑夜模式」; 导出→「设置 JSON 已导出」;
  导入→「设置文件已读取」/「JSON 文件格式不正确」; 复制→「配置摘要已复制」; 恢复→「视觉设置已恢复默认」;
  清空→「本地缓存已清空」。
- **步骤**：① 三按钮（导出/导入/复制）接 getAllSettings/exportReport/FileDialog/clipboard；
  ② 概览 metric 绑真实 manager（番茄占位）；③ 恢复/清空按钮 + 二次确认 + toast。
- **附加（F2 · 超出 v88 原型 · 已实装 PR #43）**：export tab 末尾增「关于与开源许可」卡——第三方组件
  名+版本+许可+链接方式（Qt 6.11.1 / SQLite 3.51.3 / Parson 1.5.3 / TimeArc 0.1）+「查看全文」玻璃弹层
  （`SilkyFlickable`）读 `resources/licenses/` qrc 内嵌文本、离线可达。**坑**：QML `XMLHttpRequest` 读 `qrc:`
  默认禁；改 `qrc:/`→`:/` 走 `readTextFile()`。规则/同步见 `.harness/rules/06-licensing.md §4`；启动文档
  `docs/f2-in-app-licenses-page-kickoff.md`。

---

## §3 持久化与数据模型（SettingsRepository 键表 + 可用矩阵）

**存储**：`SettingsRepository`（`src/services/settings_repository.{h,cpp}`，**非冻结**）=
SQLite `settings` 表（`key TEXT PK, value TEXT, updated_at INT`，`ON CONFLICT` upsert），
经 QML context property **`settingsRepository`**（`main.cpp:141`）暴露。API **仅**
`getValue/setValue`（串）+ `getBool/setBool`（布尔，存字面 "true"/"false"）+ `migrateLegacyQSettings`。
**无** `getInt/getAll/keys`、**无** Q_PROPERTY/信号（读为快照，须缓存进本地 property）。
表虽物理在服务同款 `timearc.db`，但**是 UI 私有 KV，非 JSONL 服务契约**。

**现有键（勿撞名）**：`night_mode`、`language_mode`、`calendar_saved_todos`、`calendar_day_photos`、
`calendar_selected_date`、`local_memo_chat_messages`、`memoryLakeMemoDoc`、`memoryLakeMemoPomodoro`、
`legacy_qsettings_migration_v1_done`、（seed 但未用：`current_theme`/`first_launch`）。

**本页拟新增键 + 后端可达性矩阵**（状态：✅wired / 🟢ui-only / 🟡partial / 🧱service-change / 🔴none）：

| 设置项 | 拟键名 | 状态 | 后端接线 / 缺口 |
|---|---|---|---|
| 白天模式 | `night_mode`(现) | ✅ | `nightModeToggled`→Shell setBool（勿自写） |
| 语言 | `language_mode`(现)+ja | 🟡 | 持久化已通；全局 i18n 缺（G-I18N） |
| 强调色 | `accent_color` | 🟢/🟡 | 持久化即得；全局应用需令牌可注入（G-ACCENT） |
| 磨砂强度 | `blur_strength` | 🟢 | 持久化即得；无真实背景模糊（G-BLUR） |
| 恢复窗口位置 | `restore_window` | 🟡 | 需启动读+应用窗口/侧栏几何（G-WIN） |
| 默认页 | `landing_page` | 🟡 | Shell 启动读+requestNavigate（G-LANDING） |
| 欢迎动画 | `show_welcome` | 🟢 | 门控入场动画 |
| 时间格式 | `time_format` | 🟢 | QML 格式化读取（G-TIMEFMT） |
| 游戏识别 | `game_mode` | ✅ | 读层短路（classifyActivity，恒实装） |
| 自动分类 | `auto_classify` | ✅ | 读层短路（同上） |
| 合并窗口 | `merge_windows` | ✅ | 读层短路（appGroupKey，恒实装） |
| 总追踪开关 | `track_running` | ✅ | UI 软暂停 + 写 `usage_config.json` `track_enabled`→服务真停采集（H5，PR #42） |
| 空闲超时 | `idle_timeout` | ✅ | 写 `usage_config.json` `idle_threshold_ms`→服务启动读入（H5，PR #42） |
| 应用显隐 | `hidden_apps`(JSON) | 🟡 | UsageStatManager 加排除过滤（G-HIDEAPP） |
| 仅本地 | `privacy_local_only` | 🟢 | 安抚占位（无上传可禁） |
| 隐藏标题 | `hide_titles` | 🟡 | 读出端脱敏（保捕获）（G-HIDETITLE） |
| 匿名分享图 | `anonymize_export` | 🟡 | 导出端替换显示名（G-ANON） |
| 存储占用 | （只读派生） | 🟡 | 新增 Q_INVOKABLE 文件字节+记录数（G-STORAGE） |
| 清理/删除历史 | （动作） | 🧱 | 契约 D1 追加-only，受限（G-CLEAR） |
| 权限状态 | （只读） | 🔴 | Windows 无正式授权（G-PERM） |
| 通知权限 | `notify_enabled` | 🔴 | 无通知能力（G-NOTIFY） |
| N 开备忘 | `memo_hotkey_n` | 🟡 | Shell 加 Shortcut 门控（G-MEMO） |
| 自动保存笔迹 | `memo_autosave` | 🟡 | 门控既有保存（G-MEMO） |
| 默认便签作者 | `memo_signature` | 🟢 | 便签读默认作者 |
| 番茄默认时长 | `pomodoro_duration` | 🔴 | 无番茄引擎（G-POMODORO） |
| 番茄收缩/祝贺 | `pomodoro_*` | 🔴 | 同上 |
| 导出/导入设置 | （动作） | 🟡 | 需 getAllSettings()+exportReport/FileDialog（G-EXPORT/G-IMPORT） |
| 复制摘要 | （动作） | 🟢 | QML 拼串+剪贴板 |
| 数据概览 | （只读派生） | 🟡 | 今日/切换/页数可得；番茄无源 |
| 恢复视觉默认 | （动作） | 🟢 | setValue 回默认 |

> 详细缺口接口/风险/分阶段见 **`docs/settings-implementation-issues.md`** §3/§7。

---

## §4 复刻规则总纲（全局条款 · 法规）

> 体例：**必须 (MUST) / 应当 (SHOULD) / 可选 (MAY)**。违反「必须」即不合格。

- **G1（token 单源，MUST）**：颜色/圆角/缓动一律取 `MemoryLakeStyle`，禁止散落 hex/rgba；
  缺令牌按美术文 §9 新增（如 `protoAmber*`），不就地造色。
- **G2（全幅范式，MUST）**：背景三件套由 Shell 绘，本页根透明只画前景；改 Shell `:61–62`+`:296`+`:810`
  三处即得全幅 + 栅格 + 返回路由。
- **G3（持久化范式，MUST）**：读 = `getBool/getValue(key, default)` 缓存进本地 property；
  写 = 改动即 `setBool/setValue`。`night_mode` **由 Shell 写**，页只发 `nightModeToggled`（勿双写）。
- **G4（磁盘契约边界，MUST）**：设置页对 usage `jsonl`/`db` **只读**；任何「写/删/暂停捕获」类
  动作不得越过契约（I2/D1）或加 IPC（I1）；越界项一律降级为 UI 近似或登记服务改提案（§8 + 问题文档）。
- **G5（读层而非服务，MUST）**：分类/合并/游戏识别开关落地为 UsageStatManager 读层短路，**不**改服务。
- **G6（不造假 / 诚实占位，MUST）**：无真实后端的项（番茄/通知/权限/番茄态指标）**禁止**写死假值
  （勿留 "Ready"/假 OK/假倒计时）；用空态/中性占位/隐藏 + 文案说明。
- **G7（无新增 C++ 文件，SHOULD）**：后端胶水**优先扩** `settings_repository.*` / `usage_stat_manager.*`
  现有 .cpp/.h（**非冻结**，加方法免提案），**不新建** .cpp（会动冻结 `src/CMakeLists.txt` → 须提案）。
- **G8（就地重皮，SHOULD）**：扩 `DesktopProfilePage.qml` 不新建页（D-EXTEND-IN-PLACE）；若新建须同改
  非冻结 `qml/CMakeLists.txt` + Shell `:171` + 删旧。
- **G9（自绘控件，MUST）**：下拉/输入/滑块/开关**关原生 Qt Controls 外观**（暗底下原生浅皮突兀），
  新建 `Glass*` 控件自绘三态（美术文 §7）。
- **G10（Qt6 硬坑，MUST）**：`font.pixelSize` 必为 int；入场动画 `running:true` 自启（勿
  `opacity:0+onCompleted.start` 致整页隐形）；rebuild 前必杀 `TimeArc.exe`（exe 锁）。
- **G11（只读数据派生，SHOULD）**：数据概览/存储/应用清单走与首页/统计同款只读 manager；
  能 QML 派生（切换次数）的不进 C++。

---

## §5 复刻标准 / 验收（Conformance · C 表）

| ID | 验收项 | 级别 |
|---|---|---|
| C0 | 杀 `TimeArc.exe` → `build.py` exit 0 + `scan_qt_log.py` 无新 warning | 必须 |
| C1 | Shell `:61–62`/`:296`/`:810` 三处含 `"settings"`；全幅暗玻璃 + 栅格 + 返回可用 | 必须 |
| C2 | 5 标签切换：section 互斥 + settingsCopy 逐字 + 清搜索 + 复位卡片 + 入场动画 | 必须 |
| C3 | 搜索只过滤当前分区、含 keywords、大小写不敏感、空查询全显 | 必须 |
| C4 | 白天模式开关 = `!nightMode`，发 `nightModeToggled`，**不**自写 night_mode，昼夜整 App 切 | 必须 |
| C5 | 每个 UI 偏好项即时 `setBool/setValue` 持久化，重启保持（getBool/getValue 读回） | 必须 |
| C6 | 分类/合并/游戏识别开关 = 读层短路生效（关→退回原始分组），非装饰 | 必须 |
| C7 | 总追踪/空闲超时**已真生效**（H5，写 usage_config.json→服务读）；仅清理删除历史仍诚实标注契约受限（G-CLEAR，G6/G4） | 必须 |
| C8 | 番茄卡/通知/权限：无后端项隐藏或显式占位，**无**假值（G6） | 必须 |
| C9 | 数据概览今日/切换/页数接真实 manager/派生；番茄态「—」不写死 | 必须 |
| C10 | 导出 = getAllSettings()+exportReport 真落文件；导入 = 真读真写键 | 应当 |
| C11 | 全部 toast 文案逐字对齐 §2.10 表 | 应当 |
| C12 | 新建 `Glass*` 控件暗底无原生浅皮外露；昼夜两态正确 | 必须 |
| C13 | 无散落 hex（G1）；无新增 C++ 文件（G7）；未碰冻结文件 | 必须 |
| C14 | PrintWindow 1280×720 + 最大化 + 昼夜 + 各交互态抓图通过（美术文 §11） | 必须 |

> **PR 三联**：每条款 → 文件:行 → 截图/录屏证据。

---

## §6 复刻方式步骤（实施批次 F-B，咬合美术 M-B）

> 仪式（每批）：杀 `TimeArc.exe` → `build.py` → 启动 → `scan_qt_log.py` →（撑爆 INDEX 行预算时
> `git checkout HEAD -- .harness/journal/INDEX.md errors.jsonl` + 删 pass5 点名 orphan）→
> `record_error.py`（任何 L1/L2/L3）→ `harness_check.py`（冻结 sha256 门）。
> qrc 内嵌 QML 单测须临时改默认（activeTab/nightMode 等）+ rebuild 验证后改回。

- **F-B0 壳与路由**：改 Shell `:61–62`+`:296`+`:810`；本页根透明 + `MemoryLakeStyle`；
  左面板 + 顶栏 + 滚动壳骨架（咬合 **M-B0**）。
- **F-B1 新建 Glass 控件**：`GlassSwitch`/`GlassComboBox`/`GlassTextField`/`GlassSlider`(+`KbdChip`)
  四件套，暗底自绘三态 + 昼夜（咬合 **M-B1**，单独抓图 C12）。
- **F-B2 通用页**：视觉外观（accent/白天/恢复/磨砂）+ 首页行为 + 语言与时间，全部接 §3 键（咬合 **M-B2**）。
- **F-B3 追踪页**：游戏/分类/合并读层短路（G5）+ 应用清单(getAllApps + hidden_apps) + 总追踪/空闲诚实占位（咬合 **M-B3**）。
- **F-B4 隐私页**：仅本地/隐藏标题/匿名（读出端脱敏）+ 存储占用(新 Q_INVOKABLE) + 清理删除(缩范围+确认) + 权限/通知占位（咬合 **M-B4**）。
- **F-B5 备忘番茄页**：N 开/自动保存/默认作者 + **番茄卡按决策隐藏/占位** + 快捷键静态（咬合 **M-B5**）。
- **F-B6 导入导出页**：getAllSettings()+exportReport 导出 + FileDialog 导入 + 复制摘要 + 数据概览(真实+番茄占位) + 恢复/清空（咬合 **M-B6**）。
- **F-B7 收尾**：toast 文案对齐 + 搜索 + 昼夜 + 全量抓图 C 表 + 文档登进 CLAUDE.md/rules/04 索引。

---

## §7 GAPS / 待补充（指向问题文档）

本页所有「需决定 / 后端缺口 / 契约风险 / 产品决策」集中登记于
**`docs/settings-implementation-issues.md`**：
- **A 类（产品/设计决策）**：A-DEFAULT（默认昼/暗）、A-NAME（是否正名文件）、A-CLEAR（清理删除范围）、
  A-PERM（Windows「权限」语义）、A-POMODORO（是否本期建番茄）、A-TRACKPAUSE（总追踪暂停语义）。
- **G- 类（后端硬缺口）**：~~G-TRACK / G-IDLE~~（**已实装 H5，PR #42**）、G-ACCENT / G-BLUR / G-I18N / G-WIN / G-LANDING /
  G-TIMEFMT / G-HIDEAPP / G-HIDETITLE / G-ANON / G-STORAGE / G-CLEAR / G-PERM / G-NOTIFY / G-MEMO /
  G-POMODORO / G-EXPORT / G-IMPORT。
- **B 类（v88 稿件 bug / 不一致）**：B1 原型提示条文案需改真实口径；B2 数据概览写死 "Ready"/假数字；
  B3 权限恒「OK」假态。
- **UI 类（新建控件）**：UI-1 GlassComboBox、UI-2 GlassSlider、UI-3 GlassSwitch、UI-4 GlassTextField/搜索。
- **R 类（渲染缺口）**：R-LIGHT-*（设置页 light 专属 hex 与 cal 昼令牌比对）。

---

## §8 产品边界核对（Charter 硬边界）

- **I1 两进程分离 / 无 IPC**：设置页**不得**向服务加 IPC/socket/共享内存。总追踪开关、空闲超时
  这类「改捕获」诉求 → 只能服务读盘配置（契约修订 + 提案）或 UI 近似，**不可**直连服务（§2.7/G4）。
- **I2 磁盘契约 / D1 追加-only**：`usage_records.jsonl` 追加-only、`timearc.db` 服务实时写——
  「删除历史/清理缓存」**不可** UI 重写；缩到 UI 私有/派生缓存，或停服务迁移工具（§2.8/§2.10）。
- **产品法规 07（AI 卡片）**：设置页**无** AI；不接 AI over raw logs。番茄/通知若建，属本地确定性能力，
  不触 AI 门控。
- **隐私硬边界**：窗口标题保捕获（驱动分类），「隐藏标题/匿名」是**读出端脱敏**，非捕获端抑制；
  不引入聊天内容/截图/OCR/原始音频/浏览历史。

---

## §9 与既有文档关系

- **配套三件套**：本文（功能/行为/法规）+ `settings-render-pipeline-replication.md`（美术/像素）+
  `settings-implementation-issues.md`（问题文档/缺口/决策）。三者开头共用 blockquote 指针块。
- **范式母版**：体例承首页/日历/统计法规（`stats-functional-replication.md` 为最近同构样板）。
- **复用组件**：`GlassPanel`/`FrostCard`/`RoundedFrame`/`GlowCircle`/`GridTexture`/`SilkyFlickable`/
  `AppVisual.js` + 日历 `calToast` + 统计 range-Tab；令牌源 `MemoryLakeStyle`。
- **数据路径**：与首页/记忆湖/统计**同款只读** `usageStatManager`+`dailyCardService`+`projectManager`
  （`db_smoke` 契约注意：DCS 勿引 USM 符号——数据从 QML 传入）。
- **收尾**：完成后登进 `CLAUDE.md` Product Context 设置页条目 + `.harness/rules/04-ui-conventions.md` 索引 +
  agent 记忆 `timearc-settings-page`。
