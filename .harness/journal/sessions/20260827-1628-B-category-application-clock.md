# Category application clock

Goal: Replace the crowded per-application daily clock with a category-grouped chronological dial whose selected category expands and reveals its details.

Service side: No service, database, sampling, or disk-contract change is required; the existing foreground/media segment groups remain the only source of truth.

UI side: `StatsViewModel.js` will merge nearby intervals by category inside the selected AM/PM half, preserve their real clock angles, and expose category totals and app summaries; `DesktopStatsPage.qml` will render the grouped arcs and lock a category selection on click.

Expected files: `qml/desktop/pages/StatsViewModel.js`, `qml/desktop/pages/DesktopStatsPage.qml`, `tests/stats_view_model_test.js`, and a user-facing statistics note. Frozen files, service code, schema, mobile QML, and CMake files are explicitly out of scope. Rule 04 applies; no rule text is expected to change.

Baseline: `python .harness/tools/build.py` passed before production edits on 2026-08-27.

Progress:

- [x] Add failing category-clock behavior coverage.
- [x] Implement category aggregation and the desktop dial interaction.
- [x] Build, test, run, and document the result.

Outcome: The desktop daily clock now derives exact category totals from the original segments, then uses display-only ten-minute dominant-category buckets. Adjacent buckets merge into broad annular sectors and a single isolated bucket between the same category is absorbed, while database records, all-app details, and exact totals remain unchanged. Hover and click still expand a category and reveal its duration-ranked apps. The page-level “visual path / next step” rail was removed globally, and the new clock title, subtitle, category label, hint, summary, and app list now follow Chinese/English/Japanese language modes. Focused JS/QML/i18n tests passed, the wrapped build passed, CTest passed 6/6, and the final binary launched; Qt produced no harness log. Automated screenshot inspection remained unavailable because the Windows Computer Use sandbox helper failed twice, so final visual acceptance is left to the already-open app.
