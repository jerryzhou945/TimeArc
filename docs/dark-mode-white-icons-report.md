# 黑夜模式导航图标切换报告

## 目标

让桌面侧边栏导航在黑夜模式下使用白色 SVG 图标，并将「备忘」入口从
`chat.svg` 切换为新的 `note.svg` / `note_white.svg`。

## 范围

- 修改 `qml/desktop/DesktopAppShell.qml`：
  - 首页、日历、统计、设置、备忘增加 `nightIcon`。
  - `Image.source` 在 `nightMode` 为真时优先使用白色图标。
  - 备忘入口日间图标改为 `note.svg`，夜间图标改为 `note_white.svg`。
- 修改 `resources/CMakeLists.txt`：
  - 把新增的 `*_white.svg` 与 `note*.svg` 纳入 Qt resource 列表。
- 修正新增白色 SVG：
  - 将 `stroke="currentColor"` 固定为 `stroke="#FFFFFF"`，避免 QML `Image`
    渲染时仍按默认黑色显示。

## 不在本次范围

- 不处理移动端。
- 不改月度回顾 `recap.svg`，因为当前没有对应 `recap_white.svg`。
- 不改站点图标和应用采集图标。

## 验证

- `git diff --check`
- `.harness/tools/harness_check.py`
- `.harness/tools/build.py`

## 回退

若该改动合并后需要回退，直接 revert 本次图标切换 commit 即可。回退后侧边栏会恢复
原始单一图标源，备忘入口也会回到 `chat.svg`。
