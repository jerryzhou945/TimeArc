# Error Report - macos-double-click-preference

## Metadata

- Level: **L2**
- Track: **B**
- Topic: macos-double-click-preference
- Recorded: 2026-07-29T08:38:01Z
- Session: (unknown)
- Platform: macOS
- Tooling: Qt Quick, AppKit

## 1. What happened

Sidebar double-click always maximized/restored instead of respecting the macOS AppleActionOnDoubleClick preference

## 2. Evidence

```
DesktopAppShell.qml directly called showMaximized()/showNormal() for every
double-click and never consulted AppleActionOnDoubleClick.
```

## 3. Root cause

- Immediate cause: the action was implemented entirely in cross-platform QML.
- Underlying cause: “zoom” was interpreted as a fixed maximize toggle instead
  of native title-bar preference behavior.
- Why the harness/checklists did not prevent it: existing smoke tests validate
  resources and storage, not macOS pointer preferences.

## 4. Fix

- Files changed: `qml/desktop/DesktopAppShell.qml`,
  `src/services/macos/macos_traffic_lights.{h,mm}`, `README.md`,
  `tests/macos_sidebar_double_click_static_test.py`
- Short description: Hand off double-click to AppKit, read
  `AppleActionOnDoubleClick`, and invoke `performMiniaturize:` or
  `performZoom:`; unknown/None values do nothing.
- Commit: not requested

## 5. Prevention

Added a focused macOS static regression test.
