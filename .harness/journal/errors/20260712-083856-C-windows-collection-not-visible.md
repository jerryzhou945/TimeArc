# Error Report - windows-collection-not-visible

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-collection-not-visible
- Recorded: 2026-07-12T08:38:56Z
- Session: (unknown)
- Platform: Windows (user reproduction); Linux host static inspection
- Tooling: Source inspection of service SQLite DDL and UI read queries

## 1. What happened

On Windows, the app builds and runs but service-collected usage is not visible in the UI.

## 2. Evidence

```
Service schema: apps.app_id; frontmost_sessions.app_id/duration_sec;
media_sessions.app_id/duration_sec. Session tables have no explicit id.

UI queries: apps.app_identifier/app_name/app_icon_path;
frontmost_sessions.id/app_identifier/created_at;
media_sessions.id/app_identifier/playback_sec/created_at.

DatabaseManager also skips creating/opening the read-only connection when the
service DB does not exist during UI initialization, and periodic refresh does
not retry opening it.

User confirmed on Windows that `time-arc-service.exe` exists, `--status`
returns normal output, and `timearc_service.db` exists at the expected path.
Deployment, process discovery, and path resolution are therefore ruled out.
User subsequently confirmed that the service database contains no collected
rows, so writer failure or lack of a completed segment precedes the known UI
reader-schema failure.

User confirmed the Windows generator emits only
`build/time-arc-service.exe`, correctly beside `TimeArc.exe`; the proposed
development-output-location mismatch is ruled out.

Direct inspection of the copied `timearc_service.db`: valid SQLite, 4096 bytes,
one page, integrity OK, `journal_mode=wal`, `user_version=0`, and no schema
objects in the main file. The sibling `timearc_service.db-wal` was not copied.
Because the service enables WAL only from its lazy first-write path, foreground
sampling reached storage. Schema and committed rows may be entirely in the
missing WAL, so the standalone main-file copy cannot establish that the live
database is empty.

User inspected the live main/WAL/SHM database set and confirmed normal service
records. The producer, sampling loop, path resolution, and SQLite writes are
therefore healthy; failure is confined to the UI read path.
```

## 3. Root cause

- Immediate cause: UI service-history queries cannot execute against the schema created by `shared/database_storage.c`; the primary `sqliteMaxIds()` failure is returned without logging, presenting the SQL error as empty history.
- Writer-side finding: the service reached `open_connection()` and enabled WAL;
  inspect a WAL-consistent backup before concluding that inserts failed.
- Separate confirmed defect, ruled out for this fresh-boot reproduction:
  `idle_win.c` subtracts 32-bit `LASTINPUTINFO.dwTime` from 64-bit
  `GetTickCount64()`. After the 32-bit tick counter wraps at about 49.7 days,
  every poll is treated as idle and no foreground session starts.
- Underlying cause: The service database schema was changed without updating all UI consumers; initial database creation is also racy because the UI never retries a missing read-only connection. The idle detector separately mixes tick-counter widths.
- Why the harness/checklists did not prevent it: Existing DB smoke coverage builds the UI repositories but does not create a service-owned database with the writer DDL and query it through the UI read path.

## 4. Fix

- Files changed: `src/services/{database_manager,usage_stat_manager,frontmost_session_repository,media_session_repository}.*`, `tests/db_smoke.cpp`
- Short description: Aligned all UI service-history SQL with the locked schema, retained existing QVariant field names through aliases/column positions, used session `rowid` for incremental IDs, and allowed the read-only connection to open after first-run database creation.
- Commit: pending

## 5. Prevention

Add an integration smoke test that creates/writes `timearc_service.db` through the service storage API, then opens it through `DatabaseManager` and exercises every UI service-history query.
