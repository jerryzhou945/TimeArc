# Change Proposal - desktop-mvp-interaction

## Metadata

- Author: Codex
- Track: B (Feature)
- Date: 2026-05-22 03:10 (Asia/Shanghai)
- Session goal: Validate the desktop MVP interaction loop and fix the smallest issues blocking real verification.
- Branch: current workspace
- Related error reports: `errors/20260521-074140-B-build-failure.md`

## 1. Frozen Files Touched

- `src/CMakeLists.txt`: keep smoke-test source sets aligned with existing repository and manager code used by `tests/db_smoke.cpp`.

## 2. Motivation

The harness build currently reaches the real CMake build but fails when linking `timearc_db_smoke.exe` because the target omits existing sources for `SettingsRepository`, `ProjectManager`, and `CalendarManager`. Without this fix, MVP repository verification can only use stale binaries or manual inspection.

## 3. Impact On The Other Process

| Side | Effect |
|------|--------|
| Producer | No service-side effect. |
| Consumer | UI app sources are unchanged; the smoke target links the same consumer-side managers already used by the app. |

## 4. Migration Plan

No on-disk data migration or schema change.

## 5. Rollback Plan

Revert the source-list change; no data rollback is needed.

## 6. Test Plan

- Pre-change reproduction: `python .harness/tools/build.py` fails linking `timearc_db_smoke.exe`.
- Post-change verification: harness build links the smoke target, then desktop MVP flows can be validated against the current binary.
- New test artifacts: none expected.

## 7. Sign-off

- [ ] `rules/*.md` updated if the build-source convention changes; no rule change expected.
- [ ] `CHARTER.md` version bump not needed.
- [ ] `state/frozen-files.json` will be kept consistent before final harness check.
- [ ] Main `README.md` update not expected for this build-only fix.
