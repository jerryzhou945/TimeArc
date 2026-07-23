# Change Proposal — macos-tracking-main

## Metadata

- Author: Codex `/root`
- Track: **C (Debug)** — repair a known macOS service compile failure.
- Date: 2026-07-24 03:39 (Asia/Shanghai)
- Session goal: Compile and run the standalone macOS Tracking implementation on an exact one-second polling cadence.
- Branch: `development/macos-support`
- Related error report: `../errors/20260723-193950-C-macos-main-missing-runner.md`

## 1. Frozen files touched

- `src/service/CMakeLists.txt` — replace deleted legacy macOS sources with the current Tracking sources and required frameworks.

## 2. Motivation

The macOS target references deleted sources, while its main entry point calls
the removed `LiveServiceApplication`. The service cannot compile or poll the
new Tracking coordinator until both integration points match.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | Builds the macOS tracker and samples foreground/media state once per second. |
| Consumer | No schema or read-path change; the UI continues reading the service database. |

## 4. Migration plan

No on-disk impact. The existing SQLite contract and bridge signatures remain unchanged.

## 5. Rollback plan

Revert the CMake source-list integration and main runner; no data restoration is required.

## 6. Test plan

- Pre-change: type-check reports `LiveServiceApplication` missing.
- Post-change: type-check the exact CMake Swift source set.
- Run the sanctioned build and inspect its result.
- Verify the runner uses monotonic deadlines one second apart and flushes on shutdown.

## 7. Sign-off

- [x] No rule change required; architecture and disk contract are unchanged.
- [x] No charter amendment required.
- [x] `state/frozen-files.json` will be regenerated for the proposed CMake edit.
- [x] No user-visible README change required.

## Outcome

- Replaced the removed application layer with a direct `TrackingCoordinator` runner.
- Polling uses absolute monotonic deadlines one second apart and skips missed slots.
- `SIGINT` and `SIGTERM` interrupt the wait and flush pending sessions.
- Scoped Swift type-check and the sanctioned full build passed.
