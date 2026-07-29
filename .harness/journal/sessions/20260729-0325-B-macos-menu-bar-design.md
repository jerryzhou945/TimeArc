# 20260729-0325-B-macos-menu-bar-design

## Metadata

- Author: Claude Code (Opus 5)
- Track: **B (Feature)** — new macOS-only command surface.
- Date: 2026-07-29 03:25 (local)
- Session goal: design **and implement** the macOS application menu bar.
- Branch: `development/macos-support`
- Predecessor: `20260729-0229-B-macos-status-bar-menu.md`

## 1. Frozen files touched

None. New: `docs/macos-menu-bar-design.md`, `qml/desktop/MacMenuBar.qml`,
`tests/macos_menu_bar_static_test.py`. Modified: `qml/main.qml`,
`DesktopAppShell.qml`, `DesktopProfilePage.qml`, `I18n.js`, `qml/CMakeLists.txt`,
`README.md` — none frozen.

## 2. Motivation

macOS builds shipped no application menu bar, so the system drew the bare
fallback: ⌘, dead, 编辑 empty while the app has real text entry, and since
`66f1f7b` the red button leaves the process running with no window — where the
menu bar is one of only two surfaces the app owns.

## 3. Impact on the other process

| Side     | Effect |
|----------|--------|
| Producer | None. No `src/service/` change, no sampling/schema/control-file change; §8 rejects every command that would have needed one. |
| Consumer | UI-only. Writes only `language_mode` / `night_mode`, through the same paths the settings page uses. |

## 4. Migration / 5. Rollback

No on-disk impact; rollback is a revert of the QML diff plus deleting the file.

## 6. Test plan

`tests/macos_menu_bar_static_test.py` (new) passes; `macos_status_bar_menu` and
`macos_fullscreen_close` still pass. Runtime evidence came from
`QT_LOGGING_RULES="qt.qpa.menus.debug=true"` plus QML probes, not from looking —
Accessibility is unauthorized here, so no menu can be driven or screenshotted:
five menus insert into one `QCocoaMenuBar`, every command reaches AppKit with
its key equivalent (⌘, ⌘Q ⇧⌘E ⌘W ⌘Z ⇧⌘Z ⌘X ⌘C ⌘V ⌘A ⌘1–⌘4 ⇧⌘N ⇧⌘P ⌥⌘D ⌘M),
设置…/退出 merge into the app menu, and with the window open the gates and three
sampled `MenuItem.enabled` values read true (the check missing below).
All three languages ran from the real `language_mode` setting, restored after
(zh 备忘黑板/夜间模式, ja メモボード/ナイトモード, en Memo Board/Night Mode).
Close → reopen: §7. Not verified: clicking a row and reading a checkmark needs
Accessibility — human pass.

## 7. Design

Full design: `docs/macos-menu-bar-design.md`. Five declared menus (文件 / 编辑 /
显示 / 窗口 / 帮助) plus 设置… ⌘, and 退出 TimeArc ⌘Q merged into the app menu by
role, built with `Qt.labs.platform.MenuBar` in QML rather than a C++ `QMenuBar`:
command targets are QML shell state, and QML reaches `I18n.js` directly.

**The open risk is settled.** `qt.qpa.menus` logging across a close → reopen
cycle shows the same `QCocoaMenuBar` surviving the platform-window destroy,
items validating against `QCocoaApplicationDelegate` while no window exists, and
the bar re-attaching to the new `QCocoaWindow`. No C++ fallback needed.

Menu strings sit in new `menuEn`/`menuJa` tables behind `I18n.menu()` rather
than the shared `en`/`ja` tables: 复制 and 番茄钟 already live there with gaps in
ja, and filling them would have changed Japanese rendering on Windows/Linux.
Check state is pushed in `aboutToShow`, not bound — an activated
`Qt.labs.platform.MenuItem` writes its own `checked` and would break the
binding. Non-merged items declare `NoRole`: `TextHeuristicRole` guesses
app-menu membership from the leading English word.

## 8. Deliberate omissions

Doc §6: no service control (CHARTER §2 forbids IPC — 暂停后台采集 would need a
control file in the disk contract), no timer rows (project choice lives in the
window), no today-total row (status item, as a custom NSView), no zoom group, no
recent files. Unshipped as new product surface: 关于 TimeArc, 使用指南.

## Outcome

Shipped, after one defect the user caught: most commands opened greyed out.
`MacMenuBar { appWindow: appWindow }` bound the property to itself (a QML binding
resolves the RHS against the scope object first), so it stayed null and every
window-gated command disabled — silently, no warning. Renamed to
`hostWindow` / `hostShell`, pinned by the static test and journaled as
`errors/20260728-201546-B-macos-menu-bar-self-bound-window.md`; my own probe had
measured only the closed-window state, where false was the right answer.
Build clean, no new warnings. The only `scan_qt_log.py --track B` finding is the
known unsigned-build LaunchAgent codesigning failure already in
`state/open-issues.md` (`errors/20260728-195305-B-qt-warning-19f33ebed5.md`);
both new rows pushed `INDEX.md` past budget, so the oldest concrete rows were
trimmed under the existing omission row (rolling-index convention).
Windows/Linux are untouched by construction: the menu bar sits behind
`active: appWindow.macSidebarChrome`, so no `Qt.labs.platform.MenuBar` exists
there, and the static test forbids the shared shell from instantiating it.

Still open, not caused here: `DRIFT: CMakeLists.txt: hash mismatch` from
`d2e1af7` (macOS bundle ID) editing a frozen file — needs a re-baseline or
change proposal before the next committed build. `macos_build_script` and
`desktop_ux` static tests also fail on a clean checkout — pre-existing.
