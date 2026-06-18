# Error Report - stats-service-filename-case

## Metadata

- Level: **L3**
- Track: **C**
- Topic: stats-service-filename-case
- Recorded: 2026-06-18T15:41:14Z
- Session: `.harness/journal/sessions/20260618-2338-C-english-tags-icons-mac-doc.md`
- Platform: Windows
- Tooling: Get-Content

## 1. What happened

Looked for `src/services/StatsService.cpp`, which does not exist.

## 2. Evidence

```text
Cannot find path 'D:\TimeArc\time-arc\src\services\StatsService.cpp'
```

## 3. Root cause

- Immediate cause: guessed camel-case filename.
- Underlying cause: this repo uses snake_case for `stats_service.cpp`.
- Why the harness/checklists did not prevent it: manual filename lookup error.

## 4. Fix

- Files changed: none for product behavior.
- Short description: continued with `src/services/stats_service.cpp`.
- Commit: pending

## 5. Prevention

Use file listings before guessing service filenames.

## 6. Lessons for agents (L3)

- Wrong assumption: C++ service filename matched class name casing.
- Earlier signal available: repo file list.
- Rule file to update: none.
