# Error Report - codex-background-overcount

## Metadata

- Level: **L2**
- Track: **C**
- Topic: codex-background-overcount
- Recorded: 2026-08-27T21:02:57Z
- Session: (unknown)
- Platform: Windows 11
- Tooling: native usage service, SQLite read-only diagnostics

## 1. What happened

Codex continues accumulating usage while merely resident in the background after task execution has stopped; desired behavior is to count only active task execution.

## 2. Evidence

```
2026-08-27T15:34:36 -> 16:05:16
wall span=1840 sec, recorded=1829 sec, 32 Codex task rows

TIMEARC_USAGE_WORK_LEASE_MS=90000
timearc_agent_activity_step() advanced last_wall_sec on every sample while
the lease remained open, even when work_active was false.
```

## 3. Root cause

- Immediate cause: the Codex agent state advanced its persisted end timestamp
  during lease-only samples and checkpoints, so grace time was counted as work.
- Underlying cause: the 90-second foreground idle lease was reused for an
  independent background agent session whose CPU/I/O signal is intentionally
  intermittent.
- Why the harness/checklists did not prevent it: the existing test explicitly
  expected foreground loss and the full 90-second lease to be recorded; it did
  not assert that the recorded end remains the last observed work sample.

## 4. Fix

- Files changed: `src/service/windows/platform/process_activity_win.c`,
  `src/service/windows/tracker/usage_tracker.{c,h}`,
  `tests/windows_foreground_state_test.c`.
- Short description: persisted Codex time now stops at the last real work
  sample, checkpoints cannot extend lease-only time, and the agent-only
  continuity lease is 10 seconds instead of the foreground 90-second lease.
- Commit: pending commit.

## 5. Prevention

State-machine regression coverage now proves lease-only samples and
checkpoints cannot extend recorded Codex task time. Focused test and full
CTest suite pass.
