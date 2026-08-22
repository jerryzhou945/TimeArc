# B · Desktop stats QML migration

**Goal.** Move the approved desktop HTML statistics design into the production QML page with real period and lifetime data, without changing collection behavior.

**Service side.** The background service continues to emit the existing `apps`, `frontmost_sessions`, and `media_sessions` rows through the frozen disk contract. This feature adds no sampling source, schema field, service configuration, or writer behavior; observed timing defects are documented for a separate Track C session.

**UI side.** `DesktopStatsPage.qml` consumes the existing `UsageStatManager` window, segment, and all-app APIs to render a default daily application clock, compact aggregate views, and a complete searchable app library with period and lifetime totals. Native icons continue through `AppVisual.js` and `AppIconImageProvider`.

**Expected files.** `qml/desktop/pages/StatsViewModel.js`, `qml/desktop/pages/DesktopStatsPage.qml`, `qml/CMakeLists.txt`, `tests/stats_view_model_test.js`, the stats report, this session log, and the implementation plan.

**Hands off.** Frozen CMake/data-bridge/database-path files, service tracker sources, SQLite schema, mobile QML, and the desktop homepage.

**Rules.** `rules/01-architecture.md`, `rules/02-platform-boundaries.md`, and `rules/04-ui-conventions.md`; no rule text change is expected because the existing boundaries remain valid.

**Baseline.** Build succeeds after stopping the running UI/service executables that held the build outputs. The service was restarted immediately; the UI remains closed until the QML implementation is ready for runtime QA.

**Outcome.** The production desktop statistics page now defaults to a daily application clock with real app icons and AM/PM focus, adds a 24-hour activity timeline and keeps the existing compact trend/category views for longer ranges. A searchable all-app library exposes both selected-period and lifetime totals, including apps with zero time in the selected period. The pure JavaScript view model is covered by Node regression tests and the QML build succeeds. No collection or disk-contract behavior changed; the Windows effective-time findings and the ordered Track C repair plan are documented in `docs/windows-effective-time-diagnosis-2026-08-22.md`.
