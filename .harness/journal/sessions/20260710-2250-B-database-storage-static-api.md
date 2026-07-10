# Session - database-storage-static-api

Goal: Keep `database_storage.*` exports limited to functions required outside
the storage implementation.

Service side: make storage-only helpers file-local while preserving the
existing service write path and SQLite transaction behavior.

UI side: no UI behavior changes; the on-disk service database contract is
unchanged.

Expected touched files: `src/service/shared/database_storage.h`,
`src/service/shared/database_storage.c`.

Files intentionally not touched: `src/service/shared/data_bridge.h`,
`database_path.*`, `usage_record.*`, and CMake files.

Rules checked: `rules/01-architecture.md`, `rules/03-data-contract.md`.

Outcome: removed the exported `database_storage_error` API and replaced it
with a `static` helper in `database_storage.c`. Lifecycle and transaction
functions remain exported because Windows storage still calls them directly.
`python .harness/tools/build.py` passed.
