# Error Report - app-icon-resolver-check-mismatch

## Metadata

- Level: **L3**
- Track: **C**
- Topic: app-icon-resolver-check-mismatch
- Recorded: 2026-06-18T15:45:48Z
- Session: `.harness/journal/sessions/20260618-2338-C-english-tags-icons-mac-doc.md`
- Platform: Windows
- Tooling: PowerShell structural check

## 1. What happened

After adding the icon resolver, the structural check still failed.

## 2. Evidence

```text
AppIconImageProvider does not resolve app ids/basenames through Windows App Paths
```

## 3. Root cause

- Immediate cause: the literal `App Paths` was split inside a C++ string, and
  `QDir` was used without an include.
- Underlying cause: the structural check looked for a readable marker.
- Why the harness/checklists did not prevent it: this was a patch iteration
  mistake.

## 4. Fix

- Files changed: `src/services/app_icon_image_provider.cpp`
- Short description: add `QDir` include and a readable `App Paths` comment.
- Commit: pending

## 5. Prevention

Keep structural checks tied to comments or function names, not split literals.

## 6. Lessons for agents (L3)

- Wrong assumption: the check would see a split C++ string.
- Earlier signal available: failed structural check output.
- Rule file to update: none.
