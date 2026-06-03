# Open Issues

Known-broken or known-incomplete things. This is the working document; once
an item is fixed, move it out of here and into a session log / error report.

Keep entries short. Link to a rule or file where possible. Entries should
answer: *what's wrong, where's the code, what's the minimum fix?*

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

- **SQLite path is reserved but unused.** `timearc_storage_init_sqlite` and
  `timearc_storage_write_sqlite` are no-ops. Migration plan in
  [`../rules/03-data-contract.md`](../rules/03-data-contract.md) §4.
- **UTF-8 is not validated.** `write_json_string` in
  `src/service/windows/storage/usage_storage.c` has a TODO saying so; must be
  addressed before enabling cross-platform sync.
- **Windows `rename` is non-atomic over existing files.** `usage_storage.c`
  already `remove`s first; revisit if we move to SQLite with WAL.

## UI

- ~~**Memory Lake is a placeholder page.**~~ **Replaced** by a 1:1 port of the
  `MemoryLakeDesign/` prototype (`qml/desktop/memorylake/`). Renders **demo data**.
- **Memory Lake real-data wiring (phase E).** Desktop **done** (Phase 1 daily view +
  Phase 2 monthly recap): `MemoryLakeMock.js` replaced by read-only `UsageStatManager`
  data + `DailyCardService::memoryLake{Day,Recap}` local templates; C++ aggregation added
  (no schema change): per-day month series, last-month compare, category share, time-of-day
  peak, per-app sessions; generative covers (appColor + `image://appicon`) for arbitrary
  apps. **Still open:** mobile equivalent; Phase 3 polish (icon-derived background color
  `B4`; classify keyword coverage `A4`/`B5` — see `docs/memory-lake-integration-issues.md`).
  Full per-surface plan: `docs/memory-lake-backend-integration-plan.md`
  (also `…-implementation-plan.md` §4).
- **Third-party license page missing.** Main README TO-DO. Required by GPL +
  Qt LGPL combination; see
  [`../rules/06-licensing.md`](../rules/06-licensing.md) §4.

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
