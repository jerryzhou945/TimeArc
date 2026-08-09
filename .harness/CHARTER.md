# TimeArc Project Charter

The invariants. The things that must not silently change.

## 1. What TimeArc is

Two processes, by design:

| Process           | Binary              | Lang            | Role                                       |
|-------------------|---------------------|-----------------|--------------------------------------------|
| UI                | `TimeArc`           | C++ (Qt6) + QML | User-facing; reads journal, runs timers.   |
| Background service| `time-arc-service`  | C (Win/Linux) + Swift (macOS) | Samples foreground + audio, writes journal. |

**UI↔service**: files on disk plus CLI invocation only — no IPC/sockets/shared memory
between them; files in `rules/03-data-contract.md`. IPC **between `time-arc-service`
instances** is allowed (§5 v0.14); that channel refuses any peer that is not the same executable.

## 2. Invariants

**I1. Two-process separation.** UI does not sample. Service does not draw. The UI drives the
service only by invoking its CLI and by writing the one sanctioned control file it reads at
startup — `service_config.json` (§5 v0.13, spec in `src/service/README.md`) — disk-only; it must
not link service code, register the launch agent, or use the control channel. A single service is
guaranteed by a named mutex (`Local\TimeArcUsageService`, Windows) or a per-user `flock` (macOS).

**I2. Data contract on disk.** The service writes automatic usage exclusively
to SQLite `timearc_service.db` (only tables
`apps`/`frontmost_sessions`/`media_sessions`; service is the only writer).
The UI opens `timearc_service.db` read-only for history. The GUI writes its own SQLite
`timearc.db` for settings/tags/manual projects/mobile sync/UI state; the service
never reads or writes it. Service SQLite filename is locked; its directory
defaults to the platform service-data dir (`%APPDATA%\TimeArc\service`,
`~/Library/Application Support/TimeArc/service`,
`${XDG_DATA_HOME:-~/.local/share}/TimeArc/service`) and is redirectable via the control
file's directory pointer, `service_config.json` `database.dir`
(service and UI append `timearc_service.db`; UI only writes the pointer, never the DB). Other paths from `database_path.c`. A field
rename/type change, a service-table DDL change, or a file move requires a charter
amendment + migration plan.
Foreground idle stays in the current segment without increasing `active_sec`, unless video-like foreground playback overrides input idle; generated `idle_sec` records the difference. On every platform, complete normalized foreground and media observations define logical identity: all fields equal continues the session, while any changed field creates a boundary. Missing media ends immediately without silence grace; periodic media persistence checkpoints are optional and do not change logical identity.
**I3. C ABI as cross-language bridge.** `src/service/shared/data_bridge.h`
is `extern "C"` and uses `swift_name`. Adding a function is allowed.
Changing an existing signature requires a charter amendment.

**I4. Platform isolation under `src/service/`.** `windows/` compiles only
on WIN32; `macos/` only on APPLE; `linux/` only on UNIX-non-APPLE. Shared
code in `src/service/shared/` must not include a platform-specific header.

**I5. Storage backend pluggability.** The storage layer is all-or-nothing
across enabled backends: any failure = whole write fails. Do not introduce
partial-write behavior.

**I6. Licensing posture.** Project is GPL-3.0-or-later. Qt is LGPL and
**must** be dynamically linked in release builds; third-party license texts
must be reachable from the UI. New deps must be GPL-compatible and
documented in `rules/06-licensing.md`.

## 3. Frozen files

Editing any file in this list requires filing a change proposal at
`journal/sessions/YYYYMMDD-HHMM-<slug>.md` **before** the edit lands.
`tools/harness_check.py` will verify content hashes against
`state/frozen-files.json`.

- `src/service/shared/data_bridge.h`
- `src/service/shared/database_path.h`
- `src/service/shared/database_path.c`
- `src/service/shared/app_info.h`
- `src/service/shared/app_env.h`
- `src/include/util.h`
- `CMakeLists.txt` (top-level)
- `src/CMakeLists.txt`
- `src/service/CMakeLists.txt`
- `.harness/CHARTER.md` (this file)
- `.harness/AGENTS.md`
- `AGENTS.md` (project root — Codex CLI entry shim)

The list may grow as the project stabilizes; it may shrink only through a charter amendment.

## 4. Amendment procedure

A charter amendment is a commit that edits this file (and, if applicable,
a rule file), accompanied by a `journal/sessions/*.md` capturing motivation,
concrete breakage prevented, and — if I2 is touched — data migration plan.
Bump the version below.

## 5. Charter version

- **v0.1** — initial draft (`0.1`, 33 commits): Windows tracker end-to-end; macOS primitives only; Linux stub empty.
- **v0.2** — A1 SQLite primary-source migration: `timearc.db` primary history + JSONL fallback. Proposal: `journal/sessions/20260609-1614-B-a1-sqlite-storage-migration-kickoff.md`.
- **v0.3** — D2 user-selectable DB path via `usage_config.json` `db_path`. Proposal: `journal/sessions/20260610-1705-B-d2-db-path-pointer-proposal.md`.
- **v0.4** — H5 service config keys `idle_threshold_ms` + `track_enabled`. Proposal: `journal/sessions/20260609-0150-B-service-config-proposal.md`.
- **v0.5** — Lock service DB filename and replace `db_path` with `db_dir`. Proposal: `journal/sessions/20260709-0014-B-db-dir-service-db.md`.
- **v0.6** — Split SQLite ownership: service `timearc_service.db`, GUI `timearc.db`. Proposal: `journal/sessions/20260709-0037-B-split-service-gui-dbs.md`.
- **v0.7** — Rename DB-path resolver files to `database_path.*`; no on-disk change. Proposal: `journal/sessions/20260709-1727-B-database-path-rename.md`.
- **v0.8–v0.9** — Retire JSONL usage history and then the JSON live snapshot and schema; `timearc_service.db` is the sole historical store, JSON remains config only, and automatic usage crosses the process boundary through the DB alone. Proposal: `journal/sessions/20260711-2135-B-retire-jsonl-history.md`.
- **v0.10** — Retire the unused aggregate usage-record header; the table-specific `data_bridge.h` API and SQLite schema are the service contract. Proposal: `journal/sessions/20260712-2043-B-retire-usage-record-contract.md`.
- **v0.11** — Keep foreground sessions open across idle intervals; paused active time is represented by generated `idle_sec`. Proposal: `journal/sessions/20260718-1619-B-idle-continuity-contract.md`.
- **v0.12** — Define portable full-observation session identity, video-over-idle foreground behavior, immediate media absence, and optional media checkpointing. Proposal: `journal/sessions/20260723-1653-B-tracking-session-semantics.md`.
- **v0.13** — Approve the redesigned control file `service_config.json` v1 (versioned, namespaced, seconds-based; adds sampling period, min/max session length, frontmost/media sub-switches) superseding `usage_config.json`; config dir moves to `TimeArc/config/`. Spec in `src/service/README.md`. **Clean break, no fallback**: the retired file is never read or written, so an install that had relocated its DB falls back to the default until the user re-selects the directory. UI writer + DB pointer implemented; the service-side tracking reader is pending (backlog A3). Proposal: `journal/sessions/20260805-2143-B-service-config-v1.md`.
- **v0.14** — Permit IPC **between `time-arc-service` instances** (a per-user unix socket beside the instance lock) while UI↔service stays disk + CLI; the service, not the UI, now owns launch-agent registration and start/stop, and the macOS agent restarts only on unsuccessful exit so `stop` is distinct from `disable`. Proposal: `journal/sessions/20260807-1423-B-macos-service-lifecycle.md`.
