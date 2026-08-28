# Error Report - stats-ring-quadratic-offscreen

## Metadata

- Level: **L2**
- Track: **C**
- Topic: stats-ring-quadratic-offscreen
- Recorded: 2026-08-26T09:52:48Z
- Session: `../sessions/20260826-1752-C-stats-ring-quadratic-offscreen.md`
- Platform: n-a (macOS dev host used for measurement)
- Tooling: temporary `console.warn` timing in `rebuild()` / `buildCategoryRingRuns`;
  differential + benchmark harnesses under `QT_QPA_PLATFORM=offscreen qml`

## 1. What happened

Switching the stats page to Month or Year froze the UI for ~3 seconds.

## 2. Evidence

Per-stage timing of `DesktopStatsPage.rebuild()`:

| range | TOTAL | rebuildCategoryRing | every backend C++ call |
|---|---|---|---|
| day | 20-37 ms | 15 ms | ~5 ms |
| week | 267 ms | 248 ms | ~8 ms |
| month | **3051 ms** | **2880 ms** | ~35 ms |
| year | **2918 ms** | **2872 ms** | ~30 ms |

Inside the ring, for the month window (3253 flattened rows):
`flatten=1ms  resolveOverlap=561ms  denoise=2298ms`.

And what that bought:

| range | ring input rows | runs | arcs displayed | clock card visible |
|---|---|---|---|---|
| day | 265 | 15 | 13 | yes |
| week | 972 | 74 | 12 | **no** |
| month | 3249 | 292 | 12 | **no** |
| year | 3249 | 292 | 12 | **no** |

## 3. Root cause

- Immediate cause: `rebuild()` called `rebuildCategoryRing()` for every range, but
  `StatsCategoryClock` is gated `visible: root.range === "day"`, and
  `reprojectCategoryRing()` only ever projects one 12-hour half of one day. Week /
  month / year therefore fed a whole window into the pipeline and discarded the result.
- Second cause: the pipeline is quadratic, so the discarded work exploded with
  window size. `ringResolveOverlap` rescanned every row at each of ~2N ticks;
  `ringSmooth` ran up to 2n+8 iterations, each re-coalescing the entire array
  through `ringCopyRun` (~21M fresh objects for a month).
- Why the harness did not prevent it: nothing tied "this view model is only
  rendered under condition X" to "only compute it under condition X", and the ring
  was introduced (session `20260826-1127-B-stats-category-ring`) sized against day
  data only, where both quadratics are invisible.

## 4. Fix

- Files changed: `qml/desktop/pages/DesktopStatsPage.qml`,
  `qml/desktop/pages/StatsViewModel.js`, `tests/stats_view_model_test.js`,
  `tests/stats_period_layout_static_test.py`
- Short description: (a) `rebuildCategoryRing()` returns early for non-day ranges
  and clears the four ring view-model properties; (b) `ringResolveOverlap` keeps
  the active rows in a lazy-deletion heap instead of rescanning; (c) `ringAbsorbAt`
  splices in place and `ringCoalesceInPlace` compacts without deep-copying.
- Result: month 3051 -> **86 ms**, year 2918 -> **60 ms**, week 267 -> **50 ms**,
  day unchanged. On identical input the pipeline alone is 4-6.5x faster
  (3200 rows: 1194 -> 184 ms).
- Commit: pending commit

## 5. Prevention

Not a one-off. Concrete harness upgrade: `rules/04-ui-conventions.md` should state
that a view model gated behind a `visible:` condition must be built behind the same
condition, and that any new ring/denoise-style pipeline gets a cost check at 10x
day-sized input before it ships. The static test now pins the day-only guard, and
`stats_view_model_test.js` pins the ring's observable output against values
captured from the pre-rewrite implementation.

## 6. Notes

The rewrite was validated by differential testing rather than by reading: 840
randomized + adversarial cases (durations and gaps straddling the 60s
minSeconds/bridge boundaries, exact adjacency, nesting, duplicates) comparing old
vs new `buildCategoryRingRuns` / `projectCategoryRing` / `ringCategories`, all
identical. The harness was itself mutation-tested: flipping the bridge boundary
`<=`->`<` produced 6 failures and turning `splice(index, 2)` into
`splice(index, 1)` produced 592, so "0 fails" has real detection power. One
mutation (reversing the heap index tiebreak) is undetectable, and provably inert:
it only fires when two rows share seconds, start AND groupKey, in which case
category, display name and key are identical anyway.
