# Error Report - macos-collapsed-logo-alignment

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-collapsed-logo-alignment
- Recorded: 2026-07-28T09:39:36Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The macOS collapsed-sidebar TimeArc logo is smaller and horizontally
misaligned relative to the navigation control column.

## 2. Evidence

```
Supplied 17:37:28 screenshot: the logo occupies 36 logical pixels beginning at
the column's left edge, while collapsed controls occupy the full 52-pixel
column. Their centers differ by 8 logical pixels.
```

## 3. Root cause

- Initial hypothesis: the logo keeps its expanded-sidebar 36x36 size after
  collapse; because its Row is left-aligned, it remains centered at x=36 while
  collapsed controls are centered at x=44.
- Why the harness/checklists did not prevent it: the existing responsive rule
  changes sidebar width but has no collapsed-state rule for the logo.

## 4. Fix

- Files changed: `qml/desktop/DesktopAppShell.qml`
- Short description: Uniformly scale the complete logo to 52x52 for both
  macOS sidebar states, including its glyph and corner geometry. Preserve
  36x36 on other platforms.
- Commit: not requested

## 5. Prevention

One-off layout correction; no harness change.
