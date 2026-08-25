# Error Report - error-topic-too-long

## Metadata

- Level: **L3**
- Track: **C**
- Topic: error-topic-too-long
- Recorded: 2026-08-24T21:36:44Z
- Session: (unknown)
- Platform: windows
- Tooling: (fill in)

## 1. What happened

Two record_error calls used slugs over the 40-character limit and produced no reports; retried with shorter topics.

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
