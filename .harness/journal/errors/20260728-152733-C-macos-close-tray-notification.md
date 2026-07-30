# Error Report - macos-close-tray-notification

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-close-tray-notification
- Recorded: 2026-07-28T15:27:33Z
- Session: `../sessions/20260728-2327-C-macos-close-tray-notification.md`
- Platform: macOS
- Tooling: QML notification call-site inspection

## 1. What happened

Closing the TimeArc window on macOS emits an unwanted system notification even though the status-item behavior is already visible

## 2. Evidence

`qml/main.qml` called `notifyClosedToTray()` after every desktop close,
including the native macOS status-item path.

## 3. Root cause

- Immediate cause: the notification call had no macOS condition.
- Underlying cause: close-to-tray behavior was originally shared across all
  desktop platforms.
- Why the harness/checklists did not prevent it: the existing static checks
  verified tray wiring but not platform-specific notification policy.

## 4. Fix

- Files changed: `qml/main.qml`,
  `tests/macos_fullscreen_close_static_test.py`
- Short description: call `notifyClosedToTray()` only when
  `macSidebarChrome` is false.
- Commit: pending

## 5. Prevention

Focused macOS static regression now checks the notification-suppression gate.
