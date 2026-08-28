# 20260828-1522 · Track A · Remove retired day-view card leftovers

**Goal.** Second and final pass of the stats-page dead-code removal, split from
`20260828-1519-A-stats-aggregate-chart-leftovers` to stay under the 300-line
ceiling in `tracks/A-stabilize.md`. Observable behavior unchanged.

## Three sub-areas (entry requirement)

1. `DesktopStatsPage.qml` inline components `StatsDayTimeline` (61),
   `StatsRankingList` (120), `StatsInsightCard` (109) — declared, never
   instantiated. Their instances were retired when the day view moved to the
   category clock and the detail rows moved into the app library.
2. `I18n.js`: the `openCount` template ("{count} opens"), reachable only from
   `StatsRankingList`. Removed from all three tables together.
3. `tests/stats_period_layout_static_test.py`: `dial` sliced the file between
   `component StatsCategoryClock` and `component StatsDayTimeline`, so deleting
   the latter would have broken the slice. Re-anchored to
   `component StatsAppLibrary`, the next surviving declaration — the slice
   covers the same text, and every assertion inside it is unchanged.

**Predicted diff:** ~290 net deleted. **Actual:** 292 from
`DesktopStatsPage.qml` (2325 → 2033), 3 from `I18n.js`.

## Test guards strengthened rather than dropped

`StatsDayTimeline` / `StatsRankingList` were asserted absent from the *day
section*, and `StatsHeatmap` / `StatsLineChart` / `StatsYearRhythm` /
`StatsInsightCard` absent from the *aggregate section*. Since all six are now
deleted outright, those guards assert against the whole file. A re-introduced
declaration is exactly what let them rot unnoticed, so this is the condition
worth pinning.

## Deliberately kept

`vmRanking`, `vmInsight`, `vmRecs`, `vmKeywords` all still feed
`buildExportJson()`; `vmInsight` also feeds the sidebar insight panel. Only the
retired *cards* are gone, not the data behind the export.

## Verification

- `tools/build.py` clean; no new warnings.
- Nine static suites green, including `stats_period_layout` and `desktop_ux`
  after the guard changes.
- Ran the built app with `selectedIndex` temporarily pointed at Stats, on the
  real cocoa plugin: page loads, no QML errors, process healthy for 6s until
  SIGTERM. Probe reverted; `DesktopAppShell.qml` clean in git.
- `scan_qt_log.py`: no warnings logged by that run.

## No-behavior-delta statement (for the commit body)

Observable behavior unchanged: every removed symbol was unreachable from the
rendered tree, verified by instantiation count, by grep across `qml/ src/
tests/`, and by loading the page in the built app. The service is untouched, so
no service-DB smoke comparison applies.

## Note for whoever commits this

Track C (`20260828-1449-C-stats-page-bug-investigation`) and both track A
sessions are all uncommitted in one working tree and overlap in
`DesktopStatsPage.qml`. They are disjoint edits — C changes logic in place, A
deletes whole component blocks — but they need three separate commits, C first.
