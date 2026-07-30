# Error Report - macos-restore-exits-fullscreen

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-restore-exits-fullscreen
- Recorded: 2026-07-30T06:16:05Z
- Session: `20260730-1415-C-macos-restore-keeps-fullscreen`
- Platform: macOS (darwin 24.6.0), Qt 6.11.1 (homebrew), cocoa plugin
- Tooling: Claude Code (Opus 5)

## 1. What happened

打开 TimeArc in the macOS status menu dropped a full-screen window back to
windowed. Reported by the user: the row is supposed to raise and focus the
window, but it also animated the window out of its full-screen Space.

## 2. Evidence

Repro: launch on macOS, put the window in full screen (green button), click the
status item, choose 打开 TimeArc → the window leaves full screen.

Reproduced out-of-tree with a probe that mirrors `restoreWindow()` against a
real `QWindow` on this Qt build:

```
before      : visibility=FullScreen isVisible=1
after OLD   : visibility=Windowed   isVisible=1     <- the bug
after NEW   : visibility=FullScreen isVisible=1     <- with the guard
```

Static evidence, from disassembling the installed Qt rather than assuming:

```
QWindow::show()  (QtGui @ 0xeafd4)
  mov x1, #0x0 ; bl QWindow::setWindowStates(QFlags<Qt::WindowState>)  // WindowNoState
QCocoaWindow::applyWindowState  (libqcocoa @ 0x40374)
  cmp w21, #0x4 ; b.eq 0x40394 -> objc_msgSend$toggleFullScreen:       // current == FullScreen
```

`show()` only diverges from `showNormal()` when the platform's
`defaultWindowState()` is Maximized/FullScreen; cocoa returns WindowNoState, so
on macOS the two are the same two calls.

## 3. Root cause

- Immediate cause: `MacAppLifecycle::restoreWindow()` called
  `window_->show()` for every non-minimized window. On cocoa that is
  `showNormal()`, i.e. `setWindowStates(Qt::WindowNoState)`, and
  `QCocoaWindow::applyWindowState` exits the current state before applying the
  new one — so a full-screen window got `toggleFullScreen:`.
- Underlying cause: the function conflated "make the window visible" with
  "bring the window forward". The `Minimized` / `else` split it inherited
  reads like it distinguishes those, but both arms end in the same
  `setWindowStates(WindowNoState)`, so the distinction was cosmetic. Only the
  closed-window case actually needs a show at all, and a closed window is never
  full screen (`beginWindowClose()` exits full screen first).
- Why the harness/checklists did not prevent it: the behavior is only visible
  in a state no static test covers — window visible *and* full screen, then
  restored from the status item. `20260729-0155-B`'s test plan exercised
  restore-after-close and full-screen-then-close, but never
  full-screen-then-restore.

## 4. Fix

- Files changed: `src/services/macos/macos_app_lifecycle.mm`
  (`restoreWindow()`, one `else if (!window_->isVisible())` guard plus the
  comment explaining why a visible window must not be re-shown).
- Short description: only show the window when it is actually hidden or
  minimized; an already-visible window just gets `raise()` +
  `requestActivate()`, which do not touch window state.
- Commit: pending commit.

## 5. Prevention

Concrete upgrade: a bullet under `rules/02-platform-boundaries.md` §5 saying
that on cocoa `QWindow::show()`/`showNormal()` reset window state, so a macOS
restore or raise path must gate them on `!isVisible()` instead of calling them
unconditionally.

Not applied in this session, and the reason is mechanical: that file is exactly
at the 100-line budget pass 1 enforces, so landing the bullet means trimming
two lines elsewhere in it — a drive-by rule edit this track forbids. Filed as a
follow-up instead; the guard's own comment in `restoreWindow()` carries the
warning at the call site meanwhile.
