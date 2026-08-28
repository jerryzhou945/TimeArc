# Error Report - codex-timing-status-exit

## Metadata

- Level: **L3**
- Track: **C**
- Topic: codex-timing-status-exit
- Recorded: 2026-08-27T21:12:24Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Windows service --status reported running=yes and autostart=off but returned exit 1; treated output as state and continued with an orderly stop.

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
