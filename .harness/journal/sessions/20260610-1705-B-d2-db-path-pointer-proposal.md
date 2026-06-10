# Change Proposal — d2-db-path-pointer

> Filed per CHARTER §3/§4 before the D2 I2 amendment. Covers D2-S1: a user-selectable SQLite DB
> path via a durable cross-process pointer. Reuses the `usage_config.json` UI→service channel
> proposed in H5 (`20260609-0150-B-service-config-proposal.md`).

## Metadata

- Author: Claude Code (Opus 4.8)
- Track: **B (Feature)** — extends the disk contract + amends CHARTER I2 (a feature gate, per
  `tracks/README.md`).
- Date: 2026-06-10 17:05 (local)
- Session goal: Propose a durable two-process db-path pointer (`usage_config.json` `db_path`) +
  the CHARTER I2 amendment that lets `timearc.db` live at a user-chosen path — without bypassing
  the disk contract (I1) or risking split-brain.
- Branch: feat/d2-database-path-migration
- Related: `docs/d2-database-path-migration-kickoff.md`; H5 service-config proposal
  `20260609-0150-B-service-config-proposal.md` (same channel); D1 kickoff (migration primitives);
  CHARTER I2 (db-path invariant).

## 1. Frozen files touched

- `.harness/CHARTER.md` — **I2 amendment**: the SQLite path changes from a fixed
  `%APPDATA%\TimeArc\TimeArc\timearc.db` to "**default** that path, **redirectable** via the
  `db_path` key in `usage_config.json`; both processes read the same pointer and fail-safe to the
  default when it is absent/unreadable." Bump version **v0.2 → v0.3**.
- `state/frozen-files.json` — regenerated after the CHARTER edit lands.
- **NOT touched**: `usage_paths.{h,c}` (frozen) — the db path is built in NON-frozen
  `usage_storage.c::make_db_path:59` (service) + `database_manager.cpp::databasePath:84` (UI), so
  no frozen path-accessor change. `src/service/CMakeLists.txt` (frozen) NOT touched — the JSON read
  folds into existing `main.c`/`usage_storage.c` (no new translation unit). Filed because it
  amends I2.

## 2. Motivation

The SQLite DB path is hardcoded in two independent places (service `make_db_path` from
`getenv(APPDATA)`; UI `databasePath` from `QStandardPaths::AppDataLocation`). Users cannot
relocate their data — a larger/external drive, a synced folder, a different volume. D1 ships
whole-DB backup/restore but no relocation. A user-selectable location is the D2 backlog item and a
natural follow-on to D1.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer (service) | `make_db_path` first reads `<usageDir>/usage_config.json` `db_path`; if non-empty and its parent is creatable/writable, uses it, else falls back to the computed default. Disk-only read; no record-schema change. |
| Consumer (UI) | `databasePath()` reads the same `db_path` key identically (single source of truth). The D2-S2 migration flow WRITES the key during a relocation. UI→service is **disk-only — no IPC/socket/shm** (honors I1). |

The pointer lives in `usage_config.json` in the **fixed** usage dir (NOT inside the movable DB —
chicken-and-egg). This is the SAME channel H5 proposes; **joint sign-off recommended**.

## 4. Migration plan

- No reinterpretation of existing records. `db_path` is new + optional: absent → default path
  (today's behavior). Fully backward compatible.
- Relocation (D2-S2, UI): stop collection (B1 `Local\TimeArcStop`) → `VACUUM INTO`/copy the DB +
  `-wal`/`-shm` to the new dir → **atomically write `db_path`** → restart both processes → keep
  the old DB until the new one passes `inspectBackup` → on any failure revert the pointer + keep
  the old DB (never split-brain; reuses D1 primitives).

## 5. Rollback plan

- Code revert restores the hardcoded path. To revert a relocation: clear/delete the `db_path` key
  → both processes return to the default path (provided the DB actually sits there; else the
  fail-safe leaves the user on the default path **with a warning, no data loss** — the moved DB
  still exists at the chosen path). The pre-move backup allows a manual restore.

## 6. Test plan

- Pre: DB path hardcoded; no way to relocate; setting a path has no effect.
- Post (service smoke, **REQUIRES the service build pipeline**): `db_path` set → service opens the
  new path; absent → default; bad/unwritable → default + warning. UI: `databasePath()` honors the
  pointer; round-trip relocation (default → custom → revert) with both processes following and
  numbers intact.
- Artifacts: a sample `usage_config.json` with `db_path`; a service smoke covering the 3 cases.
- **NOTE:** the service is a separate C process — NOT verifiable in the qml build loop.

## 7. Sign-off

- [ ] `rules/03-data-contract.md` updated: db path is redirectable via `usage_config.json db_path`,
      read identically by both processes, fail-safe to default.
- [ ] `CHARTER.md` I2 amended + version bumped **v0.2 → v0.3**.
- [ ] `state/frozen-files.json` regenerated after the CHARTER edit.
- [ ] `README.md` (Data Location + Roadmap) updated when implemented.
- [ ] **Joint sign-off with H5** (shared `usage_config.json` channel) recommended; if H5 lands
      first, D2 only adds the `db_path` key + the two reads + the I2 amendment.

**Status: PROPOSED — awaiting maintainer sign-off. NOT implemented;** D2-S1 code does not land
until this proposal + the service build pipeline are approved.
