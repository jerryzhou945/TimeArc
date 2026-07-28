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
  window. An unchanged complete observation remains one logical session;
  changed captured information creates a boundary. Input idle pauses active
  time unless video-like playback evidence says the foreground session is
  still active.
- **Automatic media tracking** — independently records observed playback.
  An unchanged complete media observation remains one logical session, and
  disappearance ends it without a silence grace period. Implementations may
  optionally checkpoint long-running media without changing its identity.
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
  by `show_welcome`; and **system notifications** plus the resident tray menu use
  `qml/desktop/memorylake/NotifierTray.qml` (a `Qt.labs.platform` tray, loaded
  defensively so a missing plugin can't break the app). The tray can restore the
  hidden window and provides the explicit quit path. The **idle timeout** and
  **true track pause** now take real effect: they write `usage_config.json` and an
  "应用并重启采集" action restarts the service to apply them (H5). Items still without a
  backend (real history deletion, real-time backdrop blur, global accent color) stay
  honest placeholders rather than faked; the page is read-only over the service database
  and never bypasses the disk contract.
- **Runtime languages** — the settings language switch now drives global UI copy
  at runtime. Chinese remains the source/fallback language, English is covered
  across the main desktop flow, and Japanese has core UI coverage with fallback
  for less common strings. The switch is presentation-only and does not change
  service records, SQLite schema, or user-entered content.
- **Desktop shell** — a Qt Quick interface with full day/night theming.
  The left nav follows the design order **首页 (Memory Lake) · 日历 · 统计 ·
  设置 · 备忘**, with **记忆湖 / Monthly Recap pinned separately at the bottom**.
  Memory Lake is the home/landing page; the Timer page is reached when a
  calendar to-do starts timing. The desktop UI is single-instance on Windows:
  repeated `TimeArc.exe` launches focus the existing window instead of opening
  another one. On Windows and Linux, closing the window hides it to the system
  tray; the tray menu is the explicit app-exit path while the background
  collector can keep recording. macOS follows its own convention instead: the
  red traffic light closes the window while the app stays in the Dock and menu
  bar, clicking the Dock icon reopens the window, and ⌘Q — or 退出 TimeArc in
  the status item — is the quit path. Closing from full screen exits full
  screen first, then closes. On macOS, the status item uses a monochrome
  template “T” that follows the menu bar's light or dark appearance; the
  colorful brand icon remains in the Dock and app window.
- **Desktop window chrome** — Windows uses an immersive custom chrome
  (QQ-Music style): a brand app icon top-left and minimize / maximize / close
  controls top-right, floating over a page background that bleeds to the top
  edge. macOS is completely borderless and title-bar-free. AppKit draws standard
  traffic-light buttons directly over the edge-to-edge left sidebar; the host
  supplies group-hover glyph state and disables minimize in fullscreen without
  creating a native title region. On macOS, drag the non-interactive sidebar
  background or brand area to move the window, or double-click there to
  maximize/restore it; sidebar controls keep their normal click behavior.
  On Windows, drag the top bar to move,
  double-click to maximize/restore, and drag any edge to resize. The chrome
  steps aside while the memo blackboard is open. On Windows 11 the window gets
  **native rounded corners and drop shadow** via DWM
  (`DWMWA_WINDOW_CORNER_PREFERENCE`). Mobile preview keeps the native frame.
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
  **Ctrl+C / Ctrl+V** across pages — and visible toolbar **undo / redo** controls
  backed by **Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y**), and a **persisted pomodoro widget**
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
  tracked app's system icon via a Qt image provider. TimeArc itself is
  mapped to the built-in T brand mark so self-tracking rows do not fall back
  to a blank or generic executable icon.
- **Mainland China browser-site split** - common websites opened inside
  Chrome, Edge, Firefox, and other supported browsers can be grouped as
  independent `site:*` activities in the UI, with preset brand colors and
  text/icon fallbacks for visual surfaces. Mainstream video sites now include
  repo-local favicon assets under `resources/app/icons/sites/`, and foreground
  window titles plus useful media titles share the same site catalog matching
  path so video/audio usage can surface the site icon instead of the browser
  icon when the title contains a known site marker.

## Platform Support

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| Windows  | functional  | Foreground + WASAPI audio + idle; the tracker runs in the user session, with an opt-in logon autostart (Settings → 追踪与应用; B1 Route A). A true SCM/Session-0 service (Route B) is deferred. |
| Android  | functional preview complete | Usage Access, UsageStats/UsageEvents sync, real app labels/icons, week/month/year/all rankings, the four-tab transparent QML UI, global app-private wallpaper, Memory Lake/monthly report, and FileProvider image sharing are implemented. Multi-ROM device validation remains. |
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
|   reads              | <----    |  writes               |
|   timearc_service.db |  <----   |  timearc_service.db   |
|   writes timearc.db  |          |                       |
+----------------------+          +-----------------------+
         registers LaunchAgent (macOS)
         ----------------------------->
```

- The UI never executes or links against service code. On macOS it registers
  the embedded `com.timearc.service.plist` through `SMAppService`, which gives
  launchd ownership of the helper lifecycle.
- Session fields and their SQLite mapping are documented in
  `.harness/rules/03-data-contract.md`.
- `data_bridge.h` is the cross-language C ABI used by Swift (macOS) and
  C (Windows/Linux) tracker code to submit sessions to the storage
  layer.
- SQLite history is split by ownership: `timearc_service.db` is written only by
  the service and contains `apps`, `frontmost_sessions`, and `media_sessions`;
  the UI opens it read-only as the sole automatic-usage history source. The GUI
  writes its own `timearc.db` for settings,
  tags, manual projects, mobile sync, and other UI state.
- Current desktop data split: automatic foreground-app and media usage
  still come from the real service capture path and database session
  readers; manual projects, timer sessions, calendar todos, night mode, and the
  memo blackboard doc are routed through SQLite-backed repositories/settings.
  Legacy QSettings data for those UI-owned items is migrated into SQLite on
  startup without deleting the old QSettings keys.
- Android mobile usage collection uses the system UsageStats APIs from Java in
  `android/src/main/java/com/timearc/mobile/usage/`. Aggregated per-app daily
  foreground time is stored in `device_usage_summaries`; recent UsageEvents
  foreground/background pairs are stored in `device_usage_sessions`. App
  identity is normalized as `android:<package_name>` so desktop and mobile data
  can be merged by the presentation layer without losing platform/source
  precision.
- Mobile monthly narratives are derived locally by the header-only
  `MobileUsageInsightEngine`. It turns daily summaries and confidence-labelled
  sessions into structured, deterministic facts; QML only chooses presentation
  and never invents unsupported usage events.
- `MobileSeasonScene.qml` presents those facts over twelve bundled, original
  month scenes with season-specific restrained motion; all report artwork is
  local and available offline, with reduced-motion support.
- Mobile monthly reports are published at **次月 1 日 08:00** in the device's
  local time. Before that boundary Memory Lake continues to show the previous
  released month; its tab displays a red dot when a new monthly or annual
  release token has not yet been viewed.
- Mobile share surfaces export portrait app cards, range ranking posters, and
  the six-page monthly story. App and ranking posters reuse the user's private
  wallpaper when set, retain real application icons, and contain only
  aggregated usage facts. `MobileShareActionBar` gives every poster the same
  gallery-first entry points for local save, WeChat Moments, QQ Zone, and the
  Android Sharesheet, with honest authorization status.
- Android UI-private wallpaper and share files are managed by
  `MobileUiService` under the app data directory. They do not enter either
  SQLite usage database or the service control-file contract.
- The mobile Profile keeps an optional 本地头像 in the same UI-private area.
  It is never uploaded or inserted into a share poster automatically; the
  profile archive combines it only with the real first-record date, inclusive
  companionship span, and active record-day count.

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
- The Settings page stores night mode in GUI SQLite settings and shows the GUI
  database size from `databaseManager.getDatabasePath()`.
- The 备忘 entry opens a local blackboard memo overlay (freehand ink + notes,
  sticky/text objects, multi-page, select tool, pomodoro), not an AI chat or
  cloud service. Its content is user-authored UI-private state, persisted through
  a UI-private store (`SettingsRepository` key `memoryLakeMemoDoc`), off the
  service↔UI disk contract.

Important limits remain:

- If `timearc_service.db` is missing, empty, or unreadable, automatic-usage
  history is empty until the service database becomes available.
- Legacy QSettings project/session/todo/memo/night-mode data is migrated
  idempotently into SQLite when possible, but the old QSettings data is kept
  for rollback rather than deleted.
- Cross-day manual sessions are retained by overlapping range queries; they
  are not yet split or prorated per day.
- Fuller migration tooling, richer memo management, and production packaging
  remain P2 work.

## Tech Stack

| Layer            | Technology                                                      |
|------------------|-----------------------------------------------------------------|
| UI               | Qt 6.8 (Core, Quick, Svg, Sql, Widgets), QML, C++17             |
| Service (Win)    | C11 (WinAPI, WASAPI `IAudioMeterInformation`, PSAPI, COM)       |
| Service (macOS)  | Swift 5+ (`NSWorkspace`, Accessibility API, IOKit power mgmt)   |
| Service (Linux)  | C11 — X11 + Wayland planned                                     |
| Storage          | Service-owned SQLite `timearc_service.db` is the sole automatic-usage store; GUI-owned `timearc.db` stores settings/tags/manual/mobile/UI state |
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
(the background sampler). Windows installs both under `bin/`; macOS places
both in `TimeArc.app/Contents/MacOS`.

Desktop builds keep QML, license text, and small shell icons in the executable,
while backgrounds, site icons, and monthly-recap artwork ship as separate
`assets/timearc-{backgrounds,site-icons,monthly-recap}.rcc` functional packs.
The UI registers all required packs before loading QML. Android embeds the same
three QRC contents in its application package. Unreferenced legacy Memory Lake
artwork is not a release input.

### Packaging a release (Windows)

`tools/build-windows.ps1` is the Windows build and release entry point. With no
option it runs the full `--release` pipeline: configure, harness-wrapped Release
build, CTest, `windeployqt`, optional Authenticode signing, dynamic-linkage
verification, and ZIP creation. The narrower modes match the macOS entry point:
`--build`, `--test` (build + test), and `--package` (build + package, without
tests).

```powershell
pwsh -File tools/build-windows.ps1             # same as --release
pwsh -File tools/build-windows.ps1 --build
pwsh -File tools/build-windows.ps1 --test
pwsh -File tools/build-windows.ps1 --package
```

The result is `dist/TimeArc-<version>-win64/` plus a matching `.zip`. It contains
both executables, the three functional RCC packs, replaceable Qt/compiler DLLs,
plugins, QML modules, license texts, and `NOTICE.txt`; it runs without a
machine-wide Qt installation. Packaging rejects a statically linked Qt build.
Set `TIMEARC_SIGN_CERTIFICATE_SHA1` for Authenticode signing or
`TIMEARC_REQUIRE_SIGNING=1` to reject unsigned output. Run
`tools/build-windows.ps1 --help` for path/tool overrides. The older standalone
`package-release.ps1` and `verify-linkage.ps1` utilities remain available but
are not called by this entry point.

### Building and packaging on macOS

`tools/build-macos.sh` is the macOS build and release entry point. With no
option it runs the full `--release` pipeline: configure, harness-wrapped
Release build, CTest, `macdeployqt`, signing, portable-linkage checks, and DMG
creation. The narrower modes are `--build`, `--test` (build + test), and
`--package` (build + package, without tests).
It prefers Ninja, falls back to Xcode, and resets only generated CMake state
when a cached generator such as Unix Makefiles cannot compile Swift.

```bash
tools/build-macos.sh             # same as --release
tools/build-macos.sh --build
tools/build-macos.sh --test
tools/build-macos.sh --package
```

The result is `dist/TimeArc-<version>-macos-<arch>/TimeArc.app` plus a matching
`.dmg`. The app contains both executables in `Contents/MacOS`, the LaunchAgent
in `Contents/Library/LaunchAgents`, the three RCC packs and license texts in
`Contents/Resources`, and private dynamically linked Qt frameworks/plugins
deployed by `macdeployqt`. The package retains the macOS Controls style and its
required Fusion and Basic fallbacks. Local builds are ad-hoc signed.
For a public release, set `TIMEARC_CODESIGN_IDENTITY` and
`TIMEARC_NOTARY_PROFILE`; `TIMEARC_REQUIRE_SIGNING=1` prevents accidental
ad-hoc packaging. Run `tools/build-macos.sh --help` for path/tool overrides.

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

Launch `TimeArc`. On macOS, the UI registers the plist embedded at
`Contents/Library/LaunchAgents/com.timearc.service.plist` using
`SMAppService`; its `BundleProgram` resolves
`Contents/MacOS/time-arc-service` even if the app is relocated. On Windows,
Settings → 追踪与应用 offers an opt-in
"随系统登录自动启动后台采集" toggle that registers a per-user logon task (B1
Route A). On Windows and Linux, closing the desktop window hides it to the
system tray; use the tray menu to restore the window or explicitly quit the UI.
On macOS the red button closes the window and the app keeps running — reopen it
from the Dock or the status item, and quit with ⌘Q. The desktop nav is
**首页 (Memory Lake) · 日历 · 统计 · 设置 · 备忘**,
with **记忆湖 / Monthly Recap** pinned at the bottom; the Timer page opens when a
calendar to-do starts timing. Memory Lake is the landing page.

### Data Location

| Platform | Path                                                     |
|----------|----------------------------------------------------------|
| Windows  | `%LOCALAPPDATA%\TimeArc\usage\`                           |
| macOS    | `~/Library/Application Support/TimeArc/usage/`            |
| Linux    | `${XDG_CONFIG_HOME:-~/.config}/TimeArc/usage/`            |

Files written in the usage directory:

- `usage_config.json` - UI-written service configuration and DB-directory pointer.

The service SQLite file is separate from the usage directory. Its filename is
locked to `timearc_service.db`, and it defaults to the platform service-data directory:
`%APPDATA%\TimeArc\service\timearc_service.db` on Windows,
`~/Library/Application Support/TimeArc/service/timearc_service.db` on macOS, and
`${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db` on Linux.
It is written only by the service and contains only `apps`,
`frontmost_sessions`, and `media_sessions`. The UI opens it read-only as the
sole automatic-usage history source.

The GUI has its own SQLite file, `timearc.db`, in Qt's app-data location. It is
written only by the GUI and stores settings, tags, manual projects/sessions,
mobile sync tables, and UI-private state.

**Choosing a different location (D2).** Only the database directory is
redirectable (a larger disk, an external/synced volume) via the `db_dir` key in
`usage_config.json` (in the fixed usage directory above). Both processes read
the same directory pointer — the UI read-only service connection and the service
in `get_database_path()` — and append `timearc_service.db`. Missing or
malformed config falls back to the default; stale `db_path` keys are ignored and
removed by the next database-location write.
Settings → 导入导出 → **服务数据库目录** updates only this pointer. The GUI does
not copy, vacuum, restore, or write `timearc_service.db`; the service creates and
writes the file in the selected directory after restart. A **还原默认位置** button
clears the pointer.

Desktop manual projects, timer sessions, calendar to-dos, night mode, and the
memo blackboard doc now read/write `timearc.db`. Existing QSettings data
for projects/sessions, calendar todos, and night mode is
migrated once on startup when possible. The migration is idempotent and keeps
the legacy QSettings data in place; it does not make SQLite the only source
for automatic foreground/media usage; that history comes from service-owned
`timearc_service.db`.

A separate log produced by the Qt message handler (harness journal) is
written to `<GenericDataLocation>/TimeArc/logs/harness-qt.log`.

### TimeArc Service

The service samples foreground windows and per-process audio every
second (configurable via `TIMEARC_USAGE_POLL_INTERVAL_MS`). The idle
threshold defaults to 60 s (`TIMEARC_USAGE_IDLE_THRESHOLD_MS`) but is
**overridable at startup** via `usage_config.json` `idle_threshold_ms`;
`track_enabled=false` in that file makes the service collect nothing and
exit (a true pause — never a deletion). It guarantees a single running
instance via the named mutex `Local\TimeArcUsageService` on Windows, and a
`Ctrl+C`, console close, or `--stop` triggers an orderly flush of the
current session.

### Configuration

`usage_config.json` (in the fixed usage dir) is the one cross-process config
file: the UI writes it and the service reads it via the bundled Parson parser.
It carries the `db_dir` redirect (D2) and the H5 `idle_threshold_ms` /
`track_enabled` keys; both writers do an atomic read-modify-write that preserves
the other's keys. Other UI preferences live in the SQLite settings table.

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
- [x] Complete the SQLite history migration (A1 S1–S5): backfill legacy data,
      make `timearc_service.db` the sole history store, and retire the legacy
      history stream.
- [x] Compile Qt as dynamically-linked libraries in release builds to satisfy the
      LGPL-3.0 combination posture (F1). Qt already links dynamically — verified by
      `tools/verify-linkage.ps1` (Qt6*.dll imports, no static Qt) — and
      `tools/package-release.ps1` produces a portable package bundling the relink-able
      Qt/MinGW DLLs + `LICENSE` + `licenses/` + `NOTICE.txt`; the macOS release
      script similarly deploys private Qt frameworks and licenses into `TimeArc.app`.
- [x] Add an in-app licenses page surfacing all third-party texts (F2). Shipped
      at Settings → 导入导出 → 「关于与开源许可」: per-component name, version, and
      full, offline-readable license text (`resources/licenses/`, qrc-embedded).
- [ ] Wire Parson in as the JSON parser for user preferences /
      configuration.
- [ ] Evolve the "Memory Lake" Daily Cards: the six local card types
      (mainline, top-app, focus-block, entertainment, contrast, flip) plus the
      activity segmenter and keyword classifier ship. Still to do: a privacy
      filter for sensitive apps, user-editable categories, card persistence,
      and a confirmed-summary AI pass.
- [x] Add export/backup and restore flows for SQLite-backed desktop data.
      Shipped GUI `timearc.db` backup via `VACUUM INTO` + validated restore;
      retention (S3) deferred.
- [x] Add a safe database-directory migration flow for user-selectable data
      locations (D2). A cross-process `db_dir` pointer in `usage_config.json`
      (read by the UI read-only service connection and the service
      `get_database_path`, with `timearc_service.db` appended) + a Settings →
      服务数据库目录 pointer update and 还原默认位置 button.
- [ ] Expand local memo management only as local/offline tooling; do not
      describe it as AI chat unless an actual AI feature is added later.
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
| Qt 6      | LGPL-3.0 (with exceptions)| dynamic | Required for GUI + QML + Svg. Platform release scripts bundle replaceable DLLs/frameworks (LGPL posture). |
| SQLite    | Public domain             | static  | Vendored under `thirdparty/sqlite3/`; used by the database layer and service storage. |
| Parson    | MIT                       | static  | Vendored under `thirdparty/parson/`. Will back user config. |

Full license texts for every component above ship in `resources/licenses/*.txt`
(embedded in the qrc, so they are readable offline) and are viewable in-app at
Settings → 导入导出 → 「关于与开源许可」, which also shows each component's version
(Qt 6.11.1, SQLite 3.51.3, Parson 1.5.3). SQLite is public domain and carries no
license text, so its entry ships the author's blessing plus an explicit
"public domain — no license text" note. When a new third-party component is added
under `thirdparty/`, add its text to `resources/licenses/`, register it in
`resources/CMakeLists.txt`, and add a row to the in-app page — see
[`.harness/rules/06-licensing.md`](.harness/rules/06-licensing.md) §4.
