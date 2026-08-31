# Error Report - stats-day-window-no-clip

## Metadata

- Level: **L2** | Track: **C** | Platform: macos
- Topic: stats-day-window-no-clip | Recorded: 2026-08-28T09:47:18Z
- Session: `20260828-1747-C-stats-day-window-clip`
- Tooling: Claude Code (Opus 5); sqlite3 + throwaway harness on the real read layer

## 1. What happened

Stats day totals can exceed 24h: windowed read paths filter by `start_unix_sec`
only and never clip the interval, so a session starting inside the day charges
its whole cross-midnight span there (Aug 3 printed 36h19m vs a 24.00h union).

## 2. Evidence

Repro: Stats → Day → back to Aug 3 2026. Header reads `36h 19m`; the legend
reads `System 32h50m` on a 12-hour dial. Three calibers over that day's rows,
plus the two rows that explain it:

```
SUM(duration_sec) WHERE start in day  36.32h  <- what the page printed
union of those spans clipped to day   24.00h
SUM(active_sec) (idle excluded)        4.58h

com.apple.loginwindow  17.60h  active_sec=3064   Aug 3 18:43 -> Aug 4 12:19
com.apple.loginwindow  13.50h  active_sec=1062   Aug 3 00:07 -> Aug 3 13:37
```

36.32h == 36h19m exactly. Both rows *start* on Aug 3, so both are charged there
whole — 31.1h from one app on one day. `com.apple.loginwindow` →
`app:macos-shell`/`system`, i.e. the "System 32h50m" legend row.

The writer is not at fault: across all 17,358 `frontmost_sessions` rows adjacent
pairs overlap 6 times for 0.01h total. The service emits a clean non-overlapping
timeline; the read layer mis-slices it. Only 2 of 20 days exceed 24h, both
pre-dating the `maxSessionSec = 300` flush of 2026-08-07 (`677d856`) — under
that cap midnight is straddled by at most 300 s, so the defect had gone latent,
but it stays a live invariant break for any restored DB or raised cap.

## 3. Root cause

- Immediate cause: every windowed read path in `usage_stat_manager.cpp` decided
  membership on `record.startUnixSec` alone, then consumed the **whole**
  interval — `activeSoftwareForWindow`/`foregroundSegmentsForWindow` via
  `start >= winStart && start <= winEnd`, and `dailySecondsForMonth`,
  `dailySecondsForRange`, `monthlySecondsForYear`, `focusStatsForWindow` by
  start-day. Nothing intersected interval with window, so a session beginning
  inside a bucket contributed its full cross-midnight span to it, and the tail
  of a session begun yesterday vanished from today.
- Underlying cause: the read layer had no shared notion of "a time window". Each
  path re-expressed one in its own terms (a `QDate` pair, a unix pair, a
  `d.month()` test), so the same boundary reasoning was written six times and
  could not be fixed once. `mergedIntervalSeconds()` de-overlaps *within* an app
  group, making the totals look principled enough to hide the missing clip.
- Why the harness missed it: no rule states that one local day cannot exceed 24h,
  and no fixture contains a cross-midnight session. Parity tests cover the
  *writer*; the reader had only grep-shaped static tests on other concerns.

## 4. Fix

- Files: `src/services/usage_stat_manager.{h,cpp}`, `tests/stats_day_window_clip_static_test.py` (new).
- Short description: one `ClipWindow` (unix half-open `[start, end)`) shared by
  every windowed read path; records are selected by **intersection** and clipped
  before reaching `mergedIntervalSeconds()`. `clipWindowForBounds()` converts the
  closed `[start, end]` QML passes; `clipWindowForDates()` does the same for a
  local-date range via `startOfDay()`, not `+86400`, so DST days stay correct.
  Day/month bucketing runs each record through `forEachLocalDaySlice()`,
  splitting at local midnight. Category weighting uses the clipped length. The
  orphaned start-day helpers `matchesRange()`/`matchesYearMonth()` are removed.
- Verification (throwaway harness on the real read layer + real DB):
  ```
  2026-08-03   24.00h  (was 36.32h)     2026-08-26   10.91h  unchanged
  2026-08-18    8.82h  unchanged        week Aug3-9: total 76.74h == bars 76.74h
  ```
  Every day now reports <= 24h except Aug 4/5 at 24.06h — a **different** defect
  (§4b). `ctest` 3/3; the four static tests that read this file pass.
- Commit: pending commit

### 4b. Follow-ups (separate defects, filed to `state/open-issues.md`)

The headline is `sum(apps[i].seconds)` and `aggregateSoftware()` de-overlaps only
*within* an app group, while `refreshHistoryFromSqlite()` folds both session
tables into one list — so audio under a *different* foreground app double-counts
(227 s Aug 4, 209 s Aug 5: exactly the residual above).
`StatsService::calculateUnionDuration()` already has the right caliber. Second,
the read layer consumes `duration_sec` and never `active_sec`, so locked-screen
time counts as usage (Aug 26: 10.9h vs 4.5h) — a product call, not a bug here.

## 5. Prevention

1. `tests/stats_day_window_clip_static_test.py` (new) pins the contract: no read
   path may reselect on `record.startUnixSec` alone, both aggregation cores must
   call `window.clip(...)` before accumulating, the three bucketing paths must go
   through `forEachLocalDaySlice()`, and the orphaned start-day helpers must stay
   deleted. Confirmed to fail when the fix is reverted.
2. `rules/04-ui-conventions.md` should state the invariant plainly — *a windowed
   read selects by intersection and clips to the window; one local day can never
   exceed 24h*. Not done here (a rule edit is its own concern); filed.
