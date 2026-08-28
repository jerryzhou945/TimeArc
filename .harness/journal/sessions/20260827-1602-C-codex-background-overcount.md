# Track C — Codex background overcount

## Goal

Count Windows Codex usage only while an official Codex task shows real process-tree work, without counting passive background residence or post-task lease time.

## Related error report(s)

- `../errors/20260827-210257-C-codex-background-overcount.md`

## Plan

Add failing state-machine tests for lease-only samples and checkpoints, then make the smallest Codex-only timestamp and lease change required to pass them. Verify the focused Windows tracker test, the wrapped build, and the full test suite.

## Scope

Expected production files: `src/service/windows/platform/process_activity_win.c` and `src/service/windows/tracker/usage_tracker.h`. Expected test file: `tests/windows_foreground_state_test.c`. Discord/audio policy, game policy, QML, and both SQLite schemas stay untouched.

## Outcome

Root cause confirmed from the service DB and state machine: a 90-second
foreground lease was reused by Codex, and lease-only samples/checkpoints
advanced the persisted end time. The Codex-only lease is now 10 seconds and
persisted intervals end at the last real worker sample. The focused RED failed
at `closed.end_wall_sec == 1031`; GREEN passed after the fix. The wrapped full
build and all 6 CTest cases pass, and the rebuilt service is running. Discord,
game, QML, and database code were not changed. Runtime idle confirmation remains
a user-observable check after this Codex turn becomes idle.
