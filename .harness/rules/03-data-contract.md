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
`CHARTER` v0.8, and the service is its only writer. The service and UI resolve it
through the same control-file directory pointer, then append the locked filename.
The UI opens it read-only; a missing, empty, or unreadable database produces empty
history rather than consulting another source. The GUI's original `timearc.db` is
separate and GUI-only; it owns settings, tags, manual project state,
Android/mobile sync tables, and UI app metadata. No process writes the other
process's SQLite file.

## 1b. The control file

One UI-written, service-read JSON file carries the DB directory pointer and the collection
settings. **Only** sanctioned UI→service channel (I1): disk-only, read at service startup, never IPC.

**`service_config.json`** (`CHARTER` v0.13) in `<config base>/TimeArc/config/`
(`%APPDATA%`, `~/Library/Application Support`, `${XDG_CONFIG_HOME:-~/.config}`).
Versioned and namespaced; every key, range, and path: `src/service/README.md`
§Configuration File. `database.dir` carries the service-DB directory (D2; filename
stays locked to `timearc_service.db`); `tracking.*` the collection settings, idle
in **seconds**.

The service resolves the DB through shared `get_database_path`; the UI mirrors
that logic in `readConfigDbDirRaw`. **The two must stay in step or the processes
split-brain over where history lives.** Absent, unreadable, or malformed config
falls back to compile-time defaults. GUI "relocation" only writes the pointer — it
never copies, vacuums, restores, or writes `timearc_service.db`. Writes go through
`patchServiceConfig`, an atomic leaf-patching RMW that preserves every other key,
including sections this build does not know about.

**The retired `usage_config.json` is never read or written** — no fallback, no
mirror, no importer. Release-note consequence: an install that had relocated its
database loses the pointer and falls back to the platform default until the user
re-selects the directory in Settings; the old database is untouched on disk.
Retired spellings `db_dir`/`db_path` are dropped from the new file on the next
DB-location write. Key mapping, for anyone migrating by hand:
`db_dir` → `database.dir`; `track_enabled` → `tracking.enabled`;
`idle_threshold_ms` → `tracking.frontmost.idle_threshold_sec` (`round(ms/1000)`).

Implemented: UI writer + DB pointer; macOS reads every `tracking.*` key with
validation/newer-schema refusal; Windows reads `tracking.enabled` and frontmost
idle. Windows advanced leaves and all Linux reading remain pending. Proposals:
`journal/sessions/20260805-2143-B-service-config-v1.md`
(superseding H5 `20260609-0150` and D2 `20260610-1705`) + `20260806-0227-B-macos-service-config.md`.

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
