# 20260730-1415-C-macos-restore-keeps-fullscreen

## Metadata

- Author: Claude Code (Opus 5)
- Track: **C (Debug)** — minimum change against a reported runtime bug.
- Date: 2026-07-30 14:15 (local)
- Session goal: 打开 TimeArc must not drag a full-screen window back to windowed.
- Branch: `development/macos-support`
- Related error report(s):
  `errors/20260730-061605-C-macos-restore-exits-fullscreen.md`

## 1. Frozen files touched

None. One function body in `src/services/macos/macos_app_lifecycle.mm`.

## 2. Root cause (short)

`MacAppLifecycle::restoreWindow()` called `QWindow::show()` on every
non-minimized window. On cocoa `show()` is `showNormal()` —
`setWindowStates(Qt::WindowNoState)` — and `QCocoaWindow::applyWindowState`
exits the current state before applying the new one, so a full-screen window
received `toggleFullScreen:`. Full derivation, including the Qt/libqcocoa
disassembly and the probe output, is in the error report §2–3.

## 3. Fix

```objc
  if (window_->visibility() == QWindow::Minimized) {
    window_->showNormal();
  } else if (!window_->isVisible()) {        // <- added
    window_->show();
  }
  window_->raise();
  window_->requestActivate();
```

One guard plus a comment naming the cocoa behavior at the call site. An
already-visible window now gets only `raise()` + `requestActivate()`, neither of
which touches window state. Nothing else in the file changed; the deferred-close
observer and the Dock-reopen delegate are untouched.

Why this is sufficient rather than the alternatives considered: the closed-window
case is the only one that needs a show, and a closed window is never full screen
because `beginWindowClose()` exits full screen before allowing the close. So no
state needs to be remembered and restored, and no native
`makeKeyAndOrderFront:` detour is needed.

## 4. Verification

The bug is only visible in a state no static test can reach — window visible
*and* full screen, then restored — so it was reproduced against a real `QWindow`
on this Qt build with a scratchpad probe carrying the pre- and post-fix bodies
verbatim:

| case                              | before                | after                 |
|-----------------------------------|-----------------------|-----------------------|
| visible + full screen, old body   | `FullScreen`          | `Windowed` (the bug)  |
| visible + full screen, new body   | `FullScreen`          | `FullScreen`          |
| closed (handle destroyed), new    | `Hidden`, handle=0    | `Windowed`, handle=1  |

The third row is the regression guard that matters: the `!isVisible()` branch
still recreates and shows a genuinely closed window, which is the case
`20260729-0155-B` added the `else` for.

Build clean, no new warnings. `tests/macos_fullscreen_close_static_test.py` and
`tests/macos_status_bar_menu_static_test.py` both still pass. A launch +
`scan_qt_log.py --track C` recorded 0 L2s (only the known unsigned-build
LaunchAgent codesigning line).

Not verified by me: the click itself. Driving a status-bar menu needs
Accessibility permission this session lacks (`osascript` → System Events
-1743), so the end-to-end 打开 TimeArc path awaits a human pass — full screen,
status item, 打开 TimeArc, window stays in its Space.

## 5. Scope held

No cleanups, no feature work, no rule edit. The prevention bullet for
`rules/02` §5 is named in the error report §5 and deferred: that file sits
exactly at the 100-line budget, so landing it means trimming it, which is a
drive-by this track forbids.

## Outcome

Fixed. `打开 TimeArc` now raises and focuses a visible window without changing
its state, and still recreates a closed one.
