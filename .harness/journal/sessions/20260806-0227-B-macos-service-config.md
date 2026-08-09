# Change Proposal — macos-service-config

## Metadata

- Author: Claude
- Track: **B (Feature)**
- Date: 2026-08-06 02:27 (local)
- Session goal: Implement backlog A3 on macOS — the service-side `service_config.json` reader plus the runtime lifecycle it needs.
- Branch: feature/macos-service · Baseline commit: af520b0 · Error reports: none

## 1. Frozen files touched

- `src/service/CMakeLists.txt` — add the `Configuration/` and `Runtime/` Swift
  sources to `TIME_ARC_SERVICE_PLATFORM_SOURCES`. No target, flag, framework, or
  bridging-header change; `data_bridge.h` stays the only bridged header.

`src/service/shared/database_path.{c,h}` are **not** touched: no new exported C
function, no change to database path resolution. See §3 for the consequence.

## 2. Motivation

CHARTER v0.13 approved `service_config.json` v1 and shipped the UI writer, but
`rules/03-data-contract.md` §1b still records the service-side `tracking.*` reader
as pending (backlog A3). On macOS the helper reads no configuration at all:
`RunCommand.swift` hardcodes `idleThreshold: 60`, a 1 s poll, and both switches,
so every collection setting the Settings page writes is silently inert. Two
further gaps in the same file: no single-instance guard, which charter I1 requires
on every platform, and the first tick after a wake adds the whole sleep gap to
`active_sec`, because `FrontmostStateMachine` accumulates unconditionally.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | The helper now reads `tracking.*` at startup and honors every documented key, guards against a second instance, and closes sessions across sleep/clock jumps instead of inflating `active_sec`. Records remain identical in shape. |
| Consumer | None directly. The UI's existing `patchServiceConfig` writes finally take effect on macOS, which is the intended contract. |

Service side: session identity is unchanged by checkpointing (rule 02 §2.6), so
`max_session_sec` only splits one long row into contiguous rows. UI side: unchanged.

**Deliberate duplication.** The config path is computed in Swift
(`Configuration/ServiceConfigurationPath.swift`) rather than exported from
`database_path.c`, whose `build_config_path` is static. rules/03 §1b warns the two
sides must stay in step, so the literals sit in one small file and
`tests/macos_service_config_static_test.py` asserts they still match the C
constants, including reading `HOME` the same way. If a third platform needs the
same path, exporting `get_config_path` from shared C is the better fix.

## 4. Migration plan

No on-disk impact. No schema, path, or record-format change. Existing
`service_config.json` files are read as-is; absent or malformed files fall back to
compile-time defaults exactly as rules/03 §1b specifies.

## 5. Rollback plan

Revert the commit. The new files and CMake entries are additive and `RunCommand`
returns to its hardcoded values. No data restoration: no record changes shape.

## 6. Test plan

- Pre-change reproduction: write `tracking.frontmost.idle_threshold_sec: 5` and
  `tracking.enabled: false` — the helper ignores both and keeps sampling at 60 s idle.
- Post-change verification: the config matrix (absent / malformed / newer schema /
  disabled / sub-switches / poll period / min and max session / out-of-range),
  second-instance exit 6, and SIGTERM flush. Row-level contiguity checked in
  SQLite for `max_session_sec`.
- New test artifacts: `tests/macos_service_config_static_test.py` (README key table
  ↔ Swift parser + config-path drift guard) and `..._smoke_test.py` (real binary
  under a redirected HOME, as this proposal's predecessor §6 asked for).

## 7. Sign-off

- [x] `rules/03-data-contract.md` §1b (reader done on macOS; Win/Linux pending)
      and `rules/02-platform-boundaries.md` macOS section updated.
- [ ] `CHARTER.md` version bumped (not applicable). The v0.13 entry records what
      that amendment approved, not implementation status, so it is left as written.
- [x] `state/frozen-files.json` regenerated; `docs/implementation-backlog.md` A3
      entry updated; `src/service/README.md` needs no change (this implements it).

## Outcome

Partial. Verified: clean build; smoke green on all six cases (disabled → 0 with no
DB created, both sub-switches off → 0, `schema_version: 2` → 4 naming the version,
malformed → warn then run, out-of-range → warn by name then run, second instance →
6 while the first keeps collecting); graceful SIGTERM → 0 with the lock released;
both static tests and `harness_check.py` clean.

Blocked: `max_session_sec` contiguity and `min_session_sec` suppression need
records, and the rebuilt helper has no Accessibility grant (TCC keys on the code
identity, which changes on every relink of an ad-hoc-signed binary), so every
sample throws `accessibilityTitleUnavailable`.

Finding for a separate work item: that throw comes from
`TrackingCoordinator.getFrontmostSession`, where a title failure aborts the whole
sample, so without the grant the service records **nothing** — even though
frontmost identity needs only `NSWorkspace` and `DataBridge` already substitutes
"Unknown Window". A fresh install collects zero data until Accessibility is
granted. Degrading to app-level records is outside this proposal's scope.
