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
  - [Adapter Support](#adapter-support)
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
- **Calendar (日历)** — a full-bleed dark-glass page (v88) with **month grid +
  week-plan / today-agenda / focus-record** views. Persist per-date to-dos and
  optional photos, link to-dos to projects to merge into the timeline. Calendar
  to-dos are stored in the SQLite settings table.
- **Statistics (统计)** — a full-bleed dark-glass analytics page (v88) with
  **week / month / year** views and period **prev / next** navigation, driven by
  real read-only usage-journal data. Metric cards (total / daily-average / longest
  streak / switch count) with period-over-period change (WoW / MoM / YoY), a
  reduced-glass **category-share donut**, a 7-day / 12-month **bar chart**, a month
  **activity heatmap** + week-trend line, a **top-apps ranking** (real icons +
  open counts), **focus** time (开发/办公/笔记 derived blocks), and local
  deterministic **insights / recommendations** (no AI over raw logs). Honest
  placeholders where history is thin; **report export** to a JSON file. Read-only —
  never writes usage/SQLite.
- **Settings (设置)** — a full-bleed dark-glass settings page (v88) with five tabs
  (通用 / 追踪与应用 / 隐私与数据 / 备忘与番茄钟 / 导入导出), live card search, and
  ~30 preferences persisted immediately to the SQLite settings store. Day-mode is a
  switch that drives the app-wide night theme (the shell owns persistence). Built on a
  new reusable dark-glass control family in `qml/desktop/memorylake/` — `GlassSwitch`,
  `GlassComboBox` (overlay popup, no native skin), `GlassSlider`, `GlassTextField`
  (incl. a search variant), and `KbdChip` — all styled from `MemoryLakeStyle` tokens.
  The app-management tab lists real captured apps for per-app hide; the pomodoro card
  drives the memo blackboard's real countdown (default duration/title/celebration);
  memo & pomodoro hotkeys are user-customizable; a one-shot welcome animation is gated
  by `show_welcome`; and **system notifications** (pomodoro-complete-in-background) use
  `qml/desktop/memorylake/NotifierTray.qml` (a `Qt.labs.platform` tray, loaded
  defensively so a missing plugin can't break the app). Items with no backend
  (real history deletion, true service-side track pause / idle, real-time backdrop
  blur, global accent/i18n) stay honest placeholders rather than faked; the page is
  read-only over the usage journal and never bypasses the disk contract.
- **Desktop shell** — a Qt Quick interface with full day/night theming.
  The left nav follows the design order **首页 (Memory Lake) · 日历 · 统计 ·
  设置 · 备忘**, with **记忆湖 / Monthly Recap pinned separately at the bottom**.
  Memory Lake is the home/landing page; the Timer page is reached when a
  calendar to-do starts timing.
- **Frameless window chrome** — the desktop window drops the native OS title
  bar for an immersive custom chrome (QQ-Music style): a brand app icon
  top-left and minimize / maximize / close controls top-right, floating over a
  page background that bleeds to the top edge. Drag the top bar to move (native
  edge-snap preserved), double-click to maximize/restore, drag any edge to
  resize. Glyph color adapts to the surface (light on the dark Memory Lake /
  night pages) and the chrome steps aside while the memo blackboard is open.
  On Windows 11 the window gets **native rounded corners and drop shadow** via
  DWM (`DWMWA_WINDOW_CORNER_PREFERENCE`). Mobile preview keeps the native frame.
  *(A fuller native custom-frame pass — Win11 snap-layouts fly-out — is still
  planned.)*
- **Memory Lake memo blackboard (备忘)** — the 「备忘」 nav opens a modal blackboard
  **overlay** over the home page (an action, **not** a page route): a near-black dotted
  board with a freehand chalk-ink canvas and a floating glass tool pill (note / text /
  pen / eraser / exit), the home page re-blurred behind it. Freehand chalk pen/eraser with a
  **color palette + width presets** and a **clear-canvas** button (confirm + Ctrl+Z undoable),
  draggable + resizable **sticky notes** (autosize, aqua selection ring, a **due date/time**
  picker, a done checkbox and an editable **signature**), editable + resizable **text layers**
  (Alt-drag), a **multi-page archive folder** (switch / add / delete / **rename** / drag-**reorder**,
  max 10, each page owns its own ink + objects and shows a **row thumbnail**), a marquee
  **select tool** (copy / delete / move / scale across ink *and* objects, with a clipboard —
  **Ctrl+C / Ctrl+V** across pages — and **Ctrl+Z** undo), and a **persisted pomodoro widget**
  (editable title, collapses to a pixel tomato while running, full-screen completion celebration). The toolbar + folder auto-hide as a Dynamic-Island; the board is a fixed
  1920×1080 logical canvas uniformly scaled to fit the window (16:9). Everything
  **auto-persists** to a UI-private store (`SettingsRepository`), kept **off the service↔UI
  disk contract**. *(Replaces the former local Chat page.)*
- **Memory Lake home view** — the Memory Lake page is the **home page**, a
  three-panel "记忆湖": a left panel with the app usage ranking, a **center column**
  that stacks the **Today Conclusion** briefing (今日结论: kicker/title/score box +
  chips for top share / remaining to-dos / peak hours / suggestion) on top of the
  flip-card carousel in a rounded "cards-zone" (the cards occupy the lower half;
  the briefing **collapses on flip** — "今日结论暂时收起" — so the cards get room),
  and a right panel with **Daily Usage Share** (今日软件使用占比 donut + legend),
  the "time river", and **Calendar Sync** (今日事项, today's to-dos synced from the
  calendar). The center 3D flip-card carousel (wheel/click switching, flip-to-lock)
  is **unchanged**. The
  monthly recap is now its **own page** ("记忆湖 / Memory Recap" at the bottom of
  the nav): a full-screen story-mode recap (slides with transitions, autoplay, an
  unlockable step directory; 返回湖面 / Esc returns home). It renders **real
  recorded usage** via the same read-only path as the Home page: the day view is
  a cross-app focus-block task summary (e.g. "开发为主 · 今天有 N 段连续使用")
  with per-app categories, generative covers tinted by the app icon's own colors
  (no per-app artwork), and a time river; the monthly recap is built from real
  month data (per-day trend, category share, month-on-month). All copy is local
  deterministic templates (`DailyCardService`, no AI, no chat/screenshots/raw
  audio); missing data falls back to honest empty states. It follows the
  day/night theme with glass/neon lighting and silky scrolling. The Home and
  Monthly Recap surfaces have a full **art-replication pass** to the v88 design:
  a blue-black depth-ramp background with aqua/violet corner lights, tier-1/2
  glass with top+bottom edge-light pairs (reusable `FrostCard` for frost cards),
  a center "lake" up-light + water line + progress-dot pill, and a recap shell with
  aurora wave + glow-ring + staggered slide entrances. The Today Conclusion briefing,
  the **notebook-grid + blue-neon** Calendar Sync panel, and the **3D neon donut**
  (colored bloom + breathing ring + sculpted dark center hole) share a reusable
  `GridTexture` grid-paper overlay and corner radial glows — all colors/radii/easings
  sourced from the `MemoryLakeStyle` token singleton.
  Per-surface design: `docs/memory-lake-backend-integration-plan.md`,
  `docs/memory-lake-home-art-implementation-spec.md`,
  `docs/memory-lake-art-lighting-qml-cookbook.md`.
- **Native app icons in statistics** — the usage UI surfaces each
  tracked app's system icon via a Qt image provider.
- **Mainland China browser-site split** - common websites opened inside
  Chrome, Edge, Firefox, and other supported browsers can be grouped as
  independent `site:*` activities in the UI, with preset brand colors and
  text/icon fallbacks for visual surfaces. Mainstream video sites now include
  repo-local favicon assets under `resources/icons/sites/`, and foreground
  window titles plus useful media titles share the same site catalog matching
  path so video/audio usage can surface the site icon instead of the browser
  icon when the title contains a known site marker.

## Platform Support

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| Windows  | functional  | Foreground + WASAPI audio + idle; the tracker runs in the user session, with an opt-in logon autostart (Settings → 追踪与应用; B1 Route A). A true SCM/Session-0 service (Route B) is deferred. |
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
  readers; manual projects, timer sessions, calendar todos, night mode, and the
  memo blackboard doc are routed through SQLite-backed repositories/settings.
  Legacy QSettings data for those UI-owned items is migrated into SQLite on
  startup without deleting the old QSettings keys.

## Adapter Support

TimeArc has a basic website/software adapter system for high-frequency
activities. Adapters add friendly metadata such as display name, category,
icon fallback, source type, and confidence while keeping the original usage
record fields intact.

- System overview: `docs/adapter-system.md`
- Add a website adapter: `docs/adding-website-support.md`
- Add a desktop app adapter: `docs/adding-app-support.md`
- Implementation report: `docs/adapter-support-implementation-report.md`

## Desktop P1 MVP Status

The desktop MVP is in a P1 stabilization state, not a production-complete
state. The main data loop is now closed for the desktop surfaces below:

- Home and Stats share the same real usage/project/session repositories for
  today's manual-project totals, project rankings, recent activity, and range
  aggregation.
- Project creation, timer session submission, project deletion, calendar
  todos, night mode, and the memo blackboard doc are persisted through
  SQLite-backed repositories/settings.
- Project deletion is conservative: projects are archived/hidden from active
  lists, while historical sessions and stats remain queryable.
- Calendar todos persist date, title, and completion state through SQLite
  settings.
- The Settings page stores night mode in SQLite settings and shows the real
  read-only SQLite database path from `databaseManager.getDatabasePath()`.
- The 备忘 entry opens a local blackboard memo overlay (freehand ink + notes,
  sticky/text objects, multi-page, select tool, pomodoro), not an AI chat or
  cloud service. Its content is user-authored UI-private state, persisted through
  a UI-private store (`SettingsRepository` key `memoryLakeMemoDoc`), off the
  service↔UI disk contract.

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

### Quick run on Windows (`run.cmd` / `launch.cmd`)

Two convenience launchers live at the repo root:

- **`run.cmd`** — puts the Qt/MinGW/Ninja toolchain on `PATH`, configures the
  build the first time (`-G Ninja`), closes any running instance, builds
  incrementally, then launches. Use `run` (cmd) or `.\run` (PowerShell);
  `.\run --mobile-preview` opens the mobile window. Args pass through to `TimeArc.exe`.
- **`launch.cmd`** — toolchain + launch an *already-built* `TimeArc.exe`, no build
  (use it to open a second window alongside one started by `run.cmd`).

**Toolchain auto-detect + override.** Both resolve the Qt *root* in this order
(first hit wins), so the same committed script runs on different machines with no
edits:

1. `run.local.cmd` / `launch.local.cmd` — **gitignored, per-machine**; a one-liner
   like `set "QTROOT=C:\Qt"`.
2. the `TIMEARC_QT_ROOT` environment variable.
3. a built-in probe of common roots (`C:\Qt`, `D:\TimeArc\QT`, `D:\Qt`, …).

Everything else (Qt `6.x\mingw_64`, MinGW, Ninja, bundled CMake) is derived from
that root. If your Qt lives elsewhere, set `run.local.cmd` or `TIMEARC_QT_ROOT` —
**do not hardcode a path into the tracked `run.cmd`/`launch.cmd`.**

> ⚠️ **`run.cmd` / `launch.cmd` are fork-local.** Every fork (including upstream)
> keeps its own copy with its own toolchain paths; they are **never synced across
> forks**. See [Contributing](#contributing) for how a contribution is kept from
> ever overwriting another fork's launch scripts.

## Usage

### Basic Usage

Launch `TimeArc`. On Windows it will auto-spawn `time-arc-service` from
the same directory (detached); Settings → 追踪与应用 also offers an opt-in
"开机自动在后台采集" toggle that registers a per-user logon task so the
tracker starts at login (B1 Route A — it always runs in the interactive user
session, never Session 0, so capture stays correct). On macOS the service is not yet started
by the UI. The desktop nav is **首页 (Memory Lake) · 日历 · 统计 · 设置 · 备忘**,
with **记忆湖 / Monthly Recap** pinned at the bottom; the Timer page opens when a
calendar to-do starts timing. Memory Lake is the landing page.

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

Desktop manual projects, timer sessions, calendar to-dos, night mode, and the
memo blackboard doc now read/write this SQLite database. Existing QSettings data
for projects/sessions, calendar todos, and night mode is
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
│   │   ├── calendar_manager.{h,cpp}    Calendar to-dos, daily photos
│   │   ├── project_manager.{h,cpp}     Projects + session aggregation
│   │   ├── timer_manager.{h,cpp}       Manual stopwatch
│   │   ├── usage_stat_manager.{h,cpp}   Reads journal files, aggregates
│   │   ├── app_icon_image_provider.{h,cpp}   image://appicon/<exe path>
│   │   └── harness_logger.{h,cpp}      Qt message handler → harness log
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

### Launch scripts are fork-local — never contributed

`run.cmd` / `launch.cmd` hold per-machine toolchain paths and **differ between
forks** (upstream's Qt is under `D:\TimeArc\QT`, another fork's under `C:\Qt`).
A contribution must **never** carry them, or it overwrites the other side's
working launcher and forces a manual re-fix. This is enforced mechanically — you
don't have to remember:

- **Contribute upstream** with the helper. It pins the launch scripts to
  upstream's version (zero diff for those two files) and opens the PR with an
  explicit `--repo`/`--base`/`--head`. Always contribute from a throwaway
  `sync/…` branch, **not** from `dev`:
  ```powershell
  pwsh -File tools/contribute-to-upstream.ps1
  ```
- **A pre-push guard** rejects pushing a *contribution* branch (`sync/contribution-*`,
  or any other `sync/*` / `*contribution*` name) whose `run.cmd` / `launch.cmd`
  still differ from `upstream/dev`. Down-sync branches (`sync/upstream-dev-*`,
  `merge/upstream-dev-*`) are exempt — they intentionally keep your scripts.
  Install it once per clone:
  ```powershell
  pwsh -File tools/install-hooks.ps1
  ```
- **Down-sync** (pulling upstream into your fork) keeps *your* launch scripts:
  ```powershell
  pwsh -File tools/sync-from-upstream.ps1
  ```
  (A `.gitattributes merge=ours` does **not** reliably do this — when only
  upstream changed the file, git fast-forwards to their version — so the helper
  re-pins your copy after the merge instead.)

If you ever bypass the helper, the manual pin is:
```bash
git fetch upstream
git checkout upstream/dev -- run.cmd launch.cmd            # pin to upstream => zero diff
git diff --name-only upstream/dev -- run.cmd launch.cmd    # MUST print nothing
```

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
- [x] Windows background autostart (B1 Route A): per-user logon task /
      Run-key via `win_service.c` lifecycle verbs, with a Settings toggle.
      A true SCM Session-0 service (Route B) remains deferred.
- [ ] Finish the on-disk storage migration so SQLite becomes the primary
      source, with a one-shot JSONL backfill/migrator.
- [ ] Compile Qt as dynamically-linked libraries in release builds to
      satisfy the LGPL-3.0 combination posture.
- [ ] Add an in-app licenses page surfacing all third-party texts.
- [ ] Wire Parson in as the JSON parser for user preferences /
      configuration.
- [ ] Evolve the "Memory Lake" Daily Cards: the six local card types
      (mainline, top-app, focus-block, entertainment, contrast, flip) plus the
      activity segmenter and keyword classifier ship. Still to do: a privacy
      filter for sensitive apps, user-editable categories, card persistence,
      and a confirmed-summary AI pass.
- [ ] Add export/backup and restore flows for SQLite-backed desktop data.
- [ ] Add a safe database-path migration flow if user-selectable data
      locations become a product requirement.
- [ ] Expand local memo management only as local/offline tooling; do not
      describe it as AI chat unless an actual AI feature is added later.
- [ ] Add UTF-8 validation to `usage_storage.c::write_json_string`.
- [ ] Finish the Settings page remainders: app-wide accent-color theming and
      full internationalization (zh / en / ja), plus service-honored idle-timeout
      and tracking-pause (a change proposal is filed). Detail + priorities in
      `docs/implementation-backlog.md` §H and `docs/settings-remaining-work.md`.

## License

This project is licensed under the **GNU General Public License v3.0
or later (GPL-3.0-or-later)**. See `LICENSE` for the full text.

### Third-Party Components

| Component | License                   | Linkage | Notes                                |
|-----------|---------------------------|---------|--------------------------------------|
| Qt 6      | LGPL-3.0 (with exceptions)| dynamic (planned for release) | Required for GUI + QML + Svg. |
| SQLite    | Public domain             | static  | Vendored under `thirdparty/sqlite3/`; used by the database layer and service storage. |
| Parson    | MIT                       | static  | Vendored under `thirdparty/parson/`. Will back user config. |
