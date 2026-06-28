# Change Proposal - android-backend-cmake

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-06-29 05:35 (local)
- Session goal (one sentence): Compile the new Android/mobile usage repository
  as part of the existing Qt app backend.
- Branch: `codex/android-usage-backend`
- Related error reports (if any): none

## 1. Frozen files touched

- `src/CMakeLists.txt` - add new C++ mobile usage backend source/header files
  to `TIME_ARC_DATABASE_SOURCES` and keep include roots consistent.

## 2. Motivation

The Android usage backend needs a C++ repository to normalize Android package
identifiers and persist UsageStats summaries into SQLite. New source files under
`src/services/mobile/` must be listed in `src/CMakeLists.txt` or the default
build and DB smoke test will not compile them.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | No change to desktop `time-arc-service`; Android collection lives in the app package and does not alter JSONL/live snapshot production. |
| Consumer | The Qt app gains compiled repository code for Android usage summaries and reads/writes the same SQLite database. |

## 4. Migration plan

Existing SQLite databases gain a new `device_usage_summaries` table. Existing
`apps`, `frontmost_sessions`, `media_sessions`, JSONL, and live snapshot records
remain valid and keep their current meaning.

## 5. Rollback plan

A code revert is sufficient. The added SQLite table can remain unused; no
existing records require destructive migration.

## 6. Test plan

- Pre-change reproduction: DB smoke cannot assert or use Android usage summary
  persistence because no table/repository exists.
- Post-change verification: DB smoke creates the table, upserts Android summary
  rows idempotently, and verifies app identity normalization.
- New test artifacts: additional checks in `tests/db_smoke.cpp`.

## 7. Sign-off

- [ ] `rules/*.md` updated to reflect new reality (not expected for P0-P5;
  docs/mobile plan is the implementation guide).
- [ ] `CHARTER.md` version bumped (not a charter amendment).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible.
