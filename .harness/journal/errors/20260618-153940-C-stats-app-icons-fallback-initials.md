# Error Report - stats-app-icons-fallback-initials

## Metadata

- Level: **L2**
- Track: **C**
- Topic: stats-app-icons-fallback-initials
- Recorded: 2026-06-18T15:39:40Z
- Session: `.harness/journal/sessions/20260618-2338-C-english-tags-icons-mac-doc.md`
- Platform: Windows
- Tooling: QML/C++ review, structural check

## 1. What happened

Stats app rows often showed generated initial-letter icon tiles instead of
native application icons.

## 2. Evidence

```text
AppVisual.modelIconSource(row) can call image://appicon/app:vscode or another
identity when a concrete executable path is unavailable. The provider then
falls back to a painted first-letter pixmap.
```

## 3. Root cause

- Immediate cause: `AppIconImageProvider` only accepted existing file paths.
- Underlying cause: aggregated Stats rows can retain stable app identities even
  when the executable path is missing or stale.
- Why the harness/checklists did not prevent it: icon checks covered QML source
  shape, not provider-side identity recovery.

## 4. Fix

- Files changed: `src/services/app_icon_image_provider.cpp`
- Short description: resolve known app ids and executable basenames through
  Windows App Paths, PATH lookup, and explorer fallback before painting initials.
- Commit: pending

## 5. Prevention

Use provider-side resolver checks when changing app identity aggregation.
