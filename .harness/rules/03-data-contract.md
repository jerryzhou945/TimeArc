# Rule 03 — Data Contract

What ends up on disk and what the UI expects to read. The tightest
constraint in the project: it crosses both the process boundary (UI ↔
service) and the platform boundary (Windows C ↔ macOS Swift ↔ Linux TBD).

The canonical schema is `src/service/shared/usage_record.schema.json`. This
file is a human summary; if the two disagree, the schema wins and the diff
is a bug.

## 1. Files on disk

The service-owned SQLite history DB lives in the platform service-data directory:
- Windows: `%APPDATA%\TimeArc\service\timearc_service.db`.
- macOS: `~/Library/Application Support/TimeArc/service/timearc_service.db`.
- Linux: `${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db`.

| Filename                  | Writer                      | Reader         | Shape                               |
|---------------------------|-----------------------------|----------------|-------------------------------------|
| `timearc_service.db`      | service only                | UI read-only primary history | `apps(app_id, platform, display_name, icon_path, executable_path, created_at, updated_at)`, `frontmost_sessions(app_id, window_title, start_unix_sec, end_unix_sec, duration_sec generated, active_sec, idle_sec generated)`, `media_sessions(app_id, media_type, media_title, start_unix_sec, end_unix_sec, duration_sec generated)` |
| `timearc.db`              | GUI only                    | GUI            | settings/tags/manual/mobile/UI tables |
| `usage_records.jsonl`     | service (append)            | UI fallback / import | one JSON record per line, UTF-8 |
| `usage_current.json`      | service (atomic overwrite)  | UI (poll read) | single JSON record + `live`, `updated_unix_sec` |

SQLite (`timearc_service.db`) is the UI's **primary** history source as of A1
(`CHARTER` v0.2), but as of `CHARTER` v0.6 the service is its only writer. The
service and UI resolve it through the same `usage_config.json` `db_dir` pointer,
then append the locked filename. The UI opens it read-only and falls back to JSONL
when the DB is missing/empty (and can be forced via `TIMEARC_USAGE_SOURCE=jsonl`).
The live snapshot stays JSON (no SQLite equivalent). The GUI's original
`timearc.db` is separate and GUI-only; it owns settings, tags, manual project
state, Android/mobile sync tables, and UI app metadata. No process writes the
other process's SQLite file.

**DB path (D2, `CHARTER` v0.5).** The filename is locked to
`timearc_service.db`; only the containing directory is configurable via
`usage_config.json` `db_dir`. The service resolves it through shared
`get_database_path`, and the UI mirrors the same config-first logic for its
read-only service-history connection. Absent, unreadable, malformed, or empty
`db_dir` falls back to the default. A non-empty configured `db_dir` wins; actual
open/create failures surface at database-open time. GUI "relocation" only writes
the `db_dir` pointer; it never copies, vacuums, restores, or writes
`timearc_service.db`. The old `db_path` key is ignored and removed by the next
UI DB-location write.

**Service config (H5, `CHARTER` v0.4).** `usage_config.json` also carries
`idle_threshold_ms` (clamped 1s-24h) and `track_enabled` (`false` = service
self-exits, no deletion). The UI writes them via
`DatabaseManager::writeServiceConfig`; D2 and H5 share `mergeUsageConfig`, an
atomic RMW that preserves the other's keys. Absent/invalid keys use compile-time defaults; the channel is disk-only and honors I1. Proposal:
`journal/sessions/20260609-0150-B-service-config-proposal.md`.

## 2. Record shape

| Field              | Type     | Req. | Notes                                                      |
|--------------------|----------|------|------------------------------------------------------------|
| `platform`         | string   | yes  | `"windows" | "macos"` (add to enum when implementing Linux) |
| `source`           | string   | no   | `"foreground" | "audio"` — absent == `foreground`          |
| `app_id`           | string   | yes  | Stable identity. Win: exe path. macOS: bundle id.          |
| `app_name`         | string   | yes  | Short name (`chrome.exe`, `Safari`).                       |
| `window_title`     | string   | yes  | May be empty for `audio` source.                           |
| `path`             | string   | yes  | Full exe/bundle path.                                      |
| `start_unix_sec`   | integer  | yes  | Unix seconds.                                              |
| `duration_sec`     | integer  | yes  | `>= 0`.                                                    |
| `live`             | int 0/1  | live | Only in `usage_current.json`.                              |
| `updated_unix_sec` | integer  | live | Only in `usage_current.json`.                              |

## 3. Invariants

**D1. Append-only history.** `usage_records.jsonl` is only appended by the
service. The UI must not rewrite it. Migrations are separate tools, run with
the service stopped, producing a backup.

**D2. Session segmentation.** `foreground` segments on `app_id` or
`window_title` change, on idle, on shutdown. `audio` segments on app change,
on silence > `TIMEARC_AUDIO_SILENCE_GRACE_SEC` (3 s), and every
`TIMEARC_AUDIO_FLUSH_INTERVAL_SEC` (15 s) for long runs. `duration_sec == 0`
records are dropped at the service.

**D3. Atomic live snapshot.** `usage_current.json` is always written to
`<path>.tmp` then renamed. Do not read it for history — UI filters on the
`live: 1` marker.

**D4. UTF-8 everywhere.** Platform code must UTF-8-encode strings before
calling `ta_write_usage_record*`. Storage escapes but does not yet validate
UTF-8 (see `TODO` in `usage_storage.c` / `write_json_string`). New platforms
that cannot trivially produce UTF-8 must address this TODO first (track C).

**D5. UI read model.** `UsageStatManager` merges `foreground` and `audio`
intervals by union (simultaneous foreground + audio does not double-count
in the "active" view). Keep this semantics on refactor.

## 4. Changing anything in this rule

A data-contract change is a charter amendment (`CHARTER.md` §4) **and**
a track-B session. It requires: schema update, struct update in
`usage_record.h`, writing both old and new shape for at least one release,
and a migration note in the error journal or a dedicated upgrade doc.

SQLite migration steps are owned by `tracks/B-feature.md`.
