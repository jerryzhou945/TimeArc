# TimeArc Project Charter

The invariants. The things that must not silently change.

## 1. What TimeArc is

Two processes, by design:

| Process           | Binary              | Lang            | Role                                       |
|-------------------|---------------------|-----------------|--------------------------------------------|
| UI                | `TimeArc`           | C++ (Qt6) + QML | User-facing; reads journal, runs timers.   |
| Background service| `time-arc-service`  | C (Win/Linux) + Swift (macOS) | Samples foreground + audio, writes journal. |

They communicate **exclusively via files on disk** — no IPC, sockets,
shared memory. See `rules/03-data-contract.md` for the files.

## 2. Invariants

**I1. Two-process separation.** UI does not sample. Service does not draw.
The UI may start the service (`src/main.cpp::startUsageService`) but must
not link its code. A single service is guaranteed by a named mutex
(`Local\TimeArcUsageService` on Windows); new platforms must do the same.

**I2. Data contract on disk.** The record schema is
`src/service/shared/usage_record.schema.json`. The service writes history to
**two** backends: the SQLite database `timearc.db` (**primary**; tables
`apps`/`frontmost_sessions`/`media_sessions`, canonical DDL owned by
`src/services/database_manager.cpp`, which the service inline DDL must stay
column-compatible with — UI DDL pinned by `tests/db_smoke.cpp`, service DDL
kept in lockstep manually) and `usage_records.jsonl` (append-only, retained as
a fallback safety net). Live: `usage_current.json` (atomic overwrite). The UI
reads history from `timearc.db` as its **primary source**, falling back to JSONL
when the DB is missing/empty. SQLite path **defaults** to
`%APPDATA%\TimeArc\TimeArc\timearc.db` (service `make_db_path` + UI
`QStandardPaths::AppDataLocation`, independent but identical), and is **redirectable**
via `usage_config.json` `db_path` (both read one pointer; fail-safe to default when
absent/unreadable; D2 proposal `20260610-1705`). Other paths from `usage_paths.c`. A field
rename/type change, a shared-table DDL change, or a file move requires a charter amendment + migration plan.

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
- `src/service/shared/usage_record.h`
- `src/service/shared/usage_record.schema.json`
- `src/service/shared/usage_paths.h`
- `src/service/shared/usage_paths.c`
- `src/service/shared/app_info.h`
- `src/service/shared/app_env.h`
- `src/include/util.h`
- `CMakeLists.txt` (top-level)
- `src/CMakeLists.txt`
- `src/service/CMakeLists.txt`
- `.harness/CHARTER.md` (this file)
- `.harness/AGENTS.md`
- `AGENTS.md` (project root — Codex CLI entry shim)

The list may grow as the project stabilizes. It may shrink only through a
charter amendment.

## 4. Amendment procedure

A charter amendment is a commit that edits this file (and, if applicable,
a rule file), accompanied by a `journal/sessions/*.md` capturing motivation,
concrete breakage prevented, and — if I2 is touched — data migration plan.
Bump the version below.

## 5. Charter version

- **v0.1** — initial draft (project version `0.1`, 33 commits). Windows tracker
  end-to-end; macOS primitives only; Linux stub empty.
- **v0.2** — A1 SQLite primary-source migration. I2: `timearc.db` elevated to the
  primary history contract + UI primary read source; JSONL kept as fallback.
  `rules/03` §1. Proposal: `journal/sessions/20260609-1614-B-a1-sqlite-storage-migration-kickoff.md`.
- **v0.3** — D2 user-selectable DB path. I2: the `timearc.db` path is the default but
  **redirectable** via `usage_config.json` `db_path` (both processes read one pointer;
  fail-safe to default). `rules/03` §1. Proposal:
  `journal/sessions/20260610-1705-B-d2-db-path-pointer-proposal.md`.
