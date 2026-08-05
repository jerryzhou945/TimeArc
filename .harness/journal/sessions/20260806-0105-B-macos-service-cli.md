# Change Proposal — macos-service-cli

## Metadata

- Author: Claude
- Track: **B (Feature)**
- Date: 2026-08-06 01:05 (local)
- Session goal: Replace the placeholder macOS `@main` with a composition root and land the `CommandLine/` slice of the service CLI.
- Branch: feature/macos-service
- Baseline commit: f4a508f
- Related error reports: none

## 1. Frozen files touched

- `src/service/CMakeLists.txt` — add five macOS Swift sources to
  `TIME_ARC_SERVICE_PLATFORM_SOURCES`: `CommandLine/ServiceCommand.swift`,
  `CommandLine/ServiceCommandParser.swift`, `CommandLine/ServiceExitCode.swift`,
  `CommandLine/ServiceUsage.swift`, and `Runtime/RunCommand.swift`. No target,
  flag, framework, or bridging-header change.

## 2. Motivation

`macos/TimeArcService.swift` is a test entry point: it ignores `argv`, hardcodes
the idle threshold, and inlines the poll loop. `src/service/README.md` specifies
a ten-verb CLI and an exit-code table that nothing implements, so the documented
contract is unverifiable and the helper cannot be driven by anything except
launchd. This lands the parser, the command model, and the exit-code table so the
CLI contract is fixed and testable before the `Runtime/`, `Configuration/`,
`Autostart/`, and `Diagnostics/` slices are built on top of it.

Scope is intentionally the smallest runnable slice: `run`, `help`, and `version`
execute; the other seven verbs parse completely and exit 1 with a message.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | `time-arc-service` gains argument parsing. With no arguments it behaves exactly as today, which is the only path launchd uses (`BundleProgram`, no `ProgramArguments`). Sampling, session semantics, and writes are untouched. |
| Consumer | None. The UI does not launch the helper (`tests/gui_service_startup_static_test.py` forbids it) and only registers the LaunchAgent through `SMAppService`. |

Service side: no change to `data_bridge.h` usage, the SQLite schema, or the
tracking loop's timing; `Runtime/RunCommand.swift` holds the current loop verbatim
and returns an exit code instead of calling `exit`.

UI side: unchanged.

## 4. Migration plan

No on-disk impact. No schema, path, or record-format change.

## 5. Rollback plan

Revert the commit. The five new files and the CMake list entries are additive;
`TimeArcService.swift` returns to its previous body. No data restoration.

## 6. Test plan

- Pre-change reproduction: `time-arc-service --help` starts tracking instead of
  printing usage; every argument is ignored; no exit code from the README table
  is ever produced.
- Post-change verification: build `time_arc_service`; walk the CLI matrix
  (`--help`, `version`, no-arg run, `run`, `status --json --verbose`,
  `status --text --json`, `bogus`, `run extra`) checking `$?` against the README
  table; confirm the no-arg run still writes `frontmost_sessions`.
- New test artifacts: `tests/macos_service_cli_static_test.py`, which
  cross-checks the parser and exit-code enum against `src/service/README.md`
  and the CMake project version.

## 7. Sign-off

- [x] `rules/02-platform-boundaries.md` §3 macOS bullet list is stale (it still
      names `AppEnv.swift` / `WindowIdentifying.swift`, removed by the `Tracking/`
      rework); refreshed to describe the current file set.
- [ ] `CHARTER.md` version bumped (not applicable; no invariant changes).
- [x] `state/frozen-files.json` regenerated for the approved frozen-file edit.
- [x] `src/service/README.md` needs no change; this implements its existing spec.

## Notes for the follow-up slices

`stop` must be launchd-aware: the bundled agent is `KeepAlive=true`, so a plain
SIGTERM is relaunched within seconds. The agreed semantics are
`launchctl bootout gui/$UID/com.timearc.service` with a SIGTERM fallback for a
manually started foreground helper, which leaves autostart registered and makes
`status` report exit 12 (not running, enabled).

## Outcome

Done. `time_arc_service` builds; the CLI matrix matches the README table
(`--help`/`version` 0, unimplemented verbs 1, all four malformed command lines 2);
a no-argument run sampled and flushed on SIGTERM, taking `frontmost_sessions`
from 5337 to 5348 with the open session written at shutdown and exit code 0.
`tests/macos_service_cli_static_test.py` and `gui_service_startup_static_test.py`
pass; `harness_check.py` is clean across all seven passes.

Unrelated pre-existing failure observed, not touched by this change:
`tests/macos_build_script_static_test.py` fails because `tools/build-macos.sh:162`
calls `cmake --build` directly instead of `.harness/tools/build.py` (drift from
commit 19c6997).
