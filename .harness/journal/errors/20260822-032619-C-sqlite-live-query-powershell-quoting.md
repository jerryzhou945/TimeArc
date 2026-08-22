# Error Report - sqlite-live-query-powershell-quoting

## Metadata

- Level: **L3**
- Track: **C**
- Topic: sqlite-live-query-powershell-quoting
- Recorded: 2026-08-22T03:26:19Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

First live SQLite diagnostic used backslash escaping that PowerShell does not honor, so its SQL was parsed as shell syntax; retrying with parameterized SQL and PowerShell-safe quoting.

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
