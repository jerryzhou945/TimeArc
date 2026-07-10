# TimeArc Background Service

TimeArc uses separate service implementations per platform, but all of them
write the same service-owned history database and live usage protocol.

- `shared/`: shared protocol, app snapshots, environment interfaces, SQLite
  database storage, and path helpers.
- `windows/`: Windows implementation in C using Windows API.
- `macos/`: macOS implementation scaffold in Swift.

The service SQLite database is resolved by `shared/database_path.*`. Its
locked filename is `timearc_service.db`. `shared/database_storage.*` owns the
SQLite connection, schema, statements, transactions, and table writes.
`shared/data_bridge.c` is only the public bridge wrapper around that storage
API. The Qt app opens that database read-only for history. JSONL
`usage_records.jsonl` remains a fallback stream, and `usage_current.json`
remains the live snapshot.

The database has exactly three service-owned tables:

- `apps`: `app_id`, `platform`, `display_name`, `icon_path`,
  `executable_path`, `created_at`, `updated_at`.
- `frontmost_sessions`: `app_id`, `window_title`, `start_unix_sec`,
  `end_unix_sec`, generated `duration_sec`, `active_sec`, generated `idle_sec`.
- `media_sessions`: `app_id`, `media_type`, `media_title`, `start_unix_sec`,
  `end_unix_sec`, generated `duration_sec`.

The JSONL fallback records are described in `shared/usage_record.md` and
validated by `shared/usage_record.schema.json`.
