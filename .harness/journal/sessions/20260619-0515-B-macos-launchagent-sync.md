# 2026-06-19 B macOS LaunchAgent sync

## Goal

Continue the macOS backend sync in the order listed by
`docs/platform-parity-packaging-gap.md`, implementing the next Windows-workspace
actionable gaps: service lifecycle verbs and UI auto-start for the macOS helper.

## Scope decision

The first remaining item, Mac-host compile/runtime smoke, cannot be completed on
this Windows host because there is no Apple Swift toolchain or macOS permission
environment. This session therefore proceeds to the next actionable items:

1. LaunchAgent lifecycle verbs in the macOS helper.
2. UI auto-start path discovery for the macOS helper.
3. Documentation updates that mark completed and still-blocked parts.

## Service side

`time-arc-service` on macOS should accept lifecycle verbs similar to Windows:
`--install`, `--uninstall`, `--start`, `--stop`, and `--status`. These verbs use
per-user LaunchAgent files and the existing helper lock pid to avoid IPC and to
keep sampling in the user session.

## UI side

`src/main.cpp::startUsageService()` should locate a macOS helper in common dev,
install, and bundle-adjacent locations, then start it detached. The UI still
does not sample and does not link service code.

## Expected files

- `src/service/macos/TimeArcService.swift`
- `src/main.cpp`
- `.harness/rules/02-platform-boundaries.md`
- `.harness/state/open-issues.md`
- `docs/platform-parity-packaging-gap.md`
- `docs/implementation-backlog.md`
- `docs/macos-launchagent-sync-report.md`

## Rule notes

- No frozen shared contract files should be edited.
- No schema or C bridge change is expected.
- CMake remains untouched because it is frozen and the implementation fits
  existing files.

## Verification

- Baseline `python .harness/tools/build.py` passed before edits.
- RED structural checks confirmed no macOS lifecycle verbs or UI macOS helper
  auto-start branch existed.
- GREEN structural checks confirmed the lifecycle verbs, LaunchAgent/launchctl
  usage, and `Q_OS_MACOS` helper lookup branch exist after edits.
- First post-edit build failed because a running `TimeArc.exe` locked the output
  binary; this was recorded in the harness and resolved by stopping the local
  process.
- `python .harness/tools/build.py` passed after stopping the running app.
- `ctest --test-dir build --output-on-failure` passed (`timearc_db_smoke`).
- `python .harness/tools/harness_check.py` passed.
- `git diff --check` passed.
- macOS Swift compile/runtime and LaunchAgent smoke remain pending on a Mac host.
