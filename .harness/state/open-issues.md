# Open Issues

Known-broken or incomplete; keep entries short and move fixed items to a session log.
> Actionable backlog: [`implementation-backlog.md`](../../docs/implementation-backlog.md).

## Platform

- **Linux service is empty.** `src/service/linux/main.c` is a 0-byte file.
  Needed: X11 + Wayland foreground sampling, idle detection, audio (likely
  PipeWire / PulseAudio), and a single-instance guard. See
  [`../rules/02-platform-boundaries.md`](../rules/02-platform-boundaries.md) §3.
- **macOS validation/packaging still open.** Helper now has foreground/media,
  config, single-instance and LaunchAgent registration; UI uses `SMAppService`
  with the embedded production plist; `tools/build-macos.sh` automates Qt deployment,
  signing/notarization and DMG creation. Remaining: credentialed release,
  runtime/Accessibility smoke, and clean-machine QA.
- **Windows background autostart shipped (B1 Route A).** `win_service.c` verbs
  + Settings toggle register an opt-in per-user logon task; SCM Session-0
  (Route B) deferred. See [`B1 kickoff`](../../docs/b1-windows-service-scm-kickoff.md).
- **Windows idle counter breaks after ~49.7 days uptime.** `idle_win.c` mixes 64/32-bit ticks; use wrap-safe `DWORD` subtraction.

## Storage

- **SQLite usage migration (A1) — DONE** (`CHARTER` v0.9). `timearc_service.db`
  is the sole history store; UI is read-only. [`kickoff`](../../docs/a1-sqlite-storage-migration-kickoff.md).
- **Whole-DB backup/restore (D1) — DONE (S1+S2, PR #40).** `DatabaseManager`
  `backupDatabase`/`inspectBackup`/`restoreDatabase` + Settings UI; S3 retention deferred.
- **Cross-device sync E1-E9 is not implemented.** Approved design and live
  checklist: `docs/superpowers/specs/2026-07-24-cross-device-sync-design.md`
  and `docs/cross-device-sync-progress.md`.

## UI

- ~~**Memory Lake is a placeholder page.**~~ **Replaced** by a 1:1 port of the
  `MemoryLakeDesign/` prototype (`qml/desktop/memorylake/`). Renders **demo data**.
- **Memory Lake real-data wiring (phase E).** Desktop **done** (Phase 1 daily view +
  Phase 2 monthly recap): `MemoryLakeMock.js` replaced by read-only `UsageStatManager`
  data + `DailyCardService::memoryLake{Day,Recap}` local templates; C++ aggregation added
  (no schema change): per-day month series, last-month compare, category share, time-of-day
  peak, per-app sessions; cross-app focus-block task summary; window-title-aware category
  classifier (`系统` bucket); icon-dominant-color blended background + covers. 2026-06-13
  alpha pass covered Apex Legends / NVIDIA Container / common Windows system process naming
  and grouping. 2026-06-14 C pass added WeChat/剪映专业版 naming, app icon
  fallback hardening, Memory Lake card-tip fadeout, day-mode sidebar icon selection,
  and GitHub-style monthly stats heatmap/layout fixes. **Mobile equivalent is
  implemented** with real usage, four ranges, Memory Lake, wallpaper and sharing;
  device/ROM validation remains. **Still open:** broader classifier long-tail keyword
  coverage (`A4` — uncommon apps can still fall to 其他). Implementation issues + resolutions (A1–A7, B1–B11):
  `docs/memory-lake-integration-issues.md`; per-surface plan:
  `docs/memory-lake-backend-integration-plan.md` (also `…-implementation-plan.md` §4).
- **Third-party license page — shipped (F2).** Settings → 导入导出 →「关于与开源许可」
  surfaces each component's name / version / full text offline (`resources/licenses/`,
  qrc-embedded); see [`../rules/06-licensing.md`](../rules/06-licensing.md) §4.
- **Frameless window — native snap-layouts fly-out deferred (Step 2).** PR #18
  shipped pure-QML frameless chrome (`qml/desktop/components/WindowChrome.qml`)
  + Win11 DWM rounded corners/shadow (`main.cpp::applyWin11RoundedCorners`);
  macOS now uses a borderless full-height sidebar with embedded traffic lights. The
  Win11 hover-maximize **snap-layouts fly-out** and maximize-over-taskbar
  precision need a native `WM_NCCALCSIZE`/`WM_NCHITTEST` pass in `main.cpp`; not
  done. See agent memory `timearc-frameless-window`.
- **Memory Lake memo blackboard overlay (备忘) — implemented (merged PR #14).**
  Modal overlay (entry-as-action + flip-guard) replicating v88 `#memoOverlay`: freehand
  pen/eraser ink; sticky notes (due date/time picker + done checkbox) + resizable text
  layers; multi-page archive folder (per-page ink+objects, **max 10**); marquee **select
  tool** (ink + objects → copy/delete/move/scale, clipboard **Ctrl+C/V cross-page**, **Ctrl+Z
  undo**); pomodoro + completion overlay; **Dynamic-Island** auto-hide chrome. Content drawn
  in a fixed **1920×1080 logical board scaled-to-fit (16:9)**, persisted UI-private via
  `SettingsRepository` (`memoryLakeMemoDoc`, no new C++; off the disk contract). Canvas
  pitfalls + patterns recorded in agent memory `timearc-qml-canvas-memo`. **Pending:** manual
  in-app QA (draw / drag / marquee / hover-reveal / fullscreen-scale / pomodoro). PR #18
  (2026-06-05/06) added: toolbar hover fix (topZone hover-block), page rename, and the 7
  functional-gap features — pen color palette, pen/eraser width, clear-canvas (+confirm),
  page drag-reorder, page thumbnails, sticky-note signature, pomodoro persistence (functional
  doc §A #1–#10 now all done). Still deferred (§A #11–#14): pomodoro sound + work-rest cycle +
  progress-ring, keyboard tool-switch, conic-aura shader. Specs `docs/memory-lake-memo-*`.

## Build / distribution

- **Qt dynamic link + release packaging — shipped (F1).** Windows now has the
  full `build-windows.ps1` entry point; the older linkage/package utilities remain.
- **No JSON parser wired for user config.** Parson is bundled but unused;
  README TO-DO lists "JSON parser for user preferences".

## Harness itself

- ~~Windows DB smoke named QSettings escaped the test IniFormat path.~~ **Fixed:** named legacy settings now use `defaultFormat()` with an isolated UserScope fixture.
- ~~`record_error.py` is a stub.~~ **Implemented.** Writes report, appends
  JSONL, updates INDEX.md atomically. Exit 0/1/2.
- ~~`harness_check.py` is a stub.~~ **Implemented.** 7 passes (line-budget,
  frozen hashes, CMake structure, platform isolation, journal hygiene,
  slug shape, track discipline). `--bootstrap` populates hashes.
- `preflight.py` — **new.** Session-start one-stop; wraps `--fast` audit.
- ~~`HarnessHooks.cmake` is still a stub.~~ **Implemented.** Defines
  `timearc_harness_enable` + `harness-check` target. Build-failure L1
  capture goes through `tools/build.py` (wraps `cmake --build`).
- ~~No runtime L2 capture.~~ **Wired.** `src/services/harnesslogger.cpp`
  tees Qt Warning/Critical/Fatal to `<DataLocation>/TimeArc/logs/
  harness-qt.log`; `tools/scan_qt_log.py` drains it into L2 reports.
  Still needs a Qt build to smoke-test.
- ~~No track enforcement in slugs.~~ **Done.** Pass 6 enforces `YYYYMMDD-HHMM(SS)-[ABC]-kebab.md`.
