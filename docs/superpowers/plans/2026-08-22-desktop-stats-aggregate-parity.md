# Desktop Statistics Aggregate Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the desktop weekly, monthly, and yearly statistics views share the approved demo layout while rendering only real TimeArc data.

**Architecture:** Keep the daily clock view unchanged. Normalize weekly, monthly, and yearly data into one aggregate view-model, then render the same four aggregate components for every non-day range: summary, trend, category distribution, and ranking; the existing full application library remains below them.

**Tech Stack:** Qt 6, QML, JavaScript view-model helpers, Node assertions, Python repository checks.

**Spec:** `docs/prototypes/timearc-stats-rework-v1.html`

## Global Constraints

- Work directly in `D:/TimeArc/time-arc`; do not create a git worktree.
- Do not change the daily clock layout or the desktop home page.
- Weekly trend uses seven days, monthly trend uses calendar-week buckets, and yearly trend uses twelve months.
- Summary facts must be deterministically derived from recorded categories and trend peaks.
- The ranking remains Top 5; the application library remains unlimited and includes inactive applications.
- Do not change background-service sampling/storage, schemas, CMake files, or frozen files in this Track B session; the UI-layer `UsageStatManager` may expose an already-read record's latest end time.
- Keep day/night colors sourced from the desktop theme contract.

---

### Task 1: Specify aggregate view-model behavior

**Files:**
- Modify: `tests/stats_view_model_test.js`
- Modify: `tests/stats_period_layout_static_test.py`
- Modify: `tests/desktop_ux_static_test.py`

**Interfaces:**
- Consumes: raw application rows and trend rows already returned by `UsageStatManager`.
- Produces: test contracts for `buildCategoryDistribution(apps, limit)`, `buildAggregateFact(range, categories, trendRows)`, and the shared QML aggregate topology.

- [ ] **Step 1: Write failing behavior assertions**

Add literal expectations proving category totals, percentages, app-name summaries, peak-label facts, month week labels, and the common QML order `StatsAggregateSummary → StatsBarChart → StatsCategoryDistribution → StatsRankingList` for week/month/year.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
node tests/stats_view_model_test.js
python tests/stats_period_layout_static_test.py
python tests/desktop_ux_static_test.py
```

Expected: the new aggregate helper/component assertions fail because they do not exist yet.

### Task 2: Build the aggregate data model

**Files:**
- Modify: `qml/desktop/pages/StatsViewModel.js`
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Modify: `src/services/usage_stat_manager.cpp`

**Interfaces:**
- Consumes: `vmApps`, `vmBars`, `vmLine`, category strings, application identities, and recorded seconds.
- Produces: `vmCategories`, `vmTrendBars`, and `vmAggregateFact`, with category rows shaped as `{name, seconds, time, percent, appsText}` and trend rows shaped as `{label, seconds, ratio, valueText}`; lifetime application rows also expose `lastUsedUnixSec` computed from their existing intervals.

- [ ] **Step 1: Implement category aggregation**

Group applications by category, sum seconds, sort descending, compute percentages from the literal total, and preserve up to three distinct application names per category.

- [ ] **Step 2: Normalize month trend buckets**

Keep weekly and yearly bar shapes unchanged; add `第1周…第5周` labels, `ratio`, and `valueText` to monthly calendar-week buckets.

- [ ] **Step 3: Implement deterministic summary facts**

Compose the fact from the largest category and the largest trend bucket; return an empty string when either side has no recorded data.

- [ ] **Step 4: Expose the most recent existing interval end**

While `UsageStatManager` is already aggregating an application's intervals, compute their maximum `end` and add it as `lastUsedUnixSec`; do not add a database query or schema field.

- [ ] **Step 5: Run the view-model test and verify GREEN**

Run `node tests/stats_view_model_test.js` and expect `stats_view_model_test: pass`.

### Task 3: Replace the three aggregate layouts

**Files:**
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Modify: `README.md`

**Interfaces:**
- Consumes: `vmTotalSec`, `vmPeriodLabel`, `vmTrendBars`, `vmCategories`, `vmRanking`, `vmLibraryRows`, and `vmLifetimeTotalSec`.
- Produces: a responsive 12-column aggregate layout shared by `week`, `month`, and `year`.

- [ ] **Step 1: Add the compact summary component**

Render period context, total time, active-unit count, and the deterministic fact in the left four columns.

- [ ] **Step 2: Restyle the trend component**

Render the right eight columns with a restrained solid accent bar, always-visible values, range-specific subtitle, and seven/five/twelve columns.

- [ ] **Step 3: Add category distribution**

Render category dot, category name, example applications, duration, and percentage as compact divided rows.

- [ ] **Step 4: Align ranking with the demo**

Render five ranked rows with native application icons, category/session metadata, duration, and percentage without nested row cards.

- [ ] **Step 5: Use one topology for week/month/year**

Remove `StatsHeatmap`, `StatsLineChart`, `StatsYearRhythm`, and aggregate `StatsInsightCard` instances from the three range sections. Keep the day view and the unlimited application library unchanged, adding the library's recent-record column from `lastUsedUnixSec`.

- [ ] **Step 6: Update the README feature description**

Document that non-day desktop statistics share the aggregate summary/trend/category/ranking/application-library structure.

- [ ] **Step 7: Run layout checks and verify GREEN**

Run:

```powershell
python tests/stats_period_layout_static_test.py
python tests/desktop_ux_static_test.py
```

Expected: both scripts report their pass messages.

### Task 4: Build and runtime verification

**Files:**
- Modify: `.harness/journal/sessions/20260822-1232-B-stats-aggregate-parity.md`

**Interfaces:**
- Consumes: the finished QML and tests.
- Produces: build, QML-log, and harness evidence recorded in the session journal.

- [ ] **Step 1: Run focused tests**

Run the two Python statistics checks and the Node view-model check.

- [ ] **Step 2: Build through the harness**

Run `python .harness/tools/build.py` and require exit code 0.

- [ ] **Step 3: Launch and inspect the desktop statistics ranges**

Open TimeArc, switch among week/month/year, and verify the common topology, real values, hover states, and application-library scrolling.

- [ ] **Step 4: Scan the Qt log**

Run `python .harness/tools/scan_qt_log.py` and require no new QML warnings.

- [ ] **Step 5: Run the harness audit**

Run `python .harness/tools/harness_check.py` and require exit code 0 before any integration action.
