# Rule 03 — Data Contract

What ends up on disk and what the UI expects to read. The tightest
constraint in the project: it crosses both the process boundary (UI ↔
service) and the platform boundary (Windows C ↔ macOS Swift ↔ Linux TBD).

SQLite usage shape is locked by the table contract below. If code and this rule
disagree, the diff is a bug.

## 1. Files on disk

The service-owned SQLite history DB lives in the platform service-data directory:
- Windows: `%APPDATA%\TimeArc\service\timearc_service.db`.
- macOS: `~/Library/Application Support/TimeArc/service/timearc_service.db`.
- Linux: `${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db`.

| Filename                  | Writer                      | Reader         | Shape                               |
|---------------------------|-----------------------------|----------------|-------------------------------------|
| `timearc_service.db`      | service only                | UI read-only primary history | `apps(app_id, platform, display_name, icon_path, executable_path, created_at, updated_at)`, `frontmost_sessions(app_id, window_title, start_unix_sec, end_unix_sec, duration_sec generated, active_sec, idle_sec generated)`, `media_sessions(app_id, media_type, media_title, start_unix_sec, end_unix_sec, duration_sec generated)` |
| `timearc.db`              | GUI only                    | GUI            | settings/tags/manual/mobile/UI tables |

SQLite (`timearc_service.db`) is the UI's **only** history source as of
`CHARTER` v0.8, and the service is its only writer. The
service and UI resolve it through the same `usage_config.json` `db_dir` pointer,
then append the locked filename. The UI opens it read-only; a missing, empty, or
unreadable database produces empty history rather than consulting another source.
The GUI's original
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

## 2. Invariants

**D1. Service-owned history.** `timearc_service.db` is written only by the
service. The UI must open it read-only. Migrations are separate tools, run with
the service stopped and a backup available.

**D2. Session segmentation.** Logical identity is the complete normalized
observation, independent of platform. A `foreground` observation includes all
captured app-information fields and the window title; a `media` observation
includes all captured app-information fields, media type, and media title. If
every field is equal, the logical session continues. If any field differs, or
the service shuts down, the current logical session ends.

Input idle keeps the foreground session open and normally pauses `active_sec`.
If the foreground observation has video-like playback evidence, it remains
active regardless of input-idle duration. A missing media observation ends at
that sample; there is no silence grace period. Periodic persistence of
long-running media is optional: implementations may checkpoint or defer the
write, and checkpoint rows do not redefine logical identity. `duration_sec ==
0` records are dropped at the service.

**D4. UTF-8 everywhere.** Platform code must UTF-8-encode strings before
calling the functions declared by `data_bridge.h`; SQLite receives those
bridge strings.

**D5. UI read model.** `UsageStatManager` merges `foreground` and `audio`
intervals by union (simultaneous foreground + audio does not double-count
in the "active" view). Keep this semantics on refactor.

## 3. Changing anything in this rule

A data-contract change is a charter amendment (`CHARTER.md` §4) **and**
a track-B session. It requires a struct/DDL impact review and a migration note
in the session proposal. Compatible shape transitions should overlap for at
least one release; backend retirement requires a completed soak period.
