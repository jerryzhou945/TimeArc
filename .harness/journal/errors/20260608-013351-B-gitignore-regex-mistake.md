# Error Report - gitignore-regex-mistake

## Metadata

- Level: **L3**
- Track: **B**
- Topic: gitignore-regex-mistake
- Recorded: 2026-06-08T01:33:51Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

During handoff cleanup verification, Select-String pattern docs|*.md|handoff was an invalid regex because * was unescaped; status already confirmed the handoff doc is untracked.

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
