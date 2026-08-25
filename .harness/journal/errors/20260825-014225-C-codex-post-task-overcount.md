# Error Report - codex-post-task-overcount

## Metadata

- Level: **L2**
- Track: **C**
- Topic: codex-post-task-overcount
- Recorded: 2026-08-25T01:42:25Z
- Session: .harness/journal/sessions/20260825-0942-C-codex-post-task-overcount.md
- Platform: windows
- Tooling: (fill in)

## 1. What happened

Codex agent time continued increasing after the five-minute command completed

## 2. Evidence

`TIMEARC_USAGE_WORK_LEASE_MS` is 90000. Live `Codex task` rows continued in
60-second checkpoints without a gap, including 1787621613–1787621673 followed
by 1787621673–1787621733 after the next request arrived.

## 3. Root cause

- Immediate cause: `timearc_agent_activity_step` keeps the session active until
  90 seconds after the last detected CPU/I/O change.
- Underlying cause: the close path advances `last_wall_sec` on every poll, so
  the grace/lease tail is persisted as active time rather than only debouncing
  the activity state.
- Why the harness/checklists did not prevent it: unit tests assert the 90-second
  survival behavior but do not distinguish a grace period from billable time.

## 4. Fix

- Files changed: diagnostic journal only.
- Short description: root cause documented; production behavior unchanged.
- Commit: pending.

## 5. Prevention

Add a test that asserts the persisted end boundary after the final work signal,
not only whether the lease state remains active.
