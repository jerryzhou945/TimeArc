# Error Report - macos-double-click-fill

## Metadata

- Level: **L2**
- Track: **B**
- Topic: macos-double-click-fill
- Recorded: 2026-07-29T08:56:05Z
- Session: (unknown)
- Platform: macOS
- Tooling: Qt Quick, AppKit, QWindow

## 1. What happened

The preference-aware sidebar double-click handler omitted the macOS Fill action, which should maximize the window

## 2. Evidence

```
The handler recognized Minimize, Maximize/Zoom, and non-actions, but had no
case-insensitive branch for the stored value "Fill".
```

## 3. Root cause

- Immediate cause: the Fill preference value was missing from the native
  action mapping.
- Underlying cause: the first mapping was based on an older three-option
  preference model.
- Why the harness/checklists did not prevent it: the initial regression test
  asserted only minimize and zoom branches.

## 4. Fix

- Files changed: `src/services/macos/macos_traffic_lights.mm`, `README.md`,
  `tests/macos_sidebar_double_click_static_test.py`
- Short description: Map Fill to `QWindow::showMaximized()` and cover it in
  the targeted regression test.
- Commit: not requested

## 5. Prevention

Extended the macOS preference regression test to require Fill.
