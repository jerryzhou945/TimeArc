# Error Report - ico-preview-unsupported

## Metadata

- Level: **L3**
- Track: **C**
- Topic: ico-preview-unsupported
- Recorded: 2026-08-25T05:24:11Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: Codex local image viewer and Pillow

## 1. What happened

Local image viewer could not decode the generated ICO directly; converting its largest frame to PNG for visual inspection

## 2. Evidence

```
unable to process image: invalid or unsupported image data
```

## 3. Root cause

- Immediate cause: the viewer does not decode ICO containers.
- Underlying cause: visual inspection requires a supported raster preview format.
- Why the harness/checklists did not prevent it: this is a viewer capability boundary.

## 4. Fix

- Files changed: temporary PNG preview outside the repository only
- Short description: extracted the 256px ICO frame to PNG and visually inspected it.
- Commit:

## 5. Prevention

One-off viewer limitation; no project change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: the local viewer accepted ICO input directly.
- Earlier signal available: supported formats were not guaranteed by the tool contract.
- Rule file to update: none.
