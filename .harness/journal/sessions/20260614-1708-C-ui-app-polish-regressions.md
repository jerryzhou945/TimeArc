# Goal

Fix user-reported UI regressions in app naming, Memory Lake hints/icons, sidebar icon theme, and statistics layout without changing the disk data contract.

# What happened

Related error report(s): `.harness/journal/errors/20260614-090851-C-ui-app-label-icon-card-regressions.md`.

Expected touches: `src/services/adapters/*`, `src/services/usage_stat_manager.cpp`, `tests/db_smoke.cpp`, `qml/desktop/`, `docs/`, and harness report files. Frozen files are not expected to change.

# Outcome

Implemented in five focused commits: `5c8e939`, `bbae8d1`, `d8b4b81`, `f023587`, and `f369f1f`, plus final runtime cleanup/docs commit `Fix runtime UI verification warnings`. Full build, `timearc_db_smoke`, clean app launch, `scan_qt_log.py` no-log result, and `harness_check.py` passed.
