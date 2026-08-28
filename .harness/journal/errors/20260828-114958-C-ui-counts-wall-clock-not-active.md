# Error Report - ui-counts-wall-clock-not-active

## Metadata

- Level: **L2** | Track: **C** | Platform: macos
- Topic: ui-counts-wall-clock-not-active | Recorded: 2026-08-28T11:49:58Z
- Session: `20260828-1747-C-stats-day-window-clip`
- Tooling: Claude Code (Opus 5); sqlite3 + throwaway harness on the real read layer

## 1. What happened

The whole desktop read layer counted duration_sec (wall clock). A foreground session stays open across idle (CHARTER v0.11), so locked-screen and away time counted as usage: loginwindow read 74.9h lifetime against 9.1h of active_sec, and 2026-08-03 read 24.00h against 4.59h.

## 2. Evidence

`frontmost_sessions` stores both lengths: `duration_sec` is generated
(`end - start`), `active_sec` is what the tracker actually accumulated, and
`idle_sec` is the difference. The GUI read layer selected only `duration_sec`.

```
display_name             wall_h    active_h
loginwindow             74.94       9.11     <- locked screen
Claude                  26.98      18.32
Finder                   5.61       3.93
Elmedia Video Player      6.55       6.55     <- video-over-idle, correctly equal
2026-08-03              24.00       4.59
```

CHARTER v0.11 keeps a foreground session open across idle on purpose, so
`duration_sec` counting the lock screen is not a service bug — the reader simply
asked the wrong column. `StatsService` / `FrontmostSessionRepository` already
used `SUM(active_sec)`, so the two read paths in this repo disagreed.

## 3. Root cause

- Immediate cause: `kSqlFrontmostSince` selected `duration_sec`, and every
  interval in `usage_stat_manager.cpp` was built as
  `[start, start + durationSec)`.
- Underlying cause: the schema offers two lengths and the reader never stated
  which question it was answering. "How long was this window frontmost" and
  "how long was the user there" differ by exactly `idle_sec`, and with a locked
  overnight machine that difference is most of the day.
- Why the harness did not prevent it: `rules/03-data-contract.md` documents the
  columns but not which one a reader should count, and nothing compares the two
  read paths (`UsageStatManager` vs the repositories) for agreement.

## 4. Fix

- Files: `src/services/usage_stat_manager.{h,cpp}`,
  `tests/stats_day_window_clip_static_test.py`.
- Short description: the frontmost query carries `active_sec` as an eighth
  column; `media_sessions` has no such column, so that query backfills
  `duration_sec` into the same slot (playback is playback) and the loader keeps
  one shape. `UsageRecord` gains `activeSec`, clamped to `durationSec`. Every
  counted interval is now `[start, start + activeSec)`. `durationSec` survives
  only where the question is *when*, not *how long*: the three "last used"
  timestamps and `representativePathScore`'s recency.
- Known approximation, deliberate: active seconds are a length, not a placement
  — the tracker does not record *which* seconds inside the session were active.
  Anchoring at `start` keeps every total exact and bounds the placement error by
  the service's `maxSessionSec` (300s today), which matters only for the ring's
  clock positions, never for a total. Recorded here so the next reader does not
  rediscover it as a bug.
- Verification (real read layer + real DB), reconciled against raw SQL:
  ```
  2026-08-03  24.00h -> 4.59h   (SUM(active_sec) = 4.585h)
  macOS Shell 74.93h -> 9.11h   (SUM(active_sec) = 9.111h)
  Claude      26.85h -> 18.32h  Elmedia 6.55h -> 6.55h (video-over-idle)
  ```
  Full sweep: 31/31 static, `ctest` 3/3, `build.py` clean.
- Commit: pending commit

## 5. Prevention

`tests/stats_day_window_clip_static_test.py` gained a section 3: the frontmost
query must select `active_sec`, `UsageRecord` must carry `activeSec`, the five
record loops must count it, and no call may feed `record.durationSec` to
`ClipWindow::clip`. Confirmed to fail when one clip call is reverted.

`rules/03-data-contract.md` should say which column a reader counts and why
(`active_sec` for "how long was the user there"; `duration_sec` only for "when").
Filed to `state/open-issues.md`.
