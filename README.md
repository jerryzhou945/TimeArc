# TimeArc

A cross-platform personal time-tracking desktop/mobile app with a life-log
aesthetic. TimeArc combines **automatic** system-level activity sampling
(foreground apps and audio sessions) with **manual** project timers and
a calendar of daily to-dos, and presents them through a Qt Quick UI that
adapts between desktop and mobile layouts and between day and night modes.

> Status: early development (project version `0.1`). Windows tracker is
> end-to-end functional; macOS has the sampling primitives but the
> service loop is not yet wired; Linux is not started.

## Table of Contents

- [TimeArc](#timearc)
  - [Features](#features)
  - [Platform Support](#platform-support)
  - [Architecture](#architecture)
  - [Tech Stack](#tech-stack)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Building](#building)
  - [Usage](#usage)
    - [Basic Usage](#basic-usage)
    - [Mobile Preview](#mobile-preview)
    - [Data Location](#data-location)
    - [TimeArc Service](#timearc-service)
    - [Configuration](#configuration)
  - [Project Structure](#project-structure)
  - [Contributing](#contributing)
    - [For Humans](#for-humans)
    - [Contributing with AI Agents](#contributing-with-ai-agents)
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
  reading, social, life, other).
- **Calendar of daily to-dos and photos** — persist per-date tasks and
  optional imagery, link to-dos to projects to merge into the timeline.
- **Adaptive shell** — a single QML application auto-switches between a
  desktop and a mobile shell based on window width (`<= 720 px` → mobile)
  or explicit flag; includes full day/night theming.
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
|   reads              |  <----   |  writes (append)      |
|   usage_records.jsonl|          |  usage_records.jsonl  |
|   usage_current.json |  <----   |  usage_current.json   |
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

## Tech Stack

| Layer            | Technology                                                      |
|------------------|-----------------------------------------------------------------|
| UI               | Qt 6.8 (Core, Quick, Svg, Widgets), QML, C++17                  |
| Service (Win)    | C11 (WinAPI, WASAPI `IAudioMeterInformation`, PSAPI, COM)       |
| Service (macOS)  | Swift 5+ (`NSWorkspace`, Accessibility API, IOKit power mgmt)   |
| Service (Linux)  | C11 — X11 + Wayland planned                                     |
| Storage (today)  | JSONL history + atomic JSON live snapshot, UTF-8                |
| Storage (planned)| SQLite; path reserved, writer is a no-op today                  |
| Build            | CMake 3.16+, Qt's `qt_standard_project_setup(REQUIRES 6.8)`     |
| Persistence (UI) | `QSettings` for projects, sessions, calendar data               |
| Third-party      | SQLite (vendored, public domain), Parson (vendored, MIT)        |
| License          | GPL-3.0-or-later                                                |

## Installation

### Prerequisites

- **CMake** 3.16 or newer.
- **Qt** 6.8 or newer with the `Core`, `Quick`, `Svg`, and `Widgets`
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

Two executables are produced: `TimeArc` (the UI) and `time-arc-service`
(the background sampler). Both land under the install prefix's `bin/`
(or `.app` bundle on macOS).

## Usage

### Basic Usage

Launch `TimeArc`. On Windows it will auto-spawn `time-arc-service` from
the same directory (detached); on macOS the service is not yet started
by the UI. The UI shows seven pages on desktop (Home, Chat, Memory Lake,
Calendar, Stats, Profile, Timer) and nine pages on mobile (Home, Timer,
Project Detail, Chat, Memory Lake, Calendar, Stats, Profile, Settings).

### Mobile Preview

To force the mobile shell on a desktop, pass `--mobile` (or
`--mobile-preview`) on the command line, or set the environment variable
`TIMEARC_MOBILE_PREVIEW=1` before launch. Otherwise the shell is chosen
automatically: window width `<= 720 px` selects the mobile shell.

### Data Location

| Platform | Path                                                     |
|----------|----------------------------------------------------------|
| Windows  | `%LOCALAPPDATA%\TimeArc\usage\` (fallback `%APPDATA%`)    |
| macOS    | `~/.timearc/usage/`                                       |
| Linux    | `~/.timearc/usage/`                                       |

Files written there:

- `usage_records.jsonl` — append-only history, one JSON record per line.
- `usage_current.json` — atomic overwrite, UI-polled live snapshot.
- `usage_records.sqlite3` — reserved for the planned SQLite migration.

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

User preferences are not yet externalized; the bundled Parson JSON
parser exists for this purpose and will be wired in a later release.

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
- [ ] Migrate on-disk storage from JSONL to SQLite behind a feature
      flag, with a one-shot migrator.
- [ ] Compile Qt as dynamically-linked libraries in release builds to
      satisfy the LGPL-3.0 combination posture.
- [ ] Add an in-app licenses page surfacing all third-party texts.
- [ ] Wire Parson in as the JSON parser for user preferences /
      configuration.
- [ ] Ship the "Memory Lake" data model + UI (currently a placeholder
      page).
- [ ] Add UTF-8 validation to `usage_storage.c::write_json_string`.

## License

This project is licensed under the **GNU General Public License v3.0
or later (GPL-3.0-or-later)**. See `LICENSE` for the full text.

### Third-Party Components

| Component | License                   | Linkage | Notes                                |
|-----------|---------------------------|---------|--------------------------------------|
| Qt 6      | LGPL-3.0 (with exceptions)| dynamic (planned for release) | Required for GUI + QML + Svg. |
| SQLite    | Public domain             | static  | Vendored under `thirdparty/sqlite3/`. Reserved for future storage backend. |
| Parson    | MIT                       | static  | Vendored under `thirdparty/parson/`. Will back user config. |
