# Error Report - macos-titlebar-still-visible

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-titlebar-still-visible
- Recorded: 2026-07-28T08:30:37Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Runtime visual verification shows a visible macOS title-bar region despite
transparent AppKit styling and full-size-content flags.

## 2. Evidence

```
User verification after launching the rebuilt app: "why am i seeing the title
bar then?"
```

## 3. Root cause

- Immediate cause: Qt Quick Controls 6.9+ automatically copied the window's
  28-pixel macOS safe-area inset into `ApplicationWindow.topPadding`.
- Underlying cause: the native content view already covered the complete
  window, but QML shifted every child below the traffic lights and exposed the
  `ApplicationWindow` background as a title-like strip.
- Why the harness/checklists did not prevent it: the previous pass treated
  native window geometry as sufficient without inspecting the rendered pixels.

## 4. Fix

- Files changed: `qml/main.qml` and
  `src/services/macos/macos_traffic_lights.mm`.
- Short description: create the macOS window with Qt's expanded-client-area
  flags and explicitly set `topPadding: 0` for the macOS sidebar shell while
  retaining AppKit's window-owned controls.
- Commit: pending.

## 5. Prevention

Use a post-load screenshot for chrome changes; native-property inspection does
not reveal QML safe-area padding.
