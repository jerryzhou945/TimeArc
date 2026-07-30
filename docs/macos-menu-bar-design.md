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
| 首页 | ⌘1 | `selectedIndex = indexOfPage("memorylake")` |
| 日历 | ⌘2 | `indexOfPage("calendar")` |
| 统计 | ⌘3 | `indexOfPage("stats")` |
| 记忆湖 | ⌘4 | `indexOfPage("recap")` |
| 备忘黑板 (checkable) | ⇧⌘N | `memoOverlay.open = !memoOverlay.open` (`DesktopAppShell.qml:341`) |
| 番茄钟 | ⇧⌘P | `memoOverlay.togglePomodoro()` (`:350`) |
| 夜间模式 (checkable) | ⇧⌘D | `nightMode = !nightMode` — Shell persists `night_mode` |
| 界面语言 ▸ 中文 / English / 日本語 | — | radio group writing `language_mode` (`DesktopProfilePage.qml:1029` does the same) |
| 进入全屏幕 | (system key) | AppKit's own row — **still do not declare one**; the window carries `Qt.WindowFullscreenButtonHint`, so the OS contributes it (§4.1) and owns its key equivalent |
| — (no row) | ⌃⌘F | `Shortcut` in `main.qml`, macOS-gated Loader → `MacAppLifecycle::toggleFullScreen()` |

**On the row labels.** Take them from `navItems[i].title` (`DesktopAppShell.qml:139`),
never from the `page` key or the English `subtitle`. Two keys are historical and no
longer describe their page: `memorylake` is the row the sidebar titles 首页 (f881cdc
promoted Memory Lake to the home slot without renaming its key), and the row actually
titled 记忆湖 is keyed `recap`. Naming ⌘1/⌘4 after their keys is exactly how this menu
first shipped 记忆湖 on the home row and 月度记忆湖 on the 记忆湖 row.

**On ⌃⌘F.** The row above is the OS's, and current macOS gives it the system's
own key equivalent rather than the ⌃⌘F that older muscle memory expects. So the
key is bound separately, and deliberately *without* a menu row: a declared 进入全屏
would sit next to AppKit's 进入全屏幕 in the same menu — one command, two rows —
and §4.1 already rejects imitating OS-contributed rows. Both paths end in the
same `[NSWindow toggleFullScreen:]`. The binding lives on `MacAppLifecycle`
because that class already owns every full-screen transition here (it exits full
screen before a close, and deliberately does not exit it on restore); the toggle
no-ops while that deferred-close animation is in flight, and no-ops when the red
button has already destroyed the platform window — a key press must not put a
window back on the user's current Space. Qt swaps Ctrl/Meta on macOS, so the
sequence string is `"Ctrl+Meta+F"`; `QKeySequence` renders it `⌃⌘F`.

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
menus **by their titles**, and the two kinds of menu behave differently —
measured by dumping the live `NSMenu` tree under each combination:

| AppKit language | Our title | Edit | View / Help |
|---|---|---|---|
| en | 编辑 / 显示 / 帮助 | nothing | nothing |
| zh | 编辑 / 显示 / 帮助 | Chinese rows | Chinese rows |
| zh | Edit / View / Help | **adopted, renamed to 编辑**, Chinese rows | nothing |
| en | Edit / View / Help | English rows | English rows |

So View and Help match only AppKit's *own* localized name, while Edit also
answers to the canonical English one — and once adopted, AppKit **rewrites the
menu's title** into its language. A Chinese UI on an English system therefore
gets nothing anywhere: AppKit looks for `Edit` / `View` / `Help`.

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
  disappears mid-run. While the two disagree — one launch, and only if the
  stored language changed without this code running — the Edit menu is the
  visible symptom: AppKit adopts it anyway and renames it, so a single 编辑
  appears among File / View / Window / Help.
- **The startup title must already be right.** `MacMenuBar` is constructed
  before `shellLoader` has an item, so its `lang` fallback reads
  `language_mode` from `settingsRepository` rather than assuming a language.
  A literal `"zh"` there titled every menu in Chinese for the first fraction of
  a second of an English session, which was long enough for AppKit to adopt the
  mislabelled Edit menu and fill it in Chinese
  (`errors/20260729-142809-B-macos-menu-bar-startup-language-fallback.md`).
- **One writer, and English is the fallback.** The pin is driven only by the
  shell's persisted `languageMode` (startup from `main.cpp`, later changes via
  a `Connections` handler); the view's display fallback never reaches the
  native side. `normalizedMode()` returns **`en`** for anything unrecognized.
  Both rules exist for the same reason: while Chinese was the fallback it was
  an attractor — any stray or transient value re-pinned `zh`, so English and
  Japanese sessions decayed into a Chinese AppKit across relaunches while
  Chinese never did. Degrading to English is tolerable; degrading to a language
  the user did not choose is not.
- **Written only when it differs, then read back**, with one `qWarning` when
  AppKit's running language and the UI language disagree — that state is
  exactly when the OS rows cannot appear, and it is otherwise invisible.
- **Nothing is pinned during teardown.** `MacMenuLocalizer` latches
  `QCoreApplication::aboutToQuit` and ignores later calls. On quit the QML
  engine outlives `SettingsRepository`, so `DesktopAppShell.languageMode` — a
  *binding* on that context property — re-evaluates to its `"zh"` fallback and
  emits a change signal. Pinning that value wrote Chinese on the way out and
  poisoned the **next** launch, which is why every second start after choosing
  English or Japanese came up with AppKit in Chinese
  (`errors/20260729-160206-B-macos-menu-language-pinned-at-teardown.md`).
  Verification that ends the app with a signal cannot see this: only the real
  ⌘Q path runs the teardown.

Measured after the cleanup, two consecutive launches each:

| UI | AppKit | Menu bar | Rows AppKit added to Edit |
|---|---|---|---|
| en | `en` | File / Edit / View / Window / Help | AutoFill · Start Dictation… · Emoji & Symbols |
| zh | `zh_CN` | 文件 / 编辑 / 显示 / 窗口 / 帮助 | 自动填充 · 开始听写… · 表情与符号 |
| ja | `ja` | ファイル / 編集 / 表示 / ウインドウ / ヘルプ | 自動入力 · 音声入力を開始… · 絵文字と記号 |

AppKit contributes its rows once per menu-bar install, so the array holds
repeats; it hides all but one (`isHidden` is set on the duplicates), which is
why only one of each is ever drawn.
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

### 4.2 Where the UI language comes from

`SettingsRepository::languageMode()` is the only resolver, and every surface
calls it — both QML shells, the settings page, the macOS menu bar and the
status item. No caller carries a literal default any more.

- A stored `language_mode` naming a language TimeArc ships (`en` / `zh` / `ja`)
  wins.
- Otherwise — first run, or a value written by hand or by an older build — the
  system language decides, and the result is **persisted immediately**, so
  every later reader sees one agreed value.
- Matching walks the user's ordered language list and takes the first entry
  TimeArc ships: `en…` → `en`, `ja…` → `ja`, Simplified `zh…` → `zh`.
  Traditional Chinese (`zh-Hant`, `zh-TW`, `zh-HK`, `zh-MO`) is **not** a match
  — there is no Traditional catalog here — and neither is anything else, so a
  list of (`zh-Hant-TW`, `ja-JP`) still lands on Japanese. English is the
  fallback when nothing matches.

**On macOS the list must come from the global domain**
(`.GlobalPreferences`, read through `QSettings` because an organization name
containing a dot maps straight to a preferences domain). TimeArc pins
`AppleLanguages` in its *own* domain (§4.1), and the app domain sits above the
global one in the defaults chain — so `QLocale::system()` here would read our
own pin back and make the default self-referential. Measured: with the pin set
to `zh-Hans` and no stored language, the resolver still reads
`("en-CN", "zh-Hans-CN")` and answers `en`.

`QSettings` rather than CoreFoundation for one practical reason: this file is
compiled into targets that do not link the Cocoa frameworks (`timearc_db_smoke`),
and `src/CMakeLists.txt` is frozen.

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
