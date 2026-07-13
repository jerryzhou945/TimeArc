# Session - database-storage-api-names

Goal: Remove the `ta_` prefix from the shared database-storage API and add brief comments to its implementation and header.

Service side: the service keeps writing the same `timearc_service.db` tables through the shared SQLite layer; only the internal C function names become shorter.

UI side: no consumer behavior changes; the UI continues to read the same service-owned database shape.

Expected touched files: `src/service/shared/database_storage.h`, `src/service/shared/database_storage.c`, `src/service/shared/data_bridge.c`, `src/service/windows/storage/usage_storage.c`.

Rules checked: `rules/01-architecture.md`, `rules/03-data-contract.md`. No rule update is needed because the disk contract and process boundary do not change.

Files intentionally not touched: `data_bridge.h`, `usage_record.*`, `database_path.*`, and `src/service/CMakeLists.txt`.

Outcome: Renamed `ta_database_storage_*` to `database_storage_*`, added short ownership/schema comments, and updated C call sites. The first sandboxed build failed in Swift module-cache setup and was auto-recorded; the required escalated harness build passed.
