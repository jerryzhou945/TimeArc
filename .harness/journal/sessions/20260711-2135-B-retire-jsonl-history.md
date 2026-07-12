# Change Proposal — retire-jsonl-history

## Metadata

- Author: `/root`
- Track: **B (Feature)**
- Date: 2026-07-11 21:35 (Asia/Shanghai)
- Session goal: Make `timearc_service.db` the sole automatic-usage data store by retiring both legacy history JSONL and the JSON live snapshot; JSON remains only for service configuration.
- Branch: `development/macos-support` (user-directed override of the normal feature-branch rule)
- Related error reports: `errors/20260711-133736-B-missing-dev-branch.md`, `errors/20260711-133801-B-git-readonly-branch.md`

## 1. Frozen files touched

- `.harness/CHARTER.md` — remove JSON usage files from invariant I2 and bump the charter version.
- `.harness/AGENTS.md` — update the project summary to the SQLite-only usage architecture.
- `src/service/shared/usage_record.h` — describe the normalized session solely as SQLite input.
- `src/service/shared/usage_record.schema.json` — delete the obsolete JSON usage-record schema.
- `src/service/shared/database_path.c` — update the service-data directory comment after retiring usage JSON files.

Expected non-frozen implementation scope: Windows storage context/writer, `UsageStatManager`, settings QML, active contract/rule docs, README, backlog, and completion report. Historical session/error documents remain immutable history.

## 2. Motivation

SQLite migration S1–S4 is complete and `timearc_service.db` is already the primary UI history source. Continuing to write and read `usage_records.jsonl` duplicates history, preserves a non-transactional partial-write path, and keeps obsolete fallback/parity code alive. This session completes migration step S5 at the user's direction.

## 3. Impact on the other process

Service side: completed foreground/media sessions are written only to `timearc_service.db`; `usage_config.json` remains the disk control channel. UI side: usage is read only from the service DB; no JSON history fallback, live polling, current-app API, source override, or dual-source parity API remains.

| Side | Effect |
| --- | --- |
| Producer | Removes JSONL creation plus live-snapshot serialization, bridge calls, and tracker updates. |
| Consumer | Removes JSONL parsing/fallback, live polling/current-app presentation, and reports service DB size in Settings. |

## 4. Migration plan

Old releases may leave `usage_records.jsonl` and `usage_current.json`. New code neither reads, writes, nor deletes those files. Existing SQLite data remains unchanged; no schema or DDL migration is needed. Automatic deletion is intentionally avoided so an upgrade cannot destroy history or mutate user files without a dedicated cleanup action.

## 5. Rollback plan

A code revert restores the retired JSON history/live paths. Existing legacy files are untouched, and SQLite data needs no rollback.

## 6. Test plan

- Pre-change: service initializes JSONL and SQLite; UI exposes JSONL fallback/parity code.
- Post-change: build through the harness; run DB smoke tests; verify no active implementation or contract reference to usage-history JSONL or the JSON live snapshot remains; confirm config JSON remains.
- New test artifacts: completion report and existing database smoke coverage.

## 7. Sign-off

- [x] `rules/01-architecture.md`, `rules/02-platform-boundaries.md`, `rules/03-data-contract.md`, and `rules/04-ui-conventions.md` updated.
- [x] `.harness/CHARTER.md` version bumped.
- [x] `state/frozen-files.json` regenerated for the Charter v0.9 amendment.
- [x] Main `README.md` updated.

## Outcome

Automatic usage is SQLite-only; the UI has no old history fallback/parity/live path, and Settings measures the two SQLite files. UI target build, storage syntax check, and stale-reference scan passed. Full all-target build remains blocked by the known empty Linux service `main`; DB smoke reaches its unrelated pre-existing legacy migration idempotence failure.

Manual target-host smoke path: launch the service and app, use foreground/audio activity for at least 60 seconds, confirm rows appear in `frontmost_sessions`/`media_sessions`, and confirm neither retired usage JSON file is created or modified.
