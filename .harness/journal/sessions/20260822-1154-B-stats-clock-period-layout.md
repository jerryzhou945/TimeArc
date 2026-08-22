# Session — stats-clock-period-layout

## Goal

Rebuild the desktop statistics day, month, and year presentations so the day dial reads as a clock and longer periods use their own clear, demo-aligned structures.

## Design

**Service side.** No producer, schema, sampling, or disk-contract change. The background service continues emitting the same foreground/media rows, including the newly bounded Windows checkpoints.

**UI side.** `DesktopStatsPage.qml` and its view-model presentation consume the existing aggregates. Day places restrained session blocks and app icons on a real clock scale, with focus details disclosed outside the dial. Month emphasizes calendar/weekly rhythm; year emphasizes a 12-month matrix and cumulative trend. The complete app-duration library remains available below every range.

## Scope

- Expected: `qml/desktop/pages/DesktopStatsPage.qml`, `qml/desktop/pages/StatsViewModel.js`, focused stats tests, prototype/docs only if the reference must stay synchronized.
- Keep off limits: service sources, database/schema, top-level CMake, Charter, mobile shell, and Home UI.
- Rule impact: `rules/04-ui-conventions.md` remains accurate; no rule edit expected.
- Baseline: harness build `20260822-115153-build.log`, six CTests, desktop UX checks, and harness check pass.

## Outcome

The shared four-card wall is now one flat overview strip. Day segments are assigned to three overlap-safe lanes; the clock draws 60 ticks, 12 hour labels, shaped time arcs, and at most eight collision-safe app icons while hover still exposes every segment. Month now leads with a period summary and large calendar heatmap, followed by weekly rhythm and Top apps. Year uses a period summary plus a dedicated 12-month rhythm matrix. The complete searchable app-duration library remains below every range.

`StatsViewModel` and production-layout regressions passed, as did the three prototype checks, desktop UX static checks, the harness build (`20260822-121010-build.log`), and all six CTests. Qt log scan produced no warning log. Manual smoke path: launch TimeArc, open 统计, switch 日/月/年, hover clock arcs, and confirm the all-app library remains below each view. This automation desktop could not enumerate the launched Qt window for a reliable screenshot, so final visual spacing still needs that normal-desktop smoke.
