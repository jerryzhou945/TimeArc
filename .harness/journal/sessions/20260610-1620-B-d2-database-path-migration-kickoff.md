# Session Log — d2-database-path-migration-kickoff

> D2 kickoff/spec authored + D1 completion audited. No implementation code.

## Metadata

- Agent / Author: Claude (Opus 4.8) + maintainer
- Track: **B (Feature)** — D2 is the next data-ops arc after D1 (`A1 → D1 → D2`).
- Date: 2026-06-10 16:20 → (local)
- Branch: feat/d2-database-path-migration (off origin/dev; D1 #40 unmerged → the
  d1-kickoff link + backlog §D1 read stale on this base until #40 merges)
- Baseline commit: 70c5779 (origin/dev, PR #37)

## Goal

Audit D1 completion, then author the D2 kickoff/spec (user-selectable DB path + safe
migration) splitting it into per-session range cards with the proposal/gating boundary.

## What actually happened

- D1 audit: 3 impl commits on PR #40 (DatabaseManager backup/inspect/restore + Settings UI +
  db_smoke). Code read vs kickoff spec — faithful: `backupDatabase` VACUUM INTO + literal escape
  + artifact verify; `inspectBackup` read-only scoped + integrity + 3-table assertion + counts;
  `restoreDatabase` inspect-gate + `.pre-restore.bak` + close/removeDatabase + lock-detection +
  `-wal/-shm` cleanup + reopen + `databaseRestored` + rollback paths. QML "数据库备份与恢复" card.
  db_smoke D1 round-trip + bad-file + missing-tables cases. Impl session log records db_smoke
  exit 0 + real-machine backup (20.8 MB, integrity ok, apps=51/front=31892/media=21823==source).
  harness_check exit 0; zero frozen files; PR #40 OPEN/MERGEABLE/CLEAN. **Verdict: S1+S2 done;**
  honest known gap = no in-app one-click collection stop (restore needs manual stop); S3 deferred.
- D2 survey: db path computed in TWO non-frozen files — service `usage_storage.c::make_db_path:59`
  (getenv APPDATA, no override hook) + UI `database_manager.cpp::databasePath:84`. `usage_paths.{h,c}`
  (frozen) does NOT carry the db path. But CHARTER **I2** documents the db path as an invariant →
  user-selectable path needs a CHARTER amendment. Crux = both processes must read a durable
  cross-process pointer; it can't live in the movable db → lands in `usage_config.json` (the H5
  service-config channel, proposal pending sign-off). So D2 is GATED: change proposal + I2 amend +
  service build pipeline; couples to H5.
- Authored `docs/d2-database-path-migration-kickoff.md` (7-section A1/D1 style). Staging:
  S1 cross-process pointer (+I2 amend, gated) → S2 UI migration flow (reuses D1 primitives) →
  S3 presets/revert/drive-guards (future). Synced `implementation-backlog §D2` ([ ]→[~] + kickoff
  link + gating note) and `README.md` D2 roadmap line.

## Outcome

**done** (kickoff-only; D2 implementation gated — see §1 of the kickoff).

- Files touched: `docs/d2-database-path-migration-kickoff.md` (new), this session log (new),
  `docs/implementation-backlog.md`, `README.md`.
- Frozen files touched: **n** (the kickoff itself touches none; D2-S1 *implementation* will need a
  CHARTER I2 amendment + change proposal — not done here).
- Follow-ups: file/merge the D2 db-path-pointer change proposal (with H5's service-config channel)
  for maintainer sign-off BEFORE any D2-S1 code.

## Notes for the next agent

- Do NOT start D2-S1 code until: CHARTER I2 amendment signed + service-config channel signed +
  service build/test pipeline available. The immediate next artifact is the change proposal.
- The db-path pointer MUST be read identically by UI `databasePath()` and service `make_db_path`,
  with fail-safe fallback to the default convention path; never split-brain.
- D2's migration mechanics reuse D1 (`database_manager.cpp:735`): stop-coordination, VACUUM INTO /
  copy + `-wal/-shm`, `inspectBackup` validation, `.pre-restore.bak` rollback.
