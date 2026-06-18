# Error Report - harness-check-session-link

## Metadata

- Level: **L3**
- Track: **C**
- Topic: harness-check-session-link
- Recorded: 2026-06-18T07:19:43Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

harness_check failed because the new C session log linked error reports without the journal/errors path format

## 2. Evidence

```
DRIFT: track C session 20260618-1509-C-remaining-english-keywords-heatmap.md does not link any journal/errors/*.md
```

## 3. Root cause

- Immediate cause: the session log linked bare filenames instead of
  `errors/*.md` paths.
- Underlying cause: I wrote human-readable links that the harness parser did
  not recognize.
- Why the harness/checklists did not prevent it: the exact expected link shape
  is only surfaced by `harness_check.py`.

## 4. Fix

- Files changed: `.harness/journal/sessions/20260618-1509-C-remaining-english-keywords-heatmap.md`.
- Short description: changed links to `errors/<report>.md`.
- Commit: pending.

## 5. Prevention

Use `errors/<filename>.md` in C session logs.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
