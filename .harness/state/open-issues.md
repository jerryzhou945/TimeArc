# Open Issues

Known-broken or known-incomplete things. This is the working document; once
an item is fixed, move it out of here and into a session log / error report.

Keep entries short. Link to a rule or file where possible. Entries should
answer: *what's wrong, where's the code, what's the minimum fix?*

> Actionable, dependency-ordered backlog (track tags + change-proposal flags):
> [`../../docs/implementation-backlog.md`](../../docs/implementation-backlog.md).

## Platform

- **Linux service is empty.** `src/service/linux/main.c` is a 0-byte file.
  Needed: X11 + Wayland foreground sampling, idle detection, audio (likely
  PipeWire / PulseAudio), and a single-instance guard. See
  [`../rules/02-platform-boundaries.md`](../rules/02-platform-boundaries.md) §3.
- **macOS service does not sample yet.** `TimeArcService.swift` is
  `RunLoop.current.run()` with no tracker. `AppEnv.swift` primitives are
  ready. The Windows `usage_tracker.c` loop is the reference contract.
- **Windows service is not a real service.** `win_service.c` has three TODO
  stubs. The current binary is a console exe.

## Storage

- **SQLite primary-source migration (A1) S1–S4 DONE** (`CHARTER` v0.2). UI now
  reads usage history from SQLite (primary; JSONL fallback when DB missing/empty);
  enable-before JSONL tail backfilled once (idempotent). Remaining = **A1 S5**
  (retire JSONL writing after a soak). Plan:
  [`a1-…-kickoff`](../../docs/a1-sqlite-storage-migration-kickoff.md).
- **UTF-8 is not validated.** `write_json_string`
  (`src/service/windows/storage/usage_storage.c:140-175`) only JSON-escapes; it does
  not check input bytes are valid UTF-8 (no TODO in source). Fix before cross-platform sync.
- **Windows `rename` is non-atomic over existing files.** `usage_storage.c`
  already `remove`s first; revisit if we move to SQLite with WAL.

## UI

- ~~**Memory Lake is a placeholder page.**~~ **Replaced** by a 1:1 port of the
  `MemoryLakeDesign/` prototype (`qml/desktop/memorylake/`). Renders **demo data**.
- **Memory Lake real-data wiring (phase E).** Desktop **done** (Phase 1 daily view +
  Phase 2 monthly recap): `MemoryLakeMock.js` replaced by read-only `UsageStatManager`
  data + `DailyCardService::memoryLake{Day,Recap}` local templates; C++ aggregation added
  (no schema change): per-day month series, last-month compare, category share, time-of-day
  peak, per-app sessions; cross-app focus-block task summary; window-title-aware category
  classifier (`系统` bucket); icon-dominant-color blended background + covers. **Still
  open:** mobile equivalent; classifier long-tail keyword coverage (`A4` — uncommon apps
  still fall to 其他). Implementation issues + resolutions (A1–A7, B1–B11):
  `docs/memory-lake-integration-issues.md`; per-surface plan:
  `docs/memory-lake-backend-integration-plan.md` (also `…-implementation-plan.md` §4).
- **Third-party license page missing.** Main README TO-DO. Required by GPL +
  Qt LGPL combination; see
  [`../rules/06-licensing.md`](../rules/06-licensing.md) §4.
- **Frameless window — native snap-layouts fly-out deferred (Step 2).** PR #18
  shipped pure-QML frameless chrome (`qml/desktop/components/WindowChrome.qml`)
  + Win11 DWM rounded corners/shadow (`main.cpp::applyWin11RoundedCorners`). The
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

- **Qt is not yet dynamically linked for distribution builds.** Still linking
  targets as-is; LGPL compliance not proven for release.
- **No JSON parser wired for user config.** Parson is bundled but unused;
  README TO-DO lists "JSON parser for user preferences".

## Harness itself

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
- ~~No track enforcement in slugs.~~ **Done.** Pass 6 in
  `harness_check.py` enforces `YYYYMMDD-HHMM(SS)-[ABC]-kebab.md`.
