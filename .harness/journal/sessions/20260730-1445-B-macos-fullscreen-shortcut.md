# 20260730-1445-B-macos-fullscreen-shortcut

## Metadata

- Author: Claude Code (Opus 5)
- Track: **B (Feature)** — new capability, macOS only.
- Date: 2026-07-30 14:45 (local)
- Session goal: ⌃⌘F toggles full screen on macOS, with AppKit's own
  进入全屏幕 row and every existing shortcut untouched.
- Branch: `development/macos-support`

## 1. Frozen files touched

None. No CMake edit — both changed native files already build.

## 2. Two-sided design

- **Service side:** nothing. No disk contract, no `usage_config.json` key, no
  sampling, no IPC. `time-arc-service` is not rebuilt or affected.
- **UI side:** `qml/main.qml` gains a macOS-gated `Loader` holding one
  `Shortcut { sequences: ["Ctrl+Meta+F"] }` that calls a new
  `MacAppLifecycle::toggleFullScreen()`. Windows/Linux/Android instantiate no
  new object (`active: appWindow.macSidebarChrome && macAppLifecycle`).

## 3. Why no menu row

`docs/macos-menu-bar-design.md` §2.4 assumed ⌃⌘F came free with AppKit's
injected 进入全屏幕 row. The row is there, but current macOS gives it the system's
own key equivalent, so ⌃⌘F did nothing. Declaring our own row would put two
rows for one command in the same 显示 menu, which §4.1 already rejects — so the
key is bound without a row, and AppKit's row keeps its key.

Native `[NSWindow toggleFullScreen:]` rather than
`appWindow.visibility = Window.FullScreen`: `MacAppLifecycle` already owns every
full-screen transition (`beginWindowClose()` exits it, `restoreWindow()` was
fixed this morning to *not* exit it), and AppKit reads its own `styleMask`, so a
second ⌃⌘F during the ~1s animation cannot act on stale Qt-side state.

Two guards in `toggleFullScreen()`: no-op while the deferred-close observer is
running (re-entering mid-animation is
`errors/20260728-150542-C-macos-fullscreen-close-black-screen.md`), and no-op
when the platform window is gone (a key press must not put a window back on the
user's current Space — design doc §3).

## 4. Files

- `src/services/macos/macos_app_lifecycle.h` — `Q_INVOKABLE void toggleFullScreen()`.
- `src/services/macos/macos_app_lifecycle.mm` — implementation + the two guards.
- `qml/main.qml` — macOS-gated `Loader { Item { Shortcut } }`. The `Item`
  wrapper keeps the shortcut's `WindowShortcut` context on the window's visual
  parent chain.
- `docs/macos-menu-bar-design.md` §2.4, `README.md` — corrected claim + feature note.
- `I18n.js` untouched: no new user-visible string, so zh/en/ja need nothing.

## 5. Verification

`build.py`: success (`build-logs/20260730-144612-build.log`).

Two out-of-tree probes (scratchpad), because sending a real ⌃⌘F to the running
app needs Accessibility/Apple-Events permission this shell does not have:

1. QML-shape probe — same `Loader { Item { Shortcut } }`, driven through
   `QTest::keyClick` → `QShortcutMap`:
   ```
   sequence native text:   "⌃⌘F"      <- what the user presses
   sequence portable text: "Meta+Ctrl+F"
   fired: 1 (expected 1)              <- ⌃⌘F matched; plain ⌘F did not
   ```
2. Native probe — compiles the real `macos_app_lifecycle.mm`, exposes it as
   `macAppLifecycle`, and reads `NSWindowStyleMaskFullScreen`:
   ```
   before      : fullScreen = false
   after ⌃⌘F   : fullScreen = true
   after ⌃⌘F #2: fullScreen = false
   ```

App launched from the new build: loads clean, no QML warning.
`scan_qt_log.py` consumed a log backlog reaching back to 2026-07-05 and filed 5
L2 reports — the unsigned-dev-build LaunchAgent codesigning warning and three
AppKit-language-pin warnings from earlier sessions. None originate from this
change; this session's only log line is the LaunchAgent one.

`harness_check.py`: clean.

Manual smoke path left for the user (needs real key presses at the window):
launch app → ⌃⌘F enters full screen → ⌃⌘F exits → 显示 menu still shows exactly
one 进入全屏幕 row and its system key still works.
