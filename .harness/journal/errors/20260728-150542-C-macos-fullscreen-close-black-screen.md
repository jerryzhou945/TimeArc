# Error Report - macos-fullscreen-close-black-screen

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-fullscreen-close-black-screen
- Recorded: 2026-07-28T15:05:42Z
- Session: `../sessions/20260728-2305-C-macos-fullscreen-close-black-screen.md`
- Platform: macOS
- Tooling: source inspection + Qt/AppKit documentation

## 1. What happened

Closing the GUI while in macOS full-screen leaves a black full-screen space instead of returning to the desktop

## 2. Evidence

Repro: enter native macOS full screen, then click the red close control.
`qml/main.qml:109-111` rejects the close event and immediately calls `hide()`.
Qt documents that hiding a full-screen window on macOS leaves its dedicated
desktop blank; the observed black Space is the documented result.

## 3. Root cause

- Immediate cause: `hide()` runs while the QWindow is still full-screen.
- Underlying cause: the cross-platform close-to-tray path was reused on macOS
  without first leaving the native full-screen Space.
- Why the harness/checklists did not prevent it: tray lifecycle tests only
  check static wiring and do not exercise close-from-full-screen on macOS.

## 4. Fix

- Files changed: `qml/main.qml`,
  `src/services/macos/macos_traffic_lights.{h,mm}`, and
  `tests/macos_fullscreen_close_static_test.py`.
- Short description: macOS close-to-tray now exits native full screen, waits
  for `NSWindowDidExitFullScreenNotification`, then hides the QWindow.
- Commit: pending

## 5. Prevention

Added a focused macOS structural regression test. Manual lifecycle smoke
remains required because desktop launch approval was declined.
