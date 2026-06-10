# Session Log — d1-export-backup-restore-kickoff

> D1 kickoff/spec authored this session. No implementation code; planning only.

## Metadata

- Agent / Author: Claude (Opus 4.8) + maintainer
- Track: **B (Feature)** — D1 is the keystone-unblocked data-ops arc (`A1 → D1 → D2`).
- Date: 2026-06-10 14:26 → (local)
- Branch: dev (kickoff doc only; implementation sessions branch later)
- Baseline commit: 70c5779 (Merge PR #37, B1 Route A)

## Goal

Produce the D1 kickoff/spec doc that splits "SQLite 整库 导出/备份/恢复" into per-session
range cards, locking file red-lines, proposal boundary, invariants, risks, and acceptance.

## Plan

- Survey real state: existing exportReport (report JSON, not whole-DB), DatabaseManager, WAL, settings export tab.
- Confirm extension point + no-frozen-file path (fold into database_manager.{cpp,h}; no new TU → no frozen CMake).
- Write `docs/d1-export-backup-restore-kickoff.md` (A1 kickoff 7-section style).
- Sync pointers: implementation-backlog §D1, open-issues Storage, README §Roadmap.
- harness_check exit 0.

## What actually happened

- 14:26 — preflight `--track B` clean; harness_check clean baseline.
- Surveyed: `usage_stat_manager.cpp:1651` exportReport (Download→Documents cascade, short-write = honest fail);
  `database_manager.{h,cpp}` (QML ctx prop `databaseManager` at `main.cpp:137`; `getDatabasePath` :16;
  WAL pragma :75; `databasePath()` :84; **A1-S3 `backfillUsageFromJsonl` :447 = reusable .bak+txn+reconcile+
  idempotent-flag pattern**); `DesktopProfilePage.qml` 导入导出 tab (`doExport` :329, `doImport` :374,
  `askConfirm` danger :350, `FileDialog` :389, `clearUiCache` :366 注释已把整库备份/恢复标注为「D1」预留).
- Confirmed authorities: `rules/03` **D1 (Append-only history, :51-53) = migrations run service-stopped +
  produce a backup** — direct governing rule for restore; `CHARTER` §2 I1/I2/I5 + §3 frozen list; B1
  `Local\TimeArcStop` stop channel for restore coordination; `README.md:569` D1 roadmap line.
- Key design decisions locked in kickoff:
  - Backup = **`VACUUM INTO`** (WAL-consistent single-file snapshot), NOT `QFile::copy` (would miss `-wal`).
  - Fold all logic into `database_manager.{cpp,h}` (already in app sources) → **no new TU → no frozen CMake
    edit → no change proposal**. DB path from DatabaseManager, never frozen `usage_paths.c`.
  - **D1 does NOT touch I2** (backup = read-only copy; restore swaps file *content*, not schema/fields/path) —
    key difference vs A1-S4, so no charter amendment.
  - Staging: **S1 backup (MVP slice)** → **S2 inspect+restore (stop-service + .pre-restore.bak + restart)** →
    **S3 retention/auto-backup (future, not this round)**.
  - Honest-failure (G6) throughout: empty string / false + toast on any failure; never fake success.
- Authored `docs/d1-export-backup-restore-kickoff.md` (§0 现状校正 … §7 关系，7-section A1 style).
- Synced pointers: `implementation-backlog.md §D1` (`[ ]`→`[~]` + kickoff link), `open-issues.md` Storage
  (D1 pointer), `README.md:569` (kickoff link).

## Outcome

**done** (kickoff-only scope; implementation deferred to per-session S1→S2).

- Commits landed: (pending — docs-only)
- Files touched: `docs/d1-export-backup-restore-kickoff.md` (new), this session log (new),
  `docs/implementation-backlog.md`, `.harness/state/open-issues.md`, `README.md`.
- Frozen files touched: **n**. No change proposal needed (D1 has zero frozen-file edits; does not touch I2).
- Follow-ups: implement **S1 backup** next (per kickoff §2 range card); then S2 restore.

## Notes for the next agent

- Start S1 from the §2 S1 range card: `Q_INVOKABLE QString DatabaseManager::backupDatabase()` via
  `VACUUM INTO` → Download cascade → `timearc-backup-YYYYMMDD-HHMMSS.db`; settings button + toast.
- Do **not** use `QFile::copy` for backup (WAL miss). Do **not** add a new .cpp/.h (frozen CMake).
- Restore (S2) is the sensitive slice: must stop collection (`Local\TimeArcStop`) + self-backup + restart;
  reuse the `.bak`+rollback shape from `backfillUsageFromJsonl` (`database_manager.cpp:447`).
- Kill `TimeArc.exe` before any build (exe lock). Verify backups with `PRAGMA integrity_check` + 3-table rows.
