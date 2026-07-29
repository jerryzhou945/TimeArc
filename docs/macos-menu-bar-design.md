# macOS Menu Bar — Command Design

Scope: the **application menu bar** (the strip at the top of the screen owned
by the frontmost app: `TimeArc / 文件 / 编辑 / 显示 / 窗口 / 帮助`).

Not in scope: the **status item** (`NSStatusItem`, the `T` glyph on the right
side of the menu bar). That surface already ships — 打开 TimeArc / 开机自启
(disabled) / 退出 TimeArc — see
`.harness/journal/sessions/20260729-0229-B-macos-status-bar-menu.md`. §7 below
states how the two surfaces divide responsibility.

macOS is the only platform affected. Windows/Linux keep the self-drawn chrome
(`qml/desktop/components/WindowChrome.qml`) and the `Qt.labs.platform` tray;
`main.qml:16 macSidebarChrome` is the existing gate.

## 1. Why the app needs one at all

TimeArc on macOS currently ships **no** menu bar of its own, so the system
draws the bare fallback (app name + Services/Hide/Quit, an empty 编辑, a 窗口
and 帮助 built from defaults). Three concrete consequences:

1. **⌘, does nothing.** Settings is reachable only by clicking the sidebar.
2. **编辑 is empty**, which on macOS is the standard place users look for
   撤销/剪切/粘贴 while typing in a 便签 or the settings search box.
3. Since `66f1f7b`/`10fe8f5`, the red button closes the window but leaves the
   process running. With no window, the menu bar is the *only* on-screen
   surface the app owns besides the status item — and today it is empty.

Every command below binds to behavior that already exists in the codebase. No
command in this design requires new product capability, with the two explicit
exceptions marked **NEW** (About panel, Help target).

## 2. Command inventory

Legend: **Binding** names the existing call site. Enablement rules are in §3.

### 2.1 TimeArc (application menu)

| Command | Key | Binding |
|---|---|---|
| ~~关于 TimeArc~~ | — | **Not shipped.** Would need a new about panel; skipped as new product surface, so macOS shows no About row |
| 设置… | ⌘, | `selectedIndex = indexOfPage("settings")`. `PreferencesRole` |
| 服务 / 隐藏 TimeArc ⌘H / 隐藏其他 ⌥⌘H / 全部显示 | — | System-provided, do not declare |
| 退出 TimeArc | ⌘Q | `appWindow.quitFromTray()` (`main.qml:77`). `QuitRole` |

开机自启 is deliberately **not** here. It is a preference, it lives on the
settings page, and its status-item row is still a disabled placeholder
(`registerMacLaunchAgent()` has no query/unregister path).

### 2.2 文件 File

| Command | Key | Binding |
|---|---|---|
| 导出统计报告… | ⇧⌘E | `DesktopStatsPage.doExport()` (`DesktopStatsPage.qml:589`) — exports the range currently shown |
| 导入设置… | — | `DesktopProfilePage` `settingsFileDialog.open()` (`:578`) |
| 导出设置… | — | `DesktopProfilePage.doExport()` (`:438`) |
| 备份数据库… | — | `DesktopProfilePage.doBackupDatabase()` (`:513`) |
| 关闭窗口 | ⌘W | `appWindow.close()` — the existing macOS path: window closes, process and sampling continue |

The three settings-file rows are the only case where a menu command reaches
into a page that may not be loaded. Rather than silently loading it, the
command **navigates to 设置 first, then opens the dialog** — the user ends up
looking at the page whose state they just changed. 导出统计报告 does the
opposite (see §3): it stays disabled off the stats page, because "export the
current range" has no meaning until a range is on screen.

### 2.3 编辑 Edit

撤销 ⌘Z · 重做 ⇧⌘Z · 剪切 ⌘X · 复制 ⌘C · 粘贴 ⌘V · 删除 · 全选 ⌘A

`Qt.labs.platform.MenuItem` has no Cut/Copy/Paste roles, so these forward to
the focused editor:

```qml
readonly property Item ed: appWindow.activeFocusItem
enabled: ed && ("copy" in ed) && ed.selectedText.length > 0   // 复制/剪切
onTriggered: ed.copy()
```

with `canUndo` / `canRedo` / `canPaste` driving the other rows. This is
required, not cosmetic: TimeArc has real text entry in 便签, memo signatures,
and the settings search field.

### 2.4 显示 View

| Command | Key | Binding |
|---|---|---|
| 记忆湖 (首页) | ⌘1 | `selectedIndex = indexOfPage("memorylake")` |
| 日历 | ⌘2 | `indexOfPage("calendar")` |
| 统计 | ⌘3 | `indexOfPage("stats")` |
| 月度记忆湖 | ⌘4 | `indexOfPage("recap")` |
| 备忘黑板 (checkable) | ⇧⌘N | `memoOverlay.open = !memoOverlay.open` (`DesktopAppShell.qml:341`) |
| 番茄钟 | ⇧⌘P | `memoOverlay.togglePomodoro()` (`:350`) |
| 夜间模式 (checkable) | ⇧⌘D | `nightMode = !nightMode` — Shell persists `night_mode` |
| 界面语言 ▸ 中文 / English / 日本語 | — | radio group writing `language_mode` (`DesktopProfilePage.qml:1029` does the same) |
| 进入全屏 | ⌃⌘F | System-provided; **do not declare** — Qt injects it because the window carries `Qt.WindowFullscreenButtonHint` |

设置 is intentionally absent from 显示: it is ⌘, in the app menu, per platform
convention, and listing it twice invites two different mental models of where
it lives.

**On the bare `N` / `P` hotkeys.** `DesktopAppShell.qml:335-353` binds
single-letter shortcuts for 备忘/番茄, user-rebindable in settings. Those stay
exactly as they are. The menu adds ⇧⌘N / ⇧⌘P as *additional* equivalents,
because a bare letter cannot be a menu key equivalent on macOS (the menu would
swallow the keystroke before a focused text field ever sees it — the very
problem `Keys.onShortcutOverride` was added to solve). If the user rebinds the
letter in settings, the menu's ⇧⌘ equivalent is unaffected.

### 2.5 窗口 Window

| Command | Key | Binding |
|---|---|---|
| 最小化 | ⌘M | `appWindow.showMinimized()` |
| 缩放 | — | Same path as the sidebar double-click zoom (`7b35dd0`) |
| 前置全部窗口 | — | System-provided |
| ✓ TimeArc | — | `appWindow.restoreFromTray()` (`main.qml:64`); checkmark when a window exists |

The last row is what makes the closed-window state recoverable from the menu
bar itself, not only from the Dock icon or the status item.

### 2.6 帮助 Help

| Command | Key | Binding |
|---|---|---|
| ~~TimeArc 使用指南~~ | — | **Not shipped.** No help content and no decided URL; an item that opens nothing is worse than no item |
| 在 Finder 中显示数据文件夹 | — | `Qt.openUrlExternally()` on `databaseManager.currentDatabaseLocationDir()` |

The Finder row is a privacy affordance as much as a support one: TimeArc's
whole claim is that it records time context locally, and "show me exactly what
is on disk" should be one click, never a support-forum instruction.

The system adds the Help search field automatically.

## 3. Enablement rules

The menu bar is alive in states the window is not. Three rules cover it:

| State | Rule |
|---|---|
| **No window** (red-button close; process alive) | 设置…, ⌘1–⌘4, 备忘黑板, 番茄钟, 夜间模式, 语言, 最小化, 缩放, 关闭窗口, all 文件 rows → **disabled**. Alive: 关于, 退出, ✓ TimeArc, 帮助. Alternative considered and rejected: auto-restoring the window on any command — it turns a mis-click into an unexpected window on the user's current Space. |
| **备忘黑板 open** (`memoOpen`) | It is a full-screen modal that hides the traffic lights (`main.qml:106`). Navigation rows (⌘1–⌘4) and 关闭窗口 → **disabled**; 备忘黑板 stays enabled (it is the way out); 番茄钟 stays enabled. Mirrors the existing `memoLocked` gate on the letter hotkeys. |
| **Page-scoped** | 导出统计报告 enabled only while `selectedPage === "stats" && !showingTimerPage`. |

## 4. Localization

The window UI ships zh / en / ja through
`qml/desktop/components/I18n.js`. A Chinese-only menu bar would reintroduce
exactly the defect fixed in the status-item session. Because this design puts
the menu bar in QML (§5), it can call `I18n.js` directly — no second string
table, unlike `macos_status_bar_icon.cpp`.

**As implemented**, the menu strings live in their own `menuEn` / `menuJa`
tables in `I18n.js`, read through a new `I18n.menu(lang, source)` with the same
fallback chain as `t()` (ja → en → the Chinese source). They are separate from
the main `en` / `ja` tables on purpose: words like 复制 and 番茄钟 already exist
there, and filling their gaps would have changed how Windows and Linux render
those strings in Japanese. A macOS-only change stays macOS-only.

Qt's Cocoa platform plugin owns the standard application-menu rows (About,
Preferences, Services, Hide, Show All, Quit). Its `mergeText()` replaces the
declared text of `PreferencesRole` / `QuitRole` items with strings from Qt
Base's `MAC_APPLICATION_MENU` catalog. `MacMenuLocalizer` installs that catalog
for TimeArc's current `language_mode`, so both Qt-generated rows and the custom
QML menus switch together. The macOS package deploys only `zh_CN` and `ja`;
English is Qt's source-language fallback.

### 4.1 The rows AppKit contributes itself

macOS adds rows to menus it recognizes: 自动填充 / 开始听写… / 表情与符号 to the
Edit menu, 进入全屏幕 to View, and the search field to Help. It finds those
menus **by comparing their titles against its own localization**, at the moment
the menu is first opened. A Chinese UI on an English system therefore gets
nothing: AppKit looks for `Edit` / `View` / `Help` and sees 编辑 / 显示 / 帮助.

This produced a confusing bug report — commands "lost" in Chinese, appearing
after a switch to English, then *staying* after switching back, but gone again
after a relaunch. All three halves follow from the above: the match succeeds
only while the titles are English, AppKit never retracts what it has added, and
a relaunch rebuilds the menus in Chinese.

`MacMenuLocalizer` therefore pins `AppleLanguages` in TimeArc's own preference
domain to the current `language_mode` — the same mechanism as System Settings ›
General › Language & Region › Applications. AppKit then runs in the UI language,
recognizes the titles we actually draw, and contributes its rows in that
language. Consequences worth knowing:

- **Bound at process start.** A language change takes effect on the next launch;
  rows already contributed persist for the rest of the session, so nothing
  disappears mid-run.
- **Process-wide.** `QLocale::system()` and native panels (`NSOpenPanel`
  buttons, etc.) follow the same override — consistent with the UI language,
  but wider than the menu bar.
- **It overwrites** any per-app language the user set in System Settings. The
  in-app 界面语言 is the single source of truth.

Rejected alternatives: renaming titles to English around each open (AppKit
re-adds its rows on every open **without deduplicating** — measured 7 copies of
`Start Dictation…` and 13 of `Emoji & Symbols` after a handful of cycles), and
declaring our own equivalents (they are the OS's rows, not ours to imitate).

`NSApp.setHelpMenu:` / `setWindowsMenu:` do work regardless of title and were
measured to, but are unnecessary once the override is in place — and
`setWindowsMenu:` would duplicate the 窗口 › TimeArc row that exists precisely
to reopen a *closed* window, which AppKit's window list cannot do.

## 5. Implementation approach

**Recommended: `Qt.labs.platform.MenuBar` in a new `qml/desktop/MacMenuBar.qml`**,
instantiated from `main.qml` under `macSidebarChrome`, with `window: appWindow`
and commands routed through `shellLoader.item`.

Rationale: `Qt.labs.platform` is already a proven dependency here
(`qml/desktop/memorylake/NotifierTray.qml` uses its `SystemTrayIcon`/`Menu`),
it produces a real `NSMenu`, `MenuItem.role` gives About/Preferences/Quit the
app-menu merge for free, and — decisively — every command target above is QML
shell state. The C++ alternative (a parentless `QMenuBar`; `QtWidgets` is
already linked, `CMakeLists.txt:19`) would need ~25 new `invokeMethod` hops
across the C++/QML seam and its own copy of the string table.

**The one risk, now settled.** `Qt.labs.platform.MenuBar` binds to a `window`,
and TimeArc's macOS close path destroys the *platform* window
(`macos_app_lifecycle.mm`) while the QML `ApplicationWindow` object survives.
Measured with `QT_LOGGING_RULES="qt.qpa.menus.debug=true"` across a
close → reopen cycle: the same `QCocoaMenuBar` instance survives, every item
keeps being validated (against `QCocoaApplicationDelegate` while no window
exists), and on reopen the bar re-attaches to the newly created
`QCocoaWindow`. `ApplicationWindow.visible` reads `false` throughout the closed
period, so §3's first row grays out exactly as specified. The C++ `QMenuBar`
fallback was not needed.

Also: `qml/CMakeLists.txt` needs the new file (`rules/05-build-system.md`).
Root `CMakeLists.txt` is untouched — see §8.

Two implementation details worth keeping:

- **Check state is pushed on `aboutToShow`, never bound.** A checkable
  `Qt.labs.platform.MenuItem` writes its own `checked` when activated, which
  would destroy a binding permanently and freeze the checkmark. `syncViewChecks()`
  / `syncWindowChecks()` push it as the menu opens — the same reason
  `macos_status_bar_icon.cpp` relabels its rows in `QMenu::aboutToShow`.
  Enablement stays declarative; Qt never writes `enabled`.
- **Non-merged items declare `NoRole`.** The default `TextHeuristicRole` guesses
  from the leading word (settings / options / quit …) whether an item belongs in
  the app menu, and several English labels here start with such words.
- **The injected properties are `hostWindow` / `hostShell`, not `appWindow` /
  `shell`.** Writing `MacMenuBar { appWindow: appWindow }` binds the property to
  *itself*: a QML binding resolves the right-hand side against the scope object
  first, so `appWindow` finds the menu bar's own property rather than main.qml's
  window id. It stays null, silently — no binding loop, no warning — and every
  command gated on a live window greys out. Cost one round trip to find
  (`errors/20260728-201546-B-macos-menu-bar-self-bound-window.md`); the static
  test now pins the names.

Test: `tests/macos_menu_bar_static_test.py`, in the shape of the existing
`macos_status_bar_menu_static_test.py` — every command present, the
`macSidebarChrome` gate so no menu bar leaks onto Windows/Linux, the §3
enablement expressions, the three-language tables, no bound `checked`, and no
bare single-letter key equivalent.

## 6. Deliberate omissions

- **暂停后台采集 / any service control.** Pausing the sampler means the UI
  signalling the service. `CHARTER` §2 forbids IPC; it would need a control
  file added to the disk contract, i.e. a change proposal first. Same reason
  the status item has no such row.
- **开始计时 / 结束并记录.** Timer control needs a project choice, which lives
  in the window. Removed from the status item at the user's request last
  session for that reason; re-adding it to the menu bar would contradict that.
- **Today's total as a menu row.** A glanceable summary belongs in the status
  item (as a custom `NSView` item), not in a command menu.
- **A 视图 zoom / text-size group.** No zoom level exists in the app.
- **Recent files.** TimeArc has no document model.

## 7. Division of labour with the status item

| Surface | Answers |
|---|---|
| **Status item** (`T` glyph) | "The window is gone — get me back in, or out." Navigation + lifecycle only: 打开 / 自启 / 退出. Visible whether or not TimeArc is frontmost. |
| **Menu bar** | "TimeArc is frontmost — what can I do to it?" The full command surface: pages, memo/pomodoro, theme, language, files, edit, window. |

Overlap is limited to 退出 and "bring the window back", which is correct:
both are the commands a user reaches for from either place.

## 8. Harness notes

- Track **B**. Frozen files touched: **none**. The build change is
  `qml/CMakeLists.txt`, which is not frozen.
- Shipped as `qml/desktop/MacMenuBar.qml`, loaded from `qml/main.qml` behind
  `active: appWindow.macSidebarChrome`; command entry points
  (`menuNavigateTo`, `menuToggleMemo`, `menuTogglePomodoro`,
  `menuToggleNightMode`, `menuSetLanguage`, `menuRunSettingsAction`,
  `menuExportStatsReport`) added to `DesktopAppShell.qml`, plus
  `openImportDialog()` on `DesktopProfilePage.qml` (a dialog id cannot be
  reached from outside its file). Those functions have no caller off macOS.
- Pre-existing drift, unrelated to this design and untouched by it:
  `preflight.py --track B` reports `DRIFT: CMakeLists.txt: hash mismatch`,
  left over from `d2e1af7` (macOS bundle ID) editing a frozen file. It must be
  re-baselined or change-proposed before the next commit that builds.
