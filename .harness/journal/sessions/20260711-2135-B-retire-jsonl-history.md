# Change Proposal — retire-jsonl-history

## Metadata

- Author: `/root`
- Track: **B (Feature)**
- Date: 2026-07-11 21:35 (Asia/Shanghai)
- Session goal: Retire JSONL usage history so `timearc_service.db` is the sole historical store while JSON remains only for service configuration and the live snapshot.
- Branch: `development/macos-support` (user-directed override of the normal feature-branch rule)
- Related error reports: `errors/20260711-133736-B-missing-dev-branch.md`, `errors/20260711-133801-B-git-readonly-branch.md`

## 1. Frozen files touched

- `.harness/CHARTER.md` — remove JSONL history and fallback from invariant I2 and bump the charter version.
- `.harness/AGENTS.md` — update the project summary to the SQLite-history architecture.
- `src/service/shared/usage_record.h` — describe the normalized session as SQLite/live input instead of JSONL output.
- `src/service/shared/usage_record.schema.json` — narrow the JSON disk schema to the live snapshot and require its live metadata.
- `src/service/shared/database_path.c` — update the service-data directory comment after retiring the legacy history stream.

Expected non-frozen implementation scope: Windows storage context/writer, `UsageStatManager`, settings QML, active contract/rule docs, README, backlog, and completion report. Historical session/error documents remain immutable history.

## 2. Motivation

SQLite migration S1–S4 is complete and `timearc_service.db` is already the primary UI history source. Continuing to write and read `usage_records.jsonl` duplicates history, preserves a non-transactional partial-write path, and keeps obsolete fallback/parity code alive. This session completes migration step S5 at the user's direction.

## 3. Impact on the other process

Service side: completed foreground/media sessions are written only to `timearc_service.db`; `usage_current.json` and `usage_config.json` remain unchanged. UI side: history is read only from the read-only service DB; no JSONL fallback, source override, or dual-source parity API remains.

| Side | Effect |
| --- | --- |
| Producer | Removes JSONL file creation, append handles, flags, and dual-write sequencing. |
| Consumer | Removes JSONL parsing/fallback and reports service DB size in Settings. |

## 4. Migration plan

Old releases may leave `usage_records.jsonl` beside `usage_current.json`. New code neither reads, writes, nor deletes that file. Existing SQLite data remains unchanged; no schema or DDL migration is needed because dual-write/backfill already shipped. Automatic deletion is intentionally avoided so an upgrade cannot destroy history that failed to reach SQLite.

## 5. Rollback plan

A code revert restores JSONL dual-write/fallback behavior. Existing legacy JSONL files are untouched, and SQLite data needs no rollback.

## 6. Test plan

- Pre-change: service initializes JSONL and SQLite; UI exposes JSONL fallback/parity code.
- Post-change: build through the harness; run DB smoke tests; verify no active implementation or contract reference to usage-history JSONL remains; confirm live/config JSON code remains.
- New test artifacts: completion report and existing database smoke coverage.

## 7. Sign-off

- [x] `rules/01-architecture.md`, `rules/02-platform-boundaries.md`, `rules/03-data-contract.md`, and `rules/04-ui-conventions.md` updated.
- [x] `.harness/CHARTER.md` version bumped.
- [x] `state/frozen-files.json` regenerated for the Charter v0.8 amendment.
- [x] Main `README.md` updated.

## Outcome

Service history is SQLite-only; the UI has no old history fallback/parity path, and Settings measures the two SQLite files. UI target build, storage syntax check, schema validation, and stale-reference scan passed. Full all-target build remains blocked by the known empty Linux service `main`; DB smoke reaches its unrelated pre-existing legacy migration idempotence failure.

Manual target-host smoke path: launch the service and app, use foreground/audio activity for at least 60 seconds, confirm rows appear in `frontmost_sessions`/`media_sessions`, confirm live state updates, and confirm no old history file is created or modified.
