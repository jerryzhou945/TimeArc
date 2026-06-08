# 设置页 · 未实现 / 未接线内容归纳（实测审计）

> 配套：`settings-functional-replication.md`（功能法规）/ `settings-render-pipeline-replication.md`（美术）/
> `settings-implementation-issues.md`（缺口 G-* · 决策 A-* · 三阶段）。本文档只做一件事：**逐项实测每个
> 设置控件的真实落地状态**，把「未实现 / 仅持久化 / 受限」的内容归纳成单一清单，供后续排期。

## 目的与方法

- 范围：`qml/desktop/pages/DesktopProfilePage.qml` 全部 5 个分区（通用 / 追踪与应用 / 隐私与数据 /
  备忘与番茄钟 / 导入导出）的每一个控件。
- 判定方法：对每个 KV 键全仓 grep 其**消费者**（设置页之外谁真正读取并产生效果），以 `file:line` 取证。
  「持久化」≠「已实现」——只有存在真实消费者且产生可观察效果，才记为 ✅。
- 实测时间：2026-06-09（对应分支 `feat/settings-page-dark-glass` / PR #28，HEAD `94db36b`）。

## 图例

| 记号 | 含义 |
|---|---|
| ✅ | 已实装：持久化 + 真实消费者 + 可观察效果 |
| 🟡 | 部分：持久化通，但效果受限 / 仅边界生效 / 仅近似 |
| ⬜ | **仅持久化**：存了值但**无任何消费者**（纯空转，需补接线） |
| 🧱 | 契约 / 平台阻断：UI 内无法真正实现（需提案、服务侧工具或系统能力） |
| 🚫 | 该功能在对应模块**已废弃**，设置项形同虚设 |

---

## 一、逐控件状态全表

### 通用（general）

| 控件 | KV 键 | 状态 | 真实消费者 / 取证 | 备注（缺口） |
|---|---|---|---|---|
| 强调色 4 点 | `accent_color` | 🟡 | 仅本页选中态高亮；**无全局注入** | G-ACCENT（= 3E，产品方另领） |
| 白天模式开关 | `night_mode` | ✅ | `DesktopAppShell.qml:46` 读 + `:200` 持久化 + 主题注入 | — |
| 启动恢复窗口位置 | `restore_window` | ✅ | `main.qml:36` 读 + `onClosing/onCompleted` 存取几何（钳进屏幕） | G-WIN |
| 默认页 | `landing_page` | ✅ | `DesktopAppShell.qml:240` 启动导航 / memo 开覆盖层 | G-LANDING |
| 磨砂强度 | `blur_strength` | 🧱 | **无消费者**；QML 无实时背景模糊（保真天花板） | G-BLUR |
| 显示欢迎动画 | `show_welcome` | ⬜ | **无消费者**：没有任何入场动画被它门控 | ui-only 未接 |
| 界面语言 zh/en/ja | `language_mode` | ⬜ | **无消费者**：存了语言但 UI 文案全静态、无翻译层 | G-I18N（= 3E，产品方另领） |
| 时间格式 12/24 | `time_format` | ⬜ | **无消费者**：没有任何页按它格式化时间（日历/统计/首页仍 24h 硬编码） | G-TIMEFMT |

### 追踪与应用（tracking）

| 控件 | KV 键 | 状态 | 真实消费者 / 取证 | 备注（缺口） |
|---|---|---|---|---|
| 追踪正在运行的应用 | `track_running` | 🟡 | `DesktopAppShell.qml:222`→`setReadFilters`：UI **软暂停**（读层不计 live）；**真停采集做不到** | G-TRACK（服务侧，契约阻断） |
| 游戏模式识别 | `game_mode` | ✅ | `setReadFilters` → `usage_stat_manager` 类别票门控 | — |
| 空闲超过（超时） | `idle_timeout` | 🧱 | **UI 内无消费者**；服务空闲阈值是编译期 `#define`，不读设置 | G-IDLE（服务侧，契约阻断） |
| 应用逐项显隐 | `hidden_apps` | ✅ | `DesktopAppShell.qml:214`→`setReadFilters`；聚合/趋势/专注/live 全链路排除 + 选单 | G-HIDEAPP |
| 自动分类 | `auto_classify` | ✅ | `setReadFilters` → 类别门控（关→「其他」、专注归零） | — |
| 合并同类窗口 | `merge_windows` | ✅ | `setReadFilters` → `effectiveGroupKey`（关→按 exe 细分） | — |

### 隐私与数据（privacy）

| 控件 | KV 键 | 状态 | 真实消费者 / 取证 | 备注（缺口） |
|---|---|---|---|---|
| 仅本地保存 | `privacy_local_only` | ⬜ | **无消费者**：架构本就无上传/网络路径，无「可禁」对象（安抚性开关） | 设计如此 |
| 隐藏敏感窗口标题 | `hide_titles` | 🟡 | `recordToVariantMap` 读出端把 windowTitle 换成类别；**但当前无任何 QML 展示 windowTitle**→效果不可见（边界硬化） | G-HIDETITLE |
| 匿名化分享图 | `anonymize_export` | ⬜ | **无消费者**：分享图渲染端匿名未接（忠实落点=回顾分享管线） | G-ANON |
| 存储占用条 / 缓存 / 记录数 | （只读） | ✅ | `usage_stat_manager.fileSizeBytes/recordCount` 真值 | G-STORAGE |
| 清理缓存 / 清空本地缓存 | （动作） | ✅ | 二次确认 + `clearUiCache`（仅清窗口几何派生缓存） | G-CLEAR（UI 私有部分） |
| 删除历史 | （动作） | 🧱 | 仅诚实说明：usage 追加-only（契约 D1），应用内不删 | G-CLEAR（需服务侧迁移工具） |
| 应用使用权限「就绪」 | （展示） | 🧱 | 静态诚实徽标；Windows 前台采集无授权 API 可探测 | G-PERM |
| 系统通知权限 | `notify_enabled` | ⬜ | **无消费者**：无通知子系统（无 QSystemTrayIcon / WinRT toast） | G-NOTIFY（需新建能力） |

### 备忘与番茄钟（memo）

| 控件 | KV 键 | 状态 | 真实消费者 / 取证 | 备注（缺口） |
|---|---|---|---|---|
| 按 N 打开备忘录 | `memo_hotkey_n` | ✅ | `DesktopAppShell.qml:257` Shortcut 门控 | G-MEMO |
| 自动保存笔迹和便签 | `memo_autosave` | ✅ | `MemoOverlay.qml:197` 门控连续自动存（关闭仍强存） | G-MEMO |
| 默认便签作者 | `memo_signature` | 🚫⬜ | **无消费者**：便签署名 UI 已停用（`StickyNote.qml:21`「位置让给成为待办」），存了也没人读 | 形同虚设 |
| 番茄钟 · 默认专注时长 | `pomodoro_duration` | ✅ | `PomodoroWidget.qml:33/92` `_load`(无存档)+`resetTimer` 读 | G-POMODORO（已接真引擎） |
| 番茄钟 · 默认专注标题 | `pomodoro_title` | ✅ | `PomodoroWidget.qml:56/92` | — |
| 番茄钟 · 结束庆祝动画 | `pomodoro_celebrate` | ✅ | `MemoOverlay.qml:1044` 门控完成弹层 | — |
| 快捷键 · 备忘 / 番茄（可改） | `memo_hotkey_key` / `pomodoro_hotkey_key` | ✅ | `DesktopAppShell.qml:232/233` 响应式重绑 Shortcut | — |
| 快捷键 · Del / Esc / Wheel（展示） | — | 🟡 | 仅静态展示；备忘内部键硬编码、不可改（本期范围外） | — |

### 导入导出（export）

| 控件 | 状态 | 取证 |
|---|---|---|
| 导出设置 JSON / 导入 / 复制摘要 | ✅ | `getAllSettings` / `readTextFile` / 剪贴板 |
| 当前数据概览（今日 / 切换次数 / 备忘页数） | ✅ | 真实只读派生 |
| 数据概览 · 番茄钟格 | 🟡 | 仍显「—」：番茄引擎不记录「完成次数」历史，无真值可填（诚实占位） |
| 恢复视觉默认 | ✅ | 重置 accent/blur/welcome |

---

## 二、未实现内容归纳（按性质分类）

### A. 仅持久化、无消费者 —— 补 UI 接线即可做（不碰契约、无平台障碍）
1. **时间格式 12/24（`time_format` / G-TIMEFMT）**：让首页 / 日历 / 统计的时间显示读 `time_format`
   走 `Qt.formatTime`。散落但纯前端，**最小可见快赢**。
2. **显示欢迎动画（`show_welcome`）**：启动入场动画按它门控（若无入场动画则需先有一个）。
3. **默认便签作者（`memo_signature`）🚫**：**特殊** —— 便签署名 UI 已废弃。两条路：(a) 复活署名展示并读
   `memo_signature`；(b) **从设置页移除该控件**（推荐，避免留一个永远无效的输入框）。
4. **界面语言全局生效（`language_mode` / G-I18N）**：`qsTr` + `QTranslator` 或共享 strings map。**大工程**，
   已与强调色全局一起列为 **3E（产品方另行领出）**。
5. **强调色全局生效（`accent_color` / G-ACCENT）**：把 `MemoryLakeStyle` 强调色改为可注入 + Shell 下发。
   **3E（产品方另行领出）**。

### B. 保真天花板（QML 限制，做不到「真」效果）
6. **磨砂强度（`blur_strength` / G-BLUR）**：QML 无实时 backdrop-filter。只能做玻璃叠色不透明度近似，或保留
   「视觉强度（占位）」标注。当前为占位。

### C. 无后端子系统（需新建能力）
7. **系统通知（`notify_enabled` / G-NOTIFY）**：需新建 `QSystemTrayIcon::showMessage` / WinRT toast 通知能力，
   之后才谈「通知权限」。当前仅存偏好。
8. **匿名分享图（`anonymize_export` / G-ANON）**：需在回顾分享图渲染管线（grabToImage 那条）替换显示名为
   类别 / 「应用 N」。当前仅存偏好。

### D. 契约 / 平台阻断（UI 内无法真正实现，需提案或服务侧工具）
9. **真正暂停采集 + 空闲超时（`track_running` 真停 / `idle_timeout` / G-TRACK·G-IDLE）**：服务是独立进程、
   靠磁盘契约通信（无 IPC，I1）。真停采集 / 改空闲阈值需「服务启动读 usage 目录配置文件」或新增控制通道 ——
   **须先提改契约提案**。UI 现仅软暂停近似 + 诚实标注。
10. **删除历史（G-CLEAR 真删）**：usage 为追加-only（契约 D1/I2）。应用内只清 UI 私有缓存；真删需「停服务 +
    迁移工具」。
11. **应用使用权限探测（G-PERM）**：Windows 前台采集无需 OS 授权，无权限 API 可查 → 恒「就绪」（诚实，按 A-PERM）。

### E. 产品方已决定本期不做
- **3E** = G-ACCENT（强调色全局）+ G-I18N（语言全局译文）。
- **G-ANON**（分享图渲染端匿名，见 C-8）。

---

## 三、建议优先级（不含已决定不做的 3E）

| 优先 | 项 | 性质 | 粗估 |
|---|---|---|---|
| P1 | 时间格式 12/24 接线（A-1） | 前端散落 | 小 |
| P1 | 默认便签作者：移除或复活（A-3） | 前端 | 小 |
| P2 | 显示欢迎动画门控（A-2） | 前端 | 小 |
| P2 | 数据概览番茄格：接「完成次数」需先给番茄引擎加完成日志 | 前端 + 引擎 | 中 |
| P3 | 系统通知能力（C-7） | 新建能力 | 中-大 |
| P3 | 匿名分享图（C-8 / G-ANON） | 跨页渲染 | 中 |
| 提案 | 真停采集 / 空闲 / 真删历史（D-9/10） | 契约修订 | 大 + 需评审 |
| 天花板 | 磨砂实时模糊（B-6） | 受限 | 不做 / 占位 |
| 设计如此 | 仅本地、权限就绪 | 安抚 / 诚实 | 不做 |

## 四、已实装（对照，避免重复排期）

整页暗玻璃重皮 · 5 暗玻璃控件 · 白天模式 · 默认页 · 窗口恢复 · 读层过滤（游戏/分类/合并/逐项显隐/标题边界脱敏/
软暂停）· 存储占用真值 · 数据概览真值 · 导入/导出/复制摘要/恢复默认 · 二次确认清缓存 · 番茄钟接真引擎（时长/标题/
庆祝）· 备忘 + 番茄自定义快捷键。
