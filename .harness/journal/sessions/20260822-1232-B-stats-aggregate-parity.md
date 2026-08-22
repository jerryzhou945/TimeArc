# B — Desktop statistics aggregate parity

Goal: make weekly, monthly, and yearly desktop statistics match the approved aggregate demo layout using real TimeArc data.

Service side: no background-service behavior, storage contract, schema, or sampling code changes in this session; the UI continues reading the existing service-owned journal through `UsageStatManager`. The UI manager may expose the maximum end time already present in its aggregated intervals as `lastUsedUnixSec`.

UI side: normalize period trend/category data in the statistics view model, render the same summary/trend/category/ranking grid for week/month/year, and keep the complete application library below it while leaving the daily clock unchanged.

Expected files: `qml/desktop/pages/DesktopStatsPage.qml`, `qml/desktop/pages/StatsViewModel.js`, `src/services/usage_stat_manager.cpp`, `tests/stats_view_model_test.js`, `tests/stats_period_layout_static_test.py`, `tests/desktop_ux_static_test.py`, `README.md`. Rule impact: `rules/01-architecture.md` and `rules/04-ui-conventions.md` remain accurate and need no edit. Frozen files and background-service sources are out of scope.

Progress:

- [x] Add failing aggregate behavior and topology tests.
- [x] Implement aggregate data helpers.
- [x] Replace weekly/monthly/yearly QML layouts.
- [x] Verify tests, build, runtime, Qt log, and harness.

Outcome: week/month/year now share the approved summary + trend + category + Top-5 ranking topology; the full application library adds period, lifetime, and latest-record columns. Node/Python focused checks and `timearc_db_smoke` passed, harness build `20260822-125008-build.log` succeeded, and the relaunched Windows app remained responsive with no Qt harness log generated. A first link attempt was blocked by the running executable and one later compile exposed a duplicated field placement; both failures were journaled and corrected before the fresh successful build.
