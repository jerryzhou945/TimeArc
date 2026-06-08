# 设置页 · 实施问题文档（后端缺口 / 技术难点 / 待决策 / 接入计划）

> **当前状态（已超本文档计划）**：设置页已全实装并入 dev（PR #28）；本文为**原始规划 / 缺口清单**，逐项
> **最新落地状态 + 未实装审计 + 服务侧配置提案**见 `docs/settings-remaining-work.md`。下方 §8 复选框是初始
> 规划，未随实装逐个勾选——以 remaining-work 审计为准。
>
> 前置：本文是设置页复刻的**数据侧 + 决策侧问题清单 + 接入计划**，体例对齐
> `docs/stats-backend-data-gaps.md`。配套：`docs/settings-functional-replication.md`（功能/行为/法规）+
> `docs/settings-render-pipeline-replication.md`（美术/像素）。
> 设计稿真值：`MemoryLakeDesign/TimeArcDesign_v88.html`（设置页 DOM `13897–14165`、JS `17824–18008`/
> `18678–18740`）。
> 现状：「设置」路由已存在（`DesktopAppShell.qml:135/171` → `DesktopProfilePage.qml`，奶油浅色简版）；
> 持久化层 `SettingsRepository`（SQLite `settings` 表，UI 私有 KV）已就绪；分类/合并/游戏识别已在
> `usage_stat_manager.cpp` 读层恒实装；番茄/通知/权限/真删历史**零后端**。
> Track：**B（新能力 / 重皮）**。
> 硬边界：两进程无 IPC（I1）、磁盘契约追加-only（I2/D1）、无 AI over logs（rules/07）、
> 标题保捕获只读出端脱敏。
> 纪律：能接的接、接不了的**诚实占位**（G6 不造假），越界的登记服务改提案，不擅碰冻结文件。

---

## 0. 必须解决的问题（开工前需拍板）

设置页约 30 个控件里，**多数是 UI 偏好**（持久化即得），但有 **6 个产品决策**和 **若干服务/契约
受限项**必须先定方向，否则会写出「看着能用、实际是假」的设置。先回答下表（建议默认已标 ★）：

| # | 决策 | 选项 | 建议默认 |
|---|---|---|---|
| A-DEFAULT | 默认主题：v88 默认暗、App 现默认昼 | (a)★保留 App 现默认昼 / (b) 改默认暗对齐 v88 | (a) |
| A-NAME | 文件命名：Profile→Settings | (a)★就地扩 `DesktopProfilePage.qml` / (b) 正名新文件 | (a) |
| A-CLEAR | 「清理缓存/删除历史/清空本地」删什么 | (a)★仅 UI 私有/派生缓存 / (b) 含服务 usage（需停服务迁移工具） | (a) |
| A-PERM | Windows「应用使用权限」语义 | (a)★恒「就绪」（前台捕获无需授权）/ (b) 启发式探测 OpenProcess 失败 / (c) 隐藏此项 | (a) |
| A-POMODORO | 本期是否建番茄钟引擎 | (a)★暂隐番茄卡（无引擎）/ (b) 仅存偏好+占位 / (c) 本期新建倒计时番茄 | (a) |
| A-TRACKPAUSE | 「追踪正在运行的应用」总开关语义 | (a)★UI 近似「暂停读取/排除新记录」/ (b) 真停服务（服务改+契约修订） | (a) |

> 用户拍板后把选项写回本节并在 §6 展开。未拍板项一律按建议默认落地 + 标注，**不**伪装生效。

### 0.1 硬性保证（验收一票否决）

- **不造假（G6）**：番茄态、通知、权限、真删历史等无后端项**禁止**写死假值（"Ready"/假"OK"/假倒计时/
  假删除成功）。无源即空态/占位/隐藏 + 文案说明。
- **不越契约（G4/I1/I2）**：设置页对 usage `jsonl`/`db` 只读；不加 IPC；不 UI 重写/删追加-only 历史。
- **不碰冻结**：不新建 C++ 源（动 `src/CMakeLists.txt`）；后端改只扩现有非冻结 .cpp/.h（§10）。
- **不接 AI**：设置页无 AI（rules/07）。

---

## 1. 核心原则

1. **持久化已解决**：`SettingsRepository`（`getValue/setValue/getBool/setBool`）是现成的 SQLite KV，
   绝大多数外观/体验偏好 = 「加一个 key + 绑定」，**无需新后端**。
2. **分类逻辑在 UI 读层、不在服务**：游戏识别/自动分类/合并窗口已恒实装于
   `usage_stat_manager.cpp`（`classifyActivity`/`appGroupKey`），所以这些「追踪」开关是 **UI 读层短路**，
   不是服务改动——与卡片名给的直觉相反。
3. **捕获行为在服务、UI 不可直控**：总追踪开关、空闲超时**真改捕获**，受两进程无 IPC + 编译期阈值约束，
   UI 单方做不到，需服务改 + 契约修订 + 产品决策。
4. **隐私 = 读出端脱敏**：窗口标题必须保捕获（驱动分类/站点识别）；「隐藏标题/匿名分享」是输出时替换，
   不是捕获时抑制。

---

## 2. 数据复用与接入架构（调用表 + 契约）

| 用途 | 现有调用 / 拟新增 | 文件 | 契约 |
|---|---|---|---|
| 设置读写 | `settingsRepository.getValue/setValue/getBool/setBool` | `settings_repository.cpp`（非冻结） | UI 私有 KV，非 JSONL 契约 |
| 设置全量导出 | **拟加** `getAllSettings()`（`SELECT key,value`→QVariantMap） | 扩 `settings_repository.cpp/.h` | 加方法免提案 |
| 写文件（导出 JSON） | `usageStatManager.exportReport(name, json)`（已写下载/文档目录） | `usage_stat_manager.cpp` | 显式非契约报告文件 |
| 应用清单 | `appRepository.getAllApps()` | `app_repository.h` | 只读 |
| 应用显隐过滤 | **拟加**聚合排除 `hidden_apps` 集 | 扩 `usage_stat_manager.cpp` | 只读层 |
| 存储占用 | **拟加** `Q_INVOKABLE` 文件字节(QFileInfo)+`m_records.size()` | 扩 `usage_stat_manager.cpp` / `database_manager.h getDatabasePath()` | 只读 |
| 隐藏标题/匿名 | **拟加**输出前 `classifyActivity` 替换 | 扩 `usage_stat_manager.cpp` 输出函数 | 只读层脱敏 |
| 今日使用 | `usageStatManager` 今日属性 / `projectManager.todayProjectMinutes` | 已有 Q_PROPERTY | 只读 |
| 切换次数 | QML 从 `foregroundSegmentsForRange` 会话数派生 | QML（无需 C++，同统计 G-4） | 只读 |
| DB 路径 | `databaseManager.getDatabasePath()` | `database_manager.h` | 只读 |
| 夜间模式 | `nightModeToggled`→Shell `setBool("night_mode")` | `DesktopAppShell.qml:202/822` | Shell 拥有，勿双写 |
| 默认页路由 | **拟加**启动读 `landing_page`+`requestNavigate` | 扩 `DesktopAppShell.qml`（非冻结） | UI |
| N 开备忘 | **拟加** Shell `Shortcut "N"` 门控 | 扩 `DesktopAppShell.qml` | UI |

---

## 3. 全量内容清单（逐控件 · 状态 · 最小路径）

> 状态：✅wired（接现成）/ 🟢ui-only（存 KV 即得）/ 🟡partial（需胶水）/ 🧱service-change（碰服务/契约）/
> 🔴none（无后端=新能力）。证据见 §7 G- 条目。

**通用 general**
- ✅ 白天模式开关 —— `nightModeToggled`→Shell；页勿自写 `night_mode`。
- 🟢 强调色 4 点 —— `setValue("accent_color")`；全局应用见 G-ACCENT（升级为 🟡）。
- 🟢 磨砂强度滑块 —— `setValue("blur_strength")`；无真实背景模糊见 G-BLUR。
- 🟡 恢复窗口位置 —— `setBool("restore_window")` + 启动应用几何（G-WIN）。
- 🟡 默认页 —— `setValue("landing_page")` + 启动 requestNavigate（G-LANDING）。
- 🟢 欢迎动画 —— `setBool("show_welcome")` 门控入场。
- 🟡 语言 zh/en/**ja** —— `language_mode` 持久化已通；全局 i18n 缺（G-I18N）。
- 🟢 时间格式 24/12 —— `setValue("time_format")` + QML 格式化（G-TIMEFMT）。

**追踪 tracking**
- ✅ 游戏识别 / ✅ 自动分类 / ✅ 合并窗口 —— 读层短路（classifyActivity/appGroupKey 恒实装）+ `setBool` 持久化。
- 🧱 总追踪开关 —— 服务捕获，UI 不可直控（G-TRACK / A-TRACKPAUSE）。
- 🧱 空闲超时 5/10/15/30 —— 编译期 `#define TIMEARC_USAGE_IDLE_THRESHOLD_MS 60000`（`usage_tracker.h:7`），
  服务不读设置（G-IDLE）。
- 🟡 应用逐项显隐 —— `getAllApps()` + `hidden_apps` JSON + 聚合排除过滤（G-HIDEAPP）。

**隐私 privacy**
- 🟢 仅本地 —— `setBool("privacy_local_only")` 安抚占位（无上传可禁）。
- 🟡 隐藏敏感标题 —— 读出端 `classifyActivity` 替换 `windowTitle`（保捕获）（G-HIDETITLE）。
- 🟡 匿名分享图 —— 导出端替换 displayName（G-ANON）。
- 🟡 存储占用条 + 缓存/记录数 —— 新 Q_INVOKABLE 文件字节 + `m_records.size()`（G-STORAGE）。
- 🧱 清理缓存 / 删除历史 —— 契约 D1 追加-only（G-CLEAR / A-CLEAR）。
- 🔴 应用使用权限状态 —— Windows 无正式授权（G-PERM / A-PERM）。
- 🔴 系统通知权限 —— 无通知能力（G-NOTIFY）。

**备忘番茄 memo**
- 🟡 N 开备忘 —— Shell `Shortcut "N"` 门控 `memo_hotkey_n`（G-MEMO）。
- 🟡 自动保存笔迹 —— 门控既有保存（备忘已恒持久化）（G-MEMO）。
- 🟢 默认便签作者 —— `setValue("memo_signature")` 供便签读默认。
- 🔴 番茄默认时长 / 🔴 像素收缩 / 🔴 结束祝贺 —— **无番茄引擎**（`timer_manager` 是正计时）（G-POMODORO / A-POMODORO）。
- 🟢/— 快捷键格 —— 纯静态展示，无后端。

**导入导出 export**
- 🟡 导出设置 JSON —— `getAllSettings()` + `exportReport()`（G-EXPORT）。
- 🟡 导入设置 —— `FileDialog` + 读 JSON + 逐键 `setValue`（G-IMPORT）。
- 🟢 复制摘要 —— QML 拼串 + 剪贴板。
- 🟡 数据概览 —— 今日/切换/页数可得（manager/派生）；**番茄态无源**（占位）。
- 🟢 恢复视觉默认 —— `setValue` 回默认 + 刷新。
- 🧱 清空本地缓存 —— 同 A-CLEAR。

---

## 4. 问题展开 · 服务边界（最关键缺口）

设置页最大结构性误区：**「追踪」标签看起来在控制后台采集，实际上**——

- **分类/合并/游戏识别**（3 项）已在 **UI 读层**恒实装（服务只存原始 exe+title+时间），所以这些开关
  是**读层短路**（轻胶水），**不**碰服务。✅
- **真正碰服务的只有 2 项**：
  - **总追踪开关**：服务是独立进程、无 IPC、不读 `settings` 表（CHARTER I1 + CLAUDE.md「禁 IPC/socket/
    共享内存进服务」）。UI 单方**无法暂停采集**；UI 侧只能做「暂停读取 / 排除新记录」的**近似**（采集仍在跑）。
    真暂停 = 起停服务进程 / 服务读盘 flag = **服务改 + 契约修订 + 产品决策**（A-TRACKPAUSE）。
  - **空闲超时**：阈值是**编译期** `#define`（`usage_tracker.h:7`），服务不从设置读。改它要么服务启动读
    usage 目录里的配置文件（服务改、契约邻接），要么固定不可调（产品决策）。UI 单方做不到。
- **删除/清理历史**：`usage_records.jsonl` 追加-only（不变量 D1）、`timearc.db` 服务实时写。UI **不可**
  重写/删。只能缩到 UI 私有/派生缓存，或停服务 + 迁移工具/轮转（A-CLEAR）。

> 结论：把这 3 类（总追踪/空闲/删历史）在 UI 上**诚实标注受限**（如灰显 + tooltip「需后台服务支持，
> 规划中」或做明确的 UI 近似），**严禁**做成「点了就以为生效」。

---

## 5. 问题展开 · 无后端子系统（番茄 / 通知 / 权限）

整片**零代码**，属新能力，不是「绑现成后端」：

- **番茄钟**：`timer_manager.h` 是手动**正**计时项目计时器（`startProject/stopAndCommit`，elapsed 累加），
  **无**倒计时/时长/番茄概念；全 src 无 `pomodoro`/`tomato`。故默认时长/收缩/祝贺三项**无可门控功能**。
  - 落地：A-POMODORO=(a) **本期隐藏番茄卡**（推荐，G6 不造假）；(b) 仅存偏好 + 「待番茄钟」占位；
    (c) 本期新建 QML 倒计时番茄（祝贺可复用 `AchievementToast`）——属独立功能开发，超本页范围。
- **系统通知**：全 src 无通知代码（无 `QSystemTrayIcon`/WinRT toast）。通知权限开关在「无通知」时是
  纯占位。建通知能力后才有意义（G-NOTIFY）。
- **权限状态**：Windows 前台捕获用 `GetForegroundWindow/OpenProcess`（`active_app_win.c`），无需正式授权，
  也无 API 把权限态报给 QML。A-PERM=(a) 恒「就绪」/(b) 启发式探 OpenProcess 失败/(c) 隐藏。
  跨平台真权限（macOS 辅助功能/屏幕时间）是新后端，超本页。

---

## 6. 待决问题汇总（产品 / 设计决策 A-*）

| ID | 决策 | 影响 | 建议 |
|---|---|---|---|
| A-DEFAULT | 默认昼 vs 暗 | 首次启动观感 | 保留现默认昼（a） |
| A-NAME | Profile 文件就地扩 vs 正名 | 触点数 / 命名整洁 | 就地扩（a），避免改 CMakeLists+路由+删旧 |
| A-CLEAR | 清理/删除范围 | 数据安全 / 契约 | 仅 UI 私有缓存（a）；真删另起停服务迁移工具 |
| A-PERM | Windows 权限语义 | 文案诚实 | 恒「就绪」（a）或隐藏 |
| A-POMODORO | 本期是否建番茄 | 范围 | 暂隐番茄卡（a） |
| A-TRACKPAUSE | 总追踪开关语义 | 用户预期 vs 真实 | UI 近似 + 诚实标注（a） |
| A-ACCENT-SCOPE | 强调色仅本页 vs 全局 | 架构 | 先持久化 + 本页高亮；全局留 G-ACCENT |

**B 类（v88 稿件 bug / 复刻顺手修）**：
- **B1**：左面板「原型数据说明」条（DOM `13904`）文案是「原型/localStorage/模拟数据」——复刻时**改真实口径**
  （本地 SQLite + 系统采集），勿照搬「原型」字样。
- **B2**：数据概览写死 `8.9h/42/1+/Ready`（DOM `14142`）——接真实值；番茄态无源 → 「—」不写死 "Ready"。
- **B3**：权限恒「OK」假徽标（DOM `14078`）——按 A-PERM 落地，勿假态。

---

## 7. 后端能力差距（硬缺口表 G-*）

> 仅列**需新增/改动后端或有契约风险**者；纯 🟢ui-only（存 KV 即得）不入表。
> 接口建议一律**扩现有非冻结 .cpp/.h**（§10），不新建文件。

| # | 缺口 | 用途 | 建议接口 / 派生 | 风险 |
|---|---|---|---|---|
| G-TRACK | 总追踪开关无法控服务采集 | 追踪范围·总开关 | UI 近似（排除新记录读取）；真停 = 服务读 flag（提案） | 🧱 契约/进程边界；A-TRACKPAUSE |
| G-IDLE | 空闲阈值编译期 #define | 空闲超时 | 服务启动读 usage 目录 config 文件 | 🧱 服务改 + 契约邻接 |
| G-HIDEAPP | 聚合无 per-app 排除 | 应用显隐 | 扩 `usage_stat_manager` 聚合：跳过 `hidden_apps` 集 + `getAllApps()` 绑清单 | 🟡 只读层小改 |
| G-HIDETITLE | 标题原样流入 UI | 隐藏敏感标题 | 输出函数加 `hide_titles` 时以 `classifyActivity` 替换 `windowTitle` | 🟡 保捕获、读出端脱敏 |
| G-ANON | 导出含真实应用名 | 匿名分享图 | 导出模型 `anonymize_export` 时替换 displayName→类别/"App N" | 🟡 UI/导出端 |
| G-STORAGE | 无文件大小/记录数 API | 存储占用条 | 扩 Q_INVOKABLE：`QFileInfo(usageRecordsPath/db).size()` + `m_records.size()` | 🟡 只读 |
| G-CLEAR | 无清理/删除 API + 契约 | 清理缓存/删历史/清空 | 仅清 UI 私有/派生；真删 = 停服务迁移工具 | 🧱 契约 D1；A-CLEAR |
| G-PERM | 无权限探测 | 权限状态 | 恒「就绪」或启发式 OpenProcess 失败探测 | 🔴 Windows N/A；A-PERM |
| G-NOTIFY | 无通知子系统 | 通知权限/番茄提醒 | 新建 `QSystemTrayIcon::showMessage`/WinRT toast | 🔴 新能力 |
| G-MEMO | 无 N 全局快捷 + 无自动保存门控键 | N 开/自动保存 | Shell 加 `Shortcut "N"` 门控 `memo_hotkey_n`；保存调用门控 `memo_autosave` | 🟡 UI |
| G-POMODORO | 无番茄引擎 | 默认时长/收缩/祝贺/番茄态 | 暂隐；或新建倒计时番茄（独立功能） | 🔴 新能力；A-POMODORO |
| G-EXPORT | 无全量设置读 | 导出 JSON | 扩 `SettingsRepository::getAllSettings()`→QVariantMap + 复用 `exportReport()` | 🟡 加方法免提案 |
| G-IMPORT | 无文件读 + 批量写 | 导入设置 | `FileDialog` + `XMLHttpRequest file://` 或小 `Q_INVOKABLE readTextFile` + 逐键 setValue | 🟡 可选加一读文件 helper |
| G-ACCENT | 令牌固定不可注入 | 强调色全局生效 | 把 `MemoryLakeStyle` 强调色改可注入（仿 `injectedTextPrimary`）+ Shell 传 `accent_color` | 🟡 架构改；A-ACCENT-SCOPE |
| G-BLUR | QML 无实时背景模糊 | 磨砂强度 | 映射玻璃叠色不透明度近似，或标注「视觉强度(占位)」 | 🟡 保真天花板 |
| G-WIN | 无窗口几何持久/恢复 | 恢复上次位置 | 关闭写 x/y/w/h+侧栏态；启动读应用到 `ApplicationWindow`+sidebar | 🟡 UI |
| G-LANDING | 启动页固定 | 默认页 | Shell `Component.onCompleted` 读 `landing_page`+`requestNavigate` | 🟡 UI |
| G-I18N | 无 app 级翻译 | 语言全局生效 | qsTr + QTranslator 或共享 strings map（广 UI 工程） | 🟡 范围大但无服务改 |
| G-TIMEFMT | 无 12/24 消费 | 时间格式 | QML 时间格式化读 `time_format`（`Qt.formatTime`） | 🟢→🟡 散落改 |

**UI 控件缺口（新建暗玻璃组件）**：
- **UI-1 `GlassComboBox`**：无可复用暗玻璃下拉（原生 Controls 被刻意回避）。自绘字段 + 浮层。
- **UI-2 `GlassSlider`**：全无 Slider/值轨。`DragHandler`/`MouseArea` over `trackBg` + 旋钮。
- **UI-3 `GlassSwitch`**：无 pill 开关。港 `MobileSwitch` 位移范式重做暗皮。
- **UI-4 `GlassTextField`（含搜索变体）**：无可复用输入组件；提取日历 inline 输入 + 搜索加放大镜/清除。

**渲染缺口（R-*）**：
- **R-LIGHT-N**：v88 设置页 light 专属 hex（`12483–13480` 三处散落）须与 `MemoryLakeStyle` 昼令牌
  逐项比对；不一致处就地补设置页昼令牌（如 `protoAmber` 琥珀提示条昼值、`theme-switch` 昼轨色）。

---

## 8. 分三阶段落地（任务 checkbox）

> 仪式（每阶段尾）：杀 `TimeArc.exe` → `build.py` → 启动 → `scan_qt_log.py` → `record_error.py`
> （任何 L1/L2/L3）→ `harness_check.py`（冻结 sha256 门）。PrintWindow 抓图 1280×720+最大化+昼夜。

**阶段一 · 壳 + 控件 + 纯 UI 偏好（零后端风险）**
- [ ] 1A Shell `:61–62`/`:296`/`:810` += `"settings"`；本页根透明 + `MemoryLakeStyle` + 左面板/顶栏/滚动壳。
- [ ] 1B 新建 `GlassSwitch`/`GlassComboBox`/`GlassTextField`/`GlassSlider`(+`KbdChip`)（UI-1..4）。
- [ ] 1C 通用页全部 🟢 项接 KV：accent/blur/welcome/time_format/language(+ja)/白天模式(信号)。
- [ ] 1D 备忘默认作者(🟢) + 快捷键静态格 + toast 文案对齐 + 搜索过滤。
- [ ] 1E B1 原型提示条改真实口径。

**阶段二 · 读层胶水（只读，不碰服务/契约）**
- [ ] 2A 游戏/分类/合并开关 = 读层短路（扩 `usage_stat_manager`）+ 持久化。
- [ ] 2B 应用清单 `getAllApps()` + `hidden_apps` + 聚合排除（G-HIDEAPP）。
- [ ] 2C 隐藏标题/匿名 = 读出端脱敏（G-HIDETITLE/G-ANON）。
- [ ] 2D 存储占用条 = 新 Q_INVOKABLE 文件字节+记录数（G-STORAGE）。
- [ ] 2E 数据概览接真实 manager + 切换次数 QML 派生；番茄态占位（B2）。
- [ ] 2F 导出 getAllSettings()+exportReport（G-EXPORT）+ 导入 FileDialog（G-IMPORT）+ 复制摘要 + 恢复默认。
- [ ] 2G N 开/自动保存门控（G-MEMO）+ 默认页 landing(G-LANDING) + 恢复窗口(G-WIN)。

**阶段三 · 受限/新能力（需决策/服务改/超范围）**
- [ ] 3A 总追踪/空闲超时：按 A-TRACKPAUSE 做 UI 近似 + 诚实标注（G-TRACK/G-IDLE）。
- [ ] 3B 清理/删除：按 A-CLEAR 缩到 UI 私有缓存 + 二次确认（G-CLEAR）。
- [ ] 3C 权限/通知：按 A-PERM 落地 + 通知占位（G-PERM/G-NOTIFY）。
- [ ] 3D 番茄卡：按 A-POMODORO 隐藏/占位（G-POMODORO）。
- [ ] 3E 强调色全局 + i18n 全局：按 A-ACCENT-SCOPE / 范围评估（G-ACCENT/G-I18N）。

---

## 9. 数据契约 / 隐私 / 安全边界

- **I1 无 IPC**：设置页不向服务加任何 IPC/socket/共享内存；总追踪/空闲只能 UI 近似或服务读盘配置（提案）。
- **I2 / D1 追加-only**：不 UI 重写/删 `usage_records.jsonl` / `timearc.db`；删除类缩到 UI 私有/派生缓存。
- **隐私捕获**：窗口标题保捕获（驱动分类/站点）；隐藏标题/匿名 = 读出端脱敏；不引聊天/截图/OCR/原始音频/
  浏览历史（CLAUDE.md 硬边界）。
- **AI 门控**：设置页无 AI；番茄/通知若建为本地确定性能力，不触 AI 法规（rules/07）。
- **导出文件**：`exportReport` 写下载/文档目录，是显式非契约文件；导出内容仅 `settings` 表（不含原始 usage）。

---

## 10. 代码编辑法规 — 文件红线

- **冻结文件（CHARTER §3，改前须提案）**：顶层 `CMakeLists.txt`、`src/CMakeLists.txt`、
  `src/service/CMakeLists.txt`、`src/service/shared/*`、`src/include/util.h`、CHARTER/AGENTS。
- **可直接改（非冻结）**：`src/services/settings_repository.{h,cpp}`（加 `getAllSettings` 等）、
  `src/services/usage_stat_manager.{h,cpp}`（加排除过滤 / 文件大小 / 记录数 / 脱敏输出）、
  `qml/desktop/DesktopAppShell.qml`（fullBleed/栅格/requestNavigate/Shortcut/landing）、
  `qml/desktop/pages/DesktopProfilePage.qml`（就地重皮）、`qml/CMakeLists.txt`（若新建 .qml 才需）。
- **G7 红线**：**不新建 C++ 源文件**（会动冻结 `src/CMakeLists.txt`）；所有后端胶水扩进上述现有 .cpp/.h。
  这是 stats 页验证过的免提案路径。
- **db_smoke 契约注意**：`daily_card_service.cpp` 链接进 db_smoke 但 `usage_stat_manager.cpp` 不链接——
  DCS 勿引 USM 符号；数据从 QML 传入（沿用现状）。

---

## 11. 验收总清单（分阶段 checkbox）

- [ ] **阶段一**：全幅暗玻璃 + 5 标签 + 搜索 + 4 新控件昼夜两态 + 纯 UI 偏好重启保持（C1–C5/C12）。
- [ ] **阶段二**：分类/合并/游戏开关真生效（读层）、应用显隐、隐私脱敏、存储占用真值、数据概览真值/派生、
  导入导出真落盘（C6/C9/C10）。
- [ ] **阶段三**：受限项诚实标注/近似、无后端项隐藏或占位、**无任何假值**（C7/C8/G6）。
- [ ] **全程**：无散落 hex（G1）、无新增 C++ 文件、未碰冻结（C13/§10）、toast 文案逐字（C11）、
  PrintWindow 全档抓图（C14）、`scan_qt_log` 零警告 + `harness_check` exit 0（C0）。

---

## 12. 实测登记（状态前缀 OPEN / RESOLVED / WONTFIX）

> 实施时按条追加，格式：**[OPEN]/[RESOLVED]/[WONTFIX] <ID> <topic>**（YYYY-MM-DD）：现象 … 处置 …
> （引 `record_error.py` level）。

- **[OPEN] A-* 全部决策**（2026-06-07）：等用户拍板；未拍板按 §0 建议默认落地 + 标注。
- **[OPEN] G-* 后端缺口**（2026-06-07）：按 §8 三阶段推进；阶段三诸项依赖 A-* 决策。
- （后续逐条登记 …）
