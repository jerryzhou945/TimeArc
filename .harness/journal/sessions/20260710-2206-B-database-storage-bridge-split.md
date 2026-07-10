# Session - database-storage-bridge-split

Goal: Reconstruct the shared SQLite split so `database_storage.*` is low-level only and `data_bridge.c` owns service-table logic.

Service side: the service still writes `apps`, `frontmost_sessions`, and `media_sessions`, but bridge code now owns DDL and row semantics while storage only wraps SQLite operations.

UI side: no behavior changes; the UI reads the same `timearc_service.db` tables.

Expected touched files: `src/service/shared/database_storage.h`, `src/service/shared/database_storage.c`, `src/service/shared/data_bridge.c`, `src/service/windows/storage/usage_storage.c`, `src/service/README.md`, `src/service/shared/usage_record.md`.

Rules checked: `rules/01-architecture.md`, `rules/03-data-contract.md`. No rule update is needed because the disk shape is unchanged.

Files intentionally not touched: `src/service/shared/data_bridge.h`, `database_path.*`, and `src/service/CMakeLists.txt`.

Outcome: Rebuilt `database_storage.*` as a low-level SQLite wrapper, moved schema and table write logic into `data_bridge.c`, kept Windows storage as a record-to-bridge mapper with transaction boundaries, and documented the split. `python .harness/tools/build.py` passed.
