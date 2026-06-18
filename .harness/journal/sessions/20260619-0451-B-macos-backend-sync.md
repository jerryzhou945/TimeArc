# 2026-06-19 B macOS backend sync

## Goal

Bring the macOS background helper closer to the Windows reference contract before packaging:

- read the shared service config (`idle_threshold_ms`, `track_enabled`);
- guarantee a single helper writer per user data directory;
- write media playback sessions from existing macOS media assertions;
- keep the shared disk contract unchanged.

## Plan

1. Add macOS-only config loading in `TimeArcService.swift` from `~/.timearc/usage/usage_config.json`.
2. Add a non-blocking file lock under the same usage directory so duplicate helpers exit before writing.
3. Add media-session tracking using `AppEnv.getMediaType()`, reusing the existing `ta_write_usage_record_with_source(..., "audio", ...)` bridge.
4. Update the Chinese platform parity documentation, backlog, and open issues to reflect the new macOS state and remaining gaps.
5. Verify on Windows with harness checks and record that macOS compile/runtime smoke still needs a Mac host.

## Rules touched

- `rules/01-architecture.md`: service-side behavior only, UI remains read-only.
- `rules/02-platform-boundaries.md`: macOS platform status updated.
- `rules/03-data-contract.md`: no schema or bridge change; existing `source=audio` path reused.
- `rules/08-git-workflow.md`: final Chinese implementation report required under `docs/`.

## Files expected

- `src/service/macos/TimeArcService.swift`
- `.harness/rules/02-platform-boundaries.md`
- `.harness/state/open-issues.md`
- `docs/platform-parity-packaging-gap.md`
- `docs/implementation-backlog.md`
- `docs/macos-backend-sync-report.md`

## Service side

The macOS helper owns sampling and writes through the shared C ABI. It must not invent a new disk format or bypass the storage layer.

## UI side

No UI change in this session. Existing desktop pages should continue to read the same SQLite/JSONL/current usage contract.

## Verification

- RED structural checks confirmed the macOS helper previously had no config
  loader, single-instance lock, or media-session write path.
- GREEN structural checks confirmed `ServiceConfig`, `SingleInstanceLock`,
  `getMediaType()`, and `ta_write_usage_record_with_source` are present after
  the change.
- `python .harness/tools/build.py` passed on Windows.
- `ctest --test-dir build --output-on-failure` passed (`timearc_db_smoke`).
- `python .harness/tools/harness_check.py` passed.
- macOS Swift compile/runtime smoke is still pending because this workspace has
  no `swiftc`; verification must continue on a Mac host.
