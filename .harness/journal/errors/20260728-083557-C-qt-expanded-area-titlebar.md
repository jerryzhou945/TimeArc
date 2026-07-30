# Error Report - qt-expanded-area-titlebar

## Metadata

- Level: **L2**
- Track: **C**
- Topic: qt-expanded-area-titlebar
- Recorded: 2026-07-28T08:35:57Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The first Qt 6.11 expanded-client-area build still displayed a 28-pixel light
strip above the QML scene.

## 2. Evidence

```
Native inspection: styleMask 0x800f, FullSizeContentView enabled,
titlebarAppearsTransparent enabled, content/QNSView both 1440x810.
Pixel inspection: QML content began 28 pixels below the top edge.
```

## 3. Root cause

- Immediate cause: `ApplicationWindow` automatically padded its content item by
  `SafeArea.margins.top`.
- Underlying cause: Qt 6.9 introduced automatic safe-area padding, independently
  of the correctly expanded native content view.
- Why the harness/checklists did not prevent it: no chrome check compared the
  native view frame with the QML content item's rendered origin.

## 4. Fix

- Files changed: `qml/main.qml`.
- Short description: override `topPadding` with zero for the macOS sidebar
  window and preserve the normal safe-area value on other surfaces.
- Commit: pending.

## 5. Prevention

Add safe-area padding to the macOS chrome visual checklist.
