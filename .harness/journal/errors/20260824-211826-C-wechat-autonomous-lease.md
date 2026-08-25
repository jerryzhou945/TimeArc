# Error Report - wechat-autonomous-lease

## Metadata

- Level: **L2**
- Track: **C**
- Topic: wechat-autonomous-lease
- Recorded: 2026-08-24T21:18:26Z
- Session: `../sessions/20260825-0518-C-wechat-autonomous-lease.md`
- Platform: Windows 11
- Tooling: service SQLite inspection, source inspection, CTest

## 1. What happened

Windows foreground tracker grants process CPU/I/O work lease to WeChat and other generic foreground apps, so active_sec continues after 60 seconds of keyboard/mouse idle.

## 2. Evidence

On 2026-08-25, today's WeChat rows in `timearc_service.db` contained 73
foreground segments totaling 2,895 seconds, of which 2,854 seconds were
written as active and only 41 seconds as idle. `time-arc-service --status`
reported the default frontmost idle threshold of 60 seconds.

Source inspection reproduced the policy defect: `usage_tracker.c` samples
process-tree CPU/I/O for every foreground executable and assigns any delta to
`sample.autonomous_active`; `foreground_state.c` then renews the bounded work
lease. WeChat background refresh therefore defeats input-idle classification.

## 3. Root cause

- Immediate cause: generic foreground process CPU/I/O set
  `sample.autonomous_active` and continuously renewed the work lease.
- Underlying cause: the Codex-specific process-tree extension was added on top
  of a generic foreground-root sampler without restricting the base sampler to
  the official packaged Codex application.
- Why the harness/checklists did not prevent it: process aggregation and Codex
  topology tests existed, but no policy regression asserted that a non-Codex
  foreground app cannot use process deltas as autonomous work evidence.

## 4. Fix

- Files changed: `src/service/windows/platform/process_activity_win.h`,
  `src/service/windows/platform/process_activity_win.c`,
  `tests/windows_foreground_state_test.c`
- Short description: select autonomous process roots only from official
  packaged Codex workers. Generic foreground apps return no process-work
  evidence, so their probe baseline resets and input idle controls active time.
  The Codex frontend itself is excluded from worker aggregation to prevent UI
  churn from extending a completed task.
- Commit: pending

## 5. Prevention

Added policy regressions proving that WeChat has no autonomous process roots
and that packaged Codex selects only its `codex.exe` worker root. No harness
change needed.
