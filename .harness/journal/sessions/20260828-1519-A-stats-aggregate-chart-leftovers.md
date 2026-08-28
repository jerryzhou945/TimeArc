# 20260828-1519 · Track A · Remove retired aggregate-chart leftovers

**Goal.** Delete never-instantiated QML left behind by the aggregate-parity rework.
Observable behavior unchanged.

## Three sub-areas (entry requirement)

1. `DesktopStatsPage.qml` inline components `StatsHeatmap`, `StatsLineChart`,
   `StatsYearRhythm` — declared, never instantiated. `docs/superpowers/plans/
   2026-08-22-desktop-stats-aggregate-parity.md` §111 removed their *instances*
   and left the declarations behind.
2. Helpers orphaned by (1): `heatWeekLabels()`, `heatDateLabel()`,
   `heatTooltipText()` — each reachable only from `StatsHeatmap`.
3. `I18n.js` entries orphaned by (1)+(2): `weekdaysHeat()` and the
   `heatTooltip` / `heatTooltipEmpty` templates, dropped from all three
   sentence tables together so zh/ja symmetry holds.

**Predicted diff:** ~280 net deleted. **Actual:** 283 lines from
`DesktopStatsPage.qml` (2608 → 2325), 12 from `I18n.js`. Under the 300 ceiling;
the remaining three dead components are a separate session by that rule.

## Deliberately kept

- `heatColor()` and `computeHeat()` — still live: `computeHeat` feeds
  `activePeriodUnitCount()` (the month view's "recorded days" figure) and the
  export JSON's `heatmap` field. Only its *rendering* was retired.
- `monthShortLabels()`, `weekdayShortLabels()` — still used by `computeYearBars`
  and `computeWindowDailyBars`.
- `vmHeat`, `vmLine`, `vmKeywords`, `vmRanking` — all still consumed by
  `buildExportJson()`.

## Verification

- `tools/build.py` clean; `qmlcachegen` recompiled `DesktopStatsPage.qml` and
  `I18n.js`; no new warnings.
- Static suite green: `stats_period_layout`, `desktop_ux`, `i18n_source_coverage`,
  `i18n_duplicate_keys`, `i18n_settings_dialog`, `resource_manifest`,
  `mobile_qml`, `about_settings_page`.
- No reference to any removed symbol survives anywhere in `qml/`, `src/`, `tests/`.

## No-behavior-delta statement (for the commit body)

Observable behavior unchanged: every removed symbol was unreachable from the
rendered tree, verified by instantiation count and by grep across the repo. The
service is untouched, so no service-DB smoke comparison applies — this session
does not build, link, or alter anything on the sampling path.
