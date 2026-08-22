# Error Report - automated-desktop-runtime-probe-isolated

## Metadata

- Level: **L3**
- Track: **C**
- Topic: automated-desktop-runtime-probe-isolated
- Recorded: 2026-08-22T03:41:59Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The post-fix service launched from the Codex tool process shared Windows SessionId 1 but saw no foreground observation even on clean shutdown, indicating an isolated desktop/window-station; runtime checkpoint verification must be relaunched through the interactive Explorer shell.

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
