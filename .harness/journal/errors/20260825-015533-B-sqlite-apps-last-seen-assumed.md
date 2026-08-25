# Error Report - sqlite-apps-last-seen-assumed

## Metadata

- Level: **L3**
- Track: **B**
- Topic: sqlite-apps-last-seen-assumed
- Recorded: 2026-08-25T01:55:33Z
- Session: .harness/journal/sessions/20260825-0953-B-app-identity-management.md
- Platform: windows
- Tooling: (fill in)

## 1. What happened

Read-only icon investigation query assumed a non-existent apps.last_seen_unix_sec column after PRAGMA showed updated_at

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
