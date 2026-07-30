# macOS 备忘黑板上的交通灯

## 目标

备忘黑板（备忘覆盖层）打开时，让 macOS 原生交通灯继续显示并可用，而不是像
`docs/macos-sidebar-window-controls-report.md` 当初那样「打开黑板就藏起窗口控制」。

## 结论：不需要做层级

AppKit 把三颗按钮画在 `NSWindow` 的标题栏视图里，该视图本就叠在 Qt 内容视图之上
（侧栏一直依赖这一点，见 `DesktopAppShell.qml` 「原生交通灯直接覆盖在其中」）。
所以黑板只需要**停止主动隐藏**，无需任何 z 序改动。

## 范围与改动

- `qml/main.qml`：`macTrafficLightsController.setVisible(true)` 改为无条件调用，
  删掉由 `memoOpen` 驱动的 `onMemoOpenChanged`。
- `qml/desktop/memorylake/MemoOverlay.qml`：新增 `macSidebarChrome` /
  `macTrafficLightInset`（88px，沿用侧栏与自绘标题栏既有让位口径），保存状态胶囊在
  macOS 下右移让开按钮带；其他平台维持 24px。
- `qml/desktop/MacMenuBar.qml`：「关闭窗口」(⌘W) 不再随黑板置灰——红灯既然可点，
  键鼠不能各说一套。最小化/缩放本来就没有置灰。
- 存盘：红灯现在随时可点，`MemoOverlay.flushPendingSave()` 由
  `DesktopAppShell.flushMemoDoc()` 经 `ApplicationWindow.onClosing` 调用，
  把 600ms 防抖里的最后一笔强制落地；`_loaded` 守卫避免没开过黑板的会话用空白文档
  覆盖用户存档。
- `qml/desktop/DesktopAppShell.qml`：侧栏的原生挪窗/双击缩放手势层改为
  `enabled: root.macSidebarChrome && !root.memoOpen`。**这是实测暴露的 bug**：
  `DragHandler`/`TapHandler` 属于指针处理器，Qt 的事件分发会先做一轮「只给 handler」的
  遍历，覆盖命中点下**所有** item（不看谁在上面），黑板自己的 MouseArea 因此挡不住它们；
  DragHandler 越过 4px 阈值后还能把独占抓取从 MouseArea 抢走。表现：在黑板左侧原侧栏
  区域横拖变成挪窗口、双击变成缩放，画笔/框选拿不到事件。普通 MouseArea 型导航不受影响
  （item 分发遇到覆盖层就停），所以只有手势会漏。
- `.harness/rules/04-ui-conventions.md` §8 补上这条约定。

## 验证

- `python3 .harness/tools/preflight.py --track B`：干净基线。
- `cmake --build build`：改动前后均干净，无新告警。
- `tests/macos_memo_traffic_lights_static_test.py` 新增并通过；macOS/桌面既有静态用例
  与 CTest 两个 smoke 全过。
- 应用可启动，日志无新增 QML 告警（仅既有的窗口几何 binding.removal 与未签名开发
  构建的 LaunchAgent 报错）。
- **未完成**：截图核验。当前 shell 未获 Screen Recording / Automation 授权，
  `screencapture -l` 与 `osascript` 均被 TCC 拒绝，无法自动开黑板取图。

## 已知限制

- 黑板左上角约「逻辑 16–107 × 5–37」板坐标被按钮遮挡，落在那里的墨迹/便签/文字点不到。
- 黑板顶部仍不能拖窗、不能双击缩放（画布优先），但常显的交通灯会让用户以为可以。
