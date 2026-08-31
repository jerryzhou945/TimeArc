# 20260828-1449 · Track C · Stats page bugs — investigation + fix

**Scope.** `qml/desktop/pages/DesktopStatsPage.qml`, `qml/desktop/pages/StatsViewModel.js`,
`qml/shared/I18n.js`, `src/services/usage_stat_manager.cpp`, `tests/stats_view_model_test.js`.
Investigation first, then all six defects fixed. No frozen file touched.

**Related error report(s)** (each carries its own §3–§5):
- `errors/20260828-065704-C-stats-period-label-i18n.md`
- `errors/20260828-065716-C-stats-category-id-vs-label.md`
- `errors/20260828-065716-C-stats-aggregate-fact-category.md`
- `errors/20260828-065729-C-stats-night-mode-stale-colors.md`
- `errors/20260828-065729-C-stats-hidden-apps-in-metrics.md`
- `errors/20260828-065729-C-stats-adapter-category-divergence.md`

**Also filed, not caused here and not fixed here:**
- `errors/20260828-071233-C-offscreen-teardown-segfault.md` — reproduces identically with
  this session's changes stashed, i.e. present at HEAD.
- `errors/20260828-071123-C-qt-warning-8cd3c75bff.md` — `scan_qt_log.py` picking up the
  pre-existing "Sans Serif" font-alias warning from the verification run.

**Carried in with the six:** two smaller defects on the same lines, fixed alongside rather
than left half-corrected — `weekMetrics` printed the raw process name instead of the row's
display name (ignoring user overrides), and day-view copy said "today" while period
navigation was showing a past day (`rangeLabel`, two metric subtitles, the share card's
kicker/title, the ring centre). Two new source strings, zh + ja both present.

**Verification.**
- `tools/build.py` clean: `qmlcachegen` compiled all three changed QML/JS files, C++ and link OK.
- Ran the built app with `selectedIndex` temporarily pointed at Stats: the page loads with no
  QML errors. That one-line probe was reverted and `DesktopAppShell.qml` is clean in git.
- `scan_qt_log.py` after the run: only the pre-existing font warning.
- `tests/stats_view_model_test.js` — all 77 checks pass, including 3 new ones. Node is absent
  on this host, so it was run under JavaScriptCore (`osascript -l JavaScript`) with `require`,
  `vm` and `structuredClone` shimmed; the assertions themselves are unmodified.
- Static suite green: `stats_period_layout`, `desktop_ux`, `i18n_source_coverage`,
  `i18n_duplicate_keys`, `i18n_settings_dialog`, `resource_manifest`, `mobile_qml`,
  `about_settings_page`, `macos_menu_bar`, `windows_tracking_parity`.

**Not fixed — belongs to track A, not this one.** Four inline components
(`StatsDayTimeline`, `StatsYearRhythm`, `StatsLineChart`, `StatsHeatmap`, ~330 lines) are
declared and never instantiated, and `computeHeat`'s per-day category pass now only feeds
`activePeriodUnitCount()` and the export JSON. Dead-code removal is a track A session.

**Open follow-up.** `AppVisual.modelCategory()` still prefers `adapterCategory` over
`category` for Home and Memory Lake. This session changed only the stats page's own
classifier; see the adapter-category report §5.
