# TimeArc

A cross-platform personal time-tracking desktop app with a life-log
aesthetic. TimeArc combines **automatic** system-level activity sampling
(foreground apps and audio sessions) with **manual** project timers and
a calendar of daily to-dos, and presents them through a Qt Quick desktop UI
with day and night modes.

> Status: early development (project version `0.1`). Windows tracker is
> end-to-end functional; macOS has the sampling primitives but the
> service loop is not yet wired; Linux is not started.

## Table of Contents

- [TimeArc](#timearc)
  - [Features](#features)
  - [Platform Support](#platform-support)
  - [Architecture](#architecture)
  - [Desktop P1 MVP Status](#desktop-p1-mvp-status)
  - [Tech Stack](#tech-stack)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Building](#building)
  - [Usage](#usage)
    - [Basic Usage](#basic-usage)
    - [Data Location](#data-location)
    - [TimeArc Service](#timearc-service)
    - [Configuration](#configuration)
  - [Project Structure](#project-structure)
  - [Contributing](#contributing)
    - [For Humans](#for-humans)
    - [Contributing with AI Agents](#contributing-with-ai-agents)
    - [Verification](#verification)
    - [Code Style](#code-style)
  - [Roadmap](#roadmap)
  - [License](#license)
    - [Third-Party Components](#third-party-components)

## Features

- **Automatic foreground tracking** — per-session records of the active
  window, segmented on app or window-title changes, idle-aware.
- **Automatic audio tracking** — independently records whether any app
  is producing audio, with silence grace and long-run segmentation;
  captures "I left the computer but the video kept playing".
- **Manual project timers** — run timers against user-defined projects
  tagged across eight fixed categories (study, work, sport, leisure,
  reading, social, life, other). Manual projects and timer sessions are
  stored through the SQLite repository layer.
- **Calendar of daily to-dos and photos** — persist per-date tasks and
  optional imagery, link to-dos to projects to merge into the timeline.
  Calendar to-dos are stored in the SQLite settings table.
- **Desktop shell** — a Qt Quick interface with full day/night theming
  across the Home, Chat, Memory Lake, Calendar, Stats, Profile, and Timer
  pages.
- **Local memo chat** — the desktop Chat page is a local self-recording
  memo surface, not an AI chat or cloud chat. Messages are stored in the
  SQLite settings repository and loaded back in timestamp order.
- **Daily cards in Memory Lake** — the Memory Lake page generates deterministic
  local cards from today's recorded data: a mainline summary (active time and
  the day's main app) and a top-app usage breakdown with native icons and
  proportional bars. Cards are generated on the fly (no AI, no persistence yet).
- **Native app icons in statistics** — the usage UI surfaces each
  tracked app's system icon via a Qt image provider.

## Platform Support

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| Windows  | functional  | Foreground + WASAPI audio + idle; service runs as a foreground console binary (SCM registration is a TODO). |
| macOS    | in progress | `NSWorkspace` + `CGEventSource` + `IOPMCopyAssertionsByProcess` primitives are in place; tracker main loop not yet wired. |
| Linux    | not started | Target both X11 and Wayland; audio likely via PipeWire. |

## Architecture

TimeArc ships as **two cooperating processes** that communicate
exclusively through files on disk — no IPC, sockets, or shared memory.

```
+----------------------+          +-----------------------+
|   TimeArc (UI)       |          |  time-arc-service     |
|   Qt 6 + QML         |          |  C (Win/Linux),       |
|   C++17              |          |  Swift (macOS)        |
|                      |          |                       |
|   reads/writes       | <---->   |  writes               |
|   usage_records.jsonl|          |  usage_records.jsonl  |
|   usage_current.json |  <----   |  usage_current.json   |
|   timearc.db         | <---->   |  timearc.db           |
+----------------------+          +-----------------------+
         starts (Windows only, via QProcess)
         --------------------------------->
```

- The UI launches and may spawn the service (see
  `src/main.cpp::startUsageService`) but does not link against its code.
- Record schema is defined in
  `src/service/shared/usage_record.schema.json`; fields include
  `platform`, `source` (`foreground` | `audio`), `app_id`, `app_name`,
  `window_title`, `path`, `start_unix_sec`, `duration_sec`.
- `data_bridge.h` is the cross-language C ABI used by Swift (macOS) and
  C (Windows/Linux) tracker code to submit sessions to the storage
  layer.
- SQLite database-layer integration has started. The app and service can
  open the shared `timearc.db` and write/read app and session tables, but
  the migration is transitional: SQLite is not yet the sole primary data
  source, and the JSONL history plus live JSON snapshot still remain in use.
- Current desktop data split: automatic foreground-app and media usage
  still come from the real service capture path and journal/database session
  readers; manual projects, timer sessions, calendar todos, night mode, and
  local memo chat are routed through SQLite-backed repositories/settings.
  Legacy QSettings data for those UI-owned items is migrated into SQLite on
  startup without deleting the old QSettings keys.

## Desktop P1 MVP Status

The desktop MVP is in a P1 stabilization state, not a production-complete
state. The main data loop is now closed for the desktop surfaces below:

- Home and Stats share the same real usage/project/session repositories for
  today's manual-project totals, project rankings, recent activity, and range
  aggregation.
- Project creation, timer session submission, project deletion, calendar
  todos, night mode, and local memo chat are persisted through SQLite-backed
  repositories/settings.
- Project deletion is conservative: projects are archived/hidden from active
  lists, while historical sessions and stats remain queryable.
- Calendar todos persist date, title, and completion state through SQLite
  settings.
- The Settings page stores night mode in SQLite settings and shows the real
  read-only SQLite database path from `databaseManager.getDatabasePath()`.
- The Chat page is a local memo/self-recording chat. It is not an AI chat,
  does not call cloud services, and does not provide smart replies.

Important limits remain:

- SQLite is not yet the only primary data source. Automatic foreground and
  media usage still depend on the service capture path, journal files, and
  current database readers.
- Legacy QSettings project/session/todo/memo/night-mode data is migrated
  idempotently into SQLite when possible, but the old QSettings data is kept
  for rollback rather than deleted.
- Cross-day manual sessions are retained by overlapping range queries; they
  are not yet split or prorated per day.
- Data export/backup, user-selectable database path migration, fuller
  migration tooling, richer memo management, and production packaging remain
  P2 work.

## Tech Stack

| Layer            | Technology                                                      |
|------------------|-----------------------------------------------------------------|
| UI               | Qt 6.8 (Core, Quick, Svg, Sql, Widgets), QML, C++17             |
| Service (Win)    | C11 (WinAPI, WASAPI `IAudioMeterInformation`, PSAPI, COM)       |
| Service (macOS)  | Swift 5+ (`NSWorkspace`, Accessibility API, IOKit power mgmt)   |
| Service (Linux)  | C11 — X11 + Wayland planned                                     |
| Storage (today)  | JSONL history + atomic JSON live snapshot for service usage; SQLite repositories for app/session/project/settings data |
| Storage (planned)| Finish SQLite migration as the primary data source              |
| Build            | CMake 3.16+, Qt's `qt_standard_project_setup(REQUIRES 6.8)`     |
| Persistence (UI) | SQLite settings/repositories; legacy QSettings is migrated and retained for rollback |
| Third-party      | SQLite (vendored, public domain), Parson (vendored, MIT)        |
| License          | GPL-3.0-or-later                                                |

## Installation

### Prerequisites

- **CMake** 3.16 or newer.
- **Qt** 6.8 or newer with the `Core`, `Quick`, `Svg`, `Sql`, and `Widgets`
  modules. On macOS, Swift toolchain enabled.
- **C11** and **C++17** compiler: MSVC ≥ 2019 or MinGW-w64 on Windows,
  Clang on macOS (with Swift), GCC/Clang on Linux.
- (Optional) **Python 3.8+** to run the project harness (see
  [Contributing with AI Agents](#contributing-with-ai-agents)).

### Building

From the project root:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
cmake --install build --prefix build/install
```

Contributors using the harness should prefer the wrapped build so that
build failures are automatically journalled:

```bash
python .harness/tools/build.py -- --config Release
```

If the Windows `python` command points at a broken Windows Store alias, install
a real Python 3 interpreter and either put it on `PATH` or point
`TIMEARC_PYTHON` at it:

```powershell
$env:TIMEARC_PYTHON = "D:\path\to\python.exe"
& $env:TIMEARC_PYTHON .harness/tools/preflight.py --track B
```

Two executables are produced: `TimeArc` (the UI) and `time-arc-service`
(the background sampler). Both land under the install prefix's `bin/`
(or `.app` bundle on macOS).

## Usage

### Basic Usage

Launch `TimeArc`. On Windows it will auto-spawn `time-arc-service` from
the same directory (detached); on macOS the service is not yet started
by the UI. The UI shows seven pages on desktop (Home, Chat, Memory Lake,
Calendar, Stats, Profile, Timer).

### Data Location

| Platform | Path                                                     |
|----------|----------------------------------------------------------|
| Windows  | `%LOCALAPPDATA%\TimeArc\usage\` (fallback `%APPDATA%`)    |
| macOS    | `~/.timearc/usage/`                                       |
| Linux    | `~/.timearc/usage/`                                       |

Files written in the usage directory:

- `usage_records.jsonl` - append-only history, one JSON record per line.
- `usage_current.json` - atomic overwrite, UI-polled live snapshot.

The SQLite file is separate from the usage directory. It uses Qt's
`QStandardPaths::AppDataLocation`; on Windows that is typically
`%APPDATA%\TimeArc\TimeArc\timearc.db`. It is being introduced alongside
JSONL and is not yet the sole primary data source.

Desktop manual projects, timer sessions, calendar to-dos, night mode, and
local memo chat now read/write this SQLite database. Existing QSettings data
for projects/sessions, calendar todos, local memo chat, and night mode is
migrated once on startup when possible. The migration is idempotent and keeps
the legacy QSettings data in place; it does not make SQLite the only source
for automatic foreground/media usage yet.

A separate log produced by the Qt message handler (harness journal) is
written to `<GenericDataLocation>/TimeArc/logs/harness-qt.log`.

### TimeArc Service

The service samples foreground windows and per-process audio every
second (configurable via `TIMEARC_USAGE_POLL_INTERVAL_MS`). It honors a
60-second idle threshold (`TIMEARC_USAGE_IDLE_THRESHOLD_MS`) and
guarantees a single running instance via the named mutex
`Local\TimeArcUsageService` on Windows. A `Ctrl+C` or console close
triggers an orderly flush of the current session.

### Configuration

User preferences are not yet externalized as editable config files. Desktop
night mode is persisted in SQLite settings, and the bundled Parson JSON parser
exists for future user-config work.

## Project Structure

```
time-arc/
├── AGENTS.md                  Entry for AI coding agents (shim → .harness)
├── CMakeLists.txt             Root CMake: project, targets, install rules
├── README.md                  This file
├── LICENSE                    GPL-3.0-or-later
├── .harness/                  AI-agent harness — see §Contributing
├── src/
│   ├── CMakeLists.txt
│   ├── main.cpp               UI entry: starts service, registers managers
│   ├── include/util.h         Shared macros (TA_MAX_*, TA_CONTAINER_OF …)
│   ├── services/              UI-side QObject managers (context properties)
│   │   ├── calendarmanager.{h,cpp}    Calendar to-dos, daily photos
│   │   ├── projectmanager.{h,cpp}     Projects + session aggregation
│   │   ├── timermanager.{h,cpp}       Manual stopwatch
│   │   ├── usagestatmanager.{h,cpp}   Reads journal files, aggregates
│   │   ├── appiconimageprovider.{h,cpp}   image://appicon/<exe path>
│   │   └── harnesslogger.{h,cpp}      Qt message handler → harness log
│   └── service/               Background sampler (separate binary)
│       ├── CMakeLists.txt
│       ├── shared/            Cross-platform C ABI and on-disk contract
│       ├── windows/           WIN32 build only
│       ├── macos/             APPLE build only
│       └── linux/             UNIX-non-APPLE build (TODO)
├── qml/
├── resources/
└── thirdparty/
    ├── sqlite3/               Vendored SQLite (public domain)
    └── parson/                Vendored Parson JSON parser (MIT)
```

## Contributing

### For Humans

Open a pull request against `main`. Follow the existing file structure
when adding code, and write a descriptive commit message in the
imperative mood. Keep diffs focused; prefer two small commits over
one mixed commit.

### Contributing with AI Agents

This repository includes a harness under `.harness/` that constrains
how AI coding agents (Codex CLI, Aider, Cursor, and others that follow
the `AGENTS.md` convention) modify the codebase. The harness provides:

- **Frozen files** — the UI↔service disk contract, top-level CMake
  entries, and agent playbooks are sha256-locked; edits require a
  change proposal filed under `.harness/journal/sessions/`.
- **7-pass audit** via `python .harness/tools/harness_check.py`
  covering markdown line budget, frozen-file hash drift, CMake
  structure, platform isolation, journal hygiene, filename-slug shape,
  and track discipline.
- **Auto-journalled errors** — `record_error.py` for manual entry,
  `build.py` for L1 build failures, `scan_qt_log.py` for L2 Qt runtime
  warnings drained from a `qInstallMessageHandler` hook in the UI.
- **Three tracks** — every session is Stabilize (A), Feature (B), or
  Debug (C); mixing tracks in one commit is discouraged.

Agents following the `AGENTS.md` convention discover `AGENTS.md` at the
project root automatically. The root file is a thin shim that points to
`.harness/AGENTS.md` for the full playbook.

Each session must run these commands at the indicated stages:

```bash
python .harness/tools/preflight.py --track <A|B|C>
python .harness/tools/record_error.py --level <L1|L2|L3> --track <A|B|C> \
    --topic <slug> --summary "..."
python .harness/tools/build.py
python .harness/tools/scan_qt_log.py
python .harness/tools/harness_check.py
```

Human contributors may bypass the harness, but using it produces a
reviewable change history for free.

### Verification

Recommended P1 desktop verification sequence:

```bash
python .harness/tools/preflight.py --track B
python .harness/tools/build.py
ctest --test-dir build --output-on-failure
python .harness/tools/scan_qt_log.py
python .harness/tools/harness_check.py
```

Run `scan_qt_log.py` after a Qt/QML app run; it drains the harness Qt log and
records real runtime warnings. Do not report harness validation as passed if
Python cannot start or these commands were not actually run.

See `.harness/CHARTER.md` for invariants and frozen files;
`.harness/OPTIMIZE.md` for how to keep agent context cost low;
`.harness/state/open-issues.md` for the running list of known gaps.

### Code Style

- C/C++ formatted to the surrounding file; prefer 2-space indentation
  in C++ code matching the existing `src/services/*` style.
- C identifiers and function names are English; inline comments may be
  Chinese, matching the existing convention.
- QML user-facing strings are Chinese; property names use camelCase in
  English.
- New source files carry an SPDX header:
  `// SPDX-License-Identifier: GPL-3.0-or-later`, followed by a
  `Copyright (C) <year> <author>` line when authored afresh.

## Roadmap

- [ ] Implement the macOS service tracker loop (sampling primitives
      already in place; mirror `windows/tracker/usage_tracker.c`).
- [ ] Implement the Linux service: X11 + Wayland foreground sampling,
      idle detection, PipeWire/PulseAudio audio.
- [ ] Register the Windows service with the Service Control Manager
      (stubs in `src/service/windows/service/win_service.c`).
- [ ] Finish the on-disk storage migration so SQLite becomes the primary
      source, with a one-shot JSONL backfill/migrator.
- [ ] Compile Qt as dynamically-linked libraries in release builds to
      satisfy the LGPL-3.0 combination posture.
- [ ] Add an in-app licenses page surfacing all third-party texts.
- [ ] Wire Parson in as the JSON parser for user preferences /
      configuration.
- [ ] Expand the "Memory Lake" Daily Cards: the first slice (mainline + top-app
      cards from today's data) ships; still to do are focus-block, entertainment
      and contrast cards via an activity segmenter/classifier, plus persistence.
- [ ] Add export/backup and restore flows for SQLite-backed desktop data.
- [ ] Add a safe database-path migration flow if user-selectable data
      locations become a product requirement.
- [ ] Expand local memo management only as local/offline tooling; do not
      describe it as AI chat unless an actual AI feature is added later.
- [ ] Add UTF-8 validation to `usage_storage.c::write_json_string`.

## License

This project is licensed under the **GNU General Public License v3.0
or later (GPL-3.0-or-later)**. See `LICENSE` for the full text.

### Third-Party Components

| Component | License                   | Linkage | Notes                                |
|-----------|---------------------------|---------|--------------------------------------|
| Qt 6      | LGPL-3.0 (with exceptions)| dynamic (planned for release) | Required for GUI + QML + Svg. |
| SQLite    | Public domain             | static  | Vendored under `thirdparty/sqlite3/`; used by the database layer and service storage. |
| Parson    | MIT                       | static  | Vendored under `thirdparty/parson/`. Will back user config. |
