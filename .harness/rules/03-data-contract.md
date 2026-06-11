# Rule 03 — Data Contract

What ends up on disk and what the UI expects to read. The tightest
constraint in the project: it crosses both the process boundary (UI ↔
service) and the platform boundary (Windows C ↔ macOS Swift ↔ Linux TBD).

The canonical schema is `src/service/shared/usage_record.schema.json`. This
file is a human summary; if the two disagree, the schema wins and the diff
is a bug.

## 1. Files on disk

Root directory from `usage_paths.c`:
- Windows: `%LOCALAPPDATA%\TimeArc\usage\`, fallback `%APPDATA%\TimeArc\usage\`.
- Unix: `~/.timearc/usage/`.

| Filename                  | Writer                      | Reader         | Shape                               |
|---------------------------|-----------------------------|----------------|-------------------------------------|
| `timearc.db`              | service + UI SQLite writers  | **UI (primary history read)** | app/session/settings tables (SQLite) |
| `usage_records.jsonl`     | service (append)            | UI fallback / import | one JSON record per line, UTF-8 |
| `usage_current.json`      | service (atomic overwrite)  | UI (poll read) | single JSON record + `live`, `updated_unix_sec` |

SQLite (`timearc.db`) is the UI's **primary** history source as of A1
(`CHARTER` v0.2). The Qt app uses `QStandardPaths::AppDataLocation`; the Windows
service mirrors that path as `%APPDATA%\TimeArc\TimeArc\timearc.db`. The service
still **dual-writes** JSONL (append-only) as a fallback, and the UI falls back
to JSONL when the DB is missing/empty (and can be forced via
`TIMEARC_USAGE_SOURCE=jsonl`). The live snapshot stays JSON (no SQLite
equivalent). Canonical shared-table DDL is owned by `database_manager.cpp`; the
service inline DDL must stay column-compatible (asserted by `tests/db_smoke.cpp`).
The enable-before JSONL tail was backfilled once into SQLite (idempotent,
`usage_jsonl_backfill_v1_done`). JSONL retirement is a future milestone (A1 S5).

**DB path (D2, `CHARTER` v0.3).** The `timearc.db` path above is the **default** and is
**redirectable** to a user-chosen location via the `db_path` key in `usage_config.json`,
read identically by the service (`make_db_path`) and the UI (`databasePath`), with a
fail-safe fallback to the default when absent/unreadable. Relocation runs with the
service stopped and keeps a backup (see invariant D1).

**Service config (H5, `CHARTER` v0.4).** `usage_config.json` also carries two UI→service behavior keys
the service reads at startup (`timearc_read_service_config`): `idle_threshold_ms` (int;
fills `TimeArcUsageTrackerConfig.idle_threshold_ms`, clamped 1s–24h) and `track_enabled`
(bool; `false` = the service collects nothing and self-exits — a *true pause*, never a
deletion). The UI writes them via `DatabaseManager::writeServiceConfig`; both the D2
db_path writer and the H5 idle/track writer share one atomic read-modify-write
(`mergeUsageConfig`) that preserves the other's keys. Absent/invalid keys → compile-time
defaults (fail-safe = today's behavior). This is a sanctioned UI→service direction over
the same disk channel D2 opened (no IPC; honors I1) and supersedes the earlier
A-TRACKPAUSE UI-only approximation. Proposal:
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
