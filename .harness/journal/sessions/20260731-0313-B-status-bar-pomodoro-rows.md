# 20260731-0313-B-status-bar-pomodoro-rows

## Metadata

- Author: Claude Code (Opus 5) · Track **B (Feature)** · 2026-07-31 03:13 (local)
- Branch: `development/macos-support`
- Goal: 状态栏菜单加番茄钟三行——读数（可点，打开浮窗）、开始/继续/暂停、重置，三语。
- Related: 承接 `20260730-2358-B-pomodoro-cpp-wall-clock`（引擎移入 C++）。

## 1. Frozen files touched

None. 改动：`src/services/macos/macos_status_bar_icon.{h,cpp}`、`src/main.cpp`、
`qml/main.qml`、`qml/desktop/DesktopAppShell.qml`、
`tests/macos_status_bar_menu_static_test.py`。无新增源文件，故 `src/CMakeLists.txt` 未动。

## 2. Two-sided design

- **Service side:** 无。番茄钟状态自始至终是 UI 私有 KV，菜单不与 `time-arc-service`
  往来，不新增 IPC，服务端未重建。
- **UI side:** `MacStatusBarIcon::attach()` 多收一个 `PomodoroManager*`，三行直接调
  `startTimer/pauseTimer/resetTimer`——上一次的 C++ 化把状态从 QML 搬进了进程内的
  QObject，于是状态栏能像持 `TimerManager` 那样直接持指针，不必绕 QML 取值。
  唯一要过 QML 的是读数行的点击：浮窗长在窗口的 QML 树里。

## 3. 行为

| 状态 | 读数行 | 主命令 | 第三行 |
|---|---|---|---|
| 空闲 | `番茄钟 25:00` | `开始计时` | `重置计时` |
| 暂停 | `番茄钟 23:45` | `继续计时` | `重置计时` |
| 运行 | `番茄钟 12:34` | `暂停计时` | `重置计时` |

三态判定：`running` 直接读引擎；`paused` = 停表且 `remain != total`。三行在
zh/en/ja 各有词条，随 `language_mode` 在每次 `aboutToShow` 重取。

## 4. Decisions

- **读数为快照，不边开边刷。** AppKit 点击后先撤下菜单再派发动作，菜单停留期间没人
  盯着秒数；且引擎按墙钟锚点算，`aboutToShow` 那一次取值即便刚睡醒也是准的。
- **三行在菜单开着时状态若变，无需守卫。** `pauseTimer()` 非运行态直接返回、
  `startTimer()` 已运行直接返回、`resetTimer()` 任何态都成立——每一行对着过期菜单
  都是安全空操作。这是引擎入口自带的性质，不是这里补的。
- **`开始计时` 一行兼作 `继续计时`。** `startTimer()` 仅在 `remain <= 0` 时重填，
  暂停态调它就是原地继续，故两态共用一个动作、只换标签。
- **读数行先复原窗口再显示浮窗**（`showPomodoroFromTray` → `restoreFromTray()` +
  `menuShowPomodoro()`）。只翻 `shown` 会把浮窗标为可见于一个不在屏上的窗口。
  用 `show()` 而非 `toggle()`：点「番茄钟 12:34」的意思是「让我看见它」。
- **0 分 0 秒时主命令置灰**，与 `startTimer()` 自己的拒绝对齐，免得点了没反应。

## 5. 测试脚本清理

按要求删掉两处「禁字表」断言：
- `("TimerManager", "pauseTimer", "resumeTimer", "stopAndCommit", "startProject")`
  ——本就写错了对象（禁的是标识符子串，而番茄钟的 `pauseTimer` 同名），这次必然误伤；
- `("QProcess", "startBackgroundCollection", "stopBackgroundCollection")`
  ——凭空假设未来会有人加服务控制，属于替将来的代码立规矩，不是测当前行为。

留下的都是正向断言（接线、三态标签、三语分支、读数行的窗口复原）。
`menu.addAction(QStringLiteral("` 那条否定断言保留：它直接护着「三语」这个需求。

## 6. Verification

`build.py` 通过，无新警告（日志里三条 `built for newer version 15.0` 是既有的部署目标
警告，230 份历史日志里最早可追到 `20260705`）。应用起得来，`scan_qt_log.py --track B`
记录 0 条 L2，stderr 只有既有的 LaunchAgent 签名报错。
`tests/macos_status_bar_menu_static_test.py`（已扩充）、`pomodoro_global_static_test.py`、
`macos_fullscreen_close_static_test.py` 三项均通过。

**未跑：** 屏幕验收。状态栏菜单的自动化需要辅助功能授权，本环境没有
（`osascript` → `-1743`）。待人工走：空闲开菜单看 `番茄钟 25:00` → `开始计时` →
重开菜单确认变成 `暂停计时` 且读数在走 → `暂停计时` → 变 `继续计时` → `重置计时`
回到 25:00 → 点读数行确认窗口回来且浮窗打开 → 设置页切 English/日本語 各复看一遍。

## 7. Outcome

Code complete，屏幕验收待人工。
