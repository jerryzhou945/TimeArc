# Session - database-storage-owns-sqlite

Goal: Move all SQLite schema and statement operation out of `data_bridge.c`
and into `database_storage.*`.

Service side: service writers still call the public bridge ABI, but bridge
functions become thin validation/normalization wrappers around storage-owned
SQLite table operations.

UI side: no UI behavior changes; the UI continues to read the same
`timearc_service.db` tables through the disk contract.

Expected touched files: `src/service/shared/database_storage.h`,
`src/service/shared/database_storage.c`, `src/service/shared/data_bridge.c`,
`src/service/README.md`, `src/service/shared/usage_record.md`.

Files intentionally not touched: `src/service/shared/data_bridge.h`,
`database_path.*`, `usage_record.h`, `usage_record.schema.json`, and
`src/service/CMakeLists.txt`.

Rules checked: `rules/01-architecture.md`, `rules/03-data-contract.md`. No
disk schema change is intended.

Outcome: `database_storage.*` now owns schema creation, statements, binds, and
typed table writes. `data_bridge.c` only adapts the public bridge ABI to the
storage API. `python .harness/tools/build.py` passed.
