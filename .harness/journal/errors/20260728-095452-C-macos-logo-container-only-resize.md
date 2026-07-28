# Error Report - macos-logo-container-only-resize

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-logo-container-only-resize
- Recorded: 2026-07-28T09:54:52Z
- Session: (unknown)
- Platform: macOS
- Tooling: Qt Quick/QML

## 1. What happened

The first sidebar fix enlarged the logo container only; the glyph and corner geometry stayed at the old scale, and expanded macOS retained a different size

## 2. Evidence

```
The first patch changed the Rectangle width and height only when
`macSidebarChrome && sidebarCollapsed`; the Text font size and radius remained
fixed, and expanded macOS still used 36x36.
```

## 3. Root cause

- Immediate cause: only the outer container dimensions were made responsive.
- Underlying cause: “icon size” was interpreted as the bounding rectangle
  rather than a uniform scale of the complete composite logo.
- Why the harness/checklists did not prevent it: this is a visual-intent detail
  not covered by automated layout checks.

## 4. Fix

- Files changed: `qml/desktop/DesktopAppShell.qml`
- Short description: Use 52x52 for both macOS sidebar states and scale the
  corner radius and glyph proportionally with the logo.
- Commit: not requested

## 5. Prevention

One-off visual correction; no harness change.
