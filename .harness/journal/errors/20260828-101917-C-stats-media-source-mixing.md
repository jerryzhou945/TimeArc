# Error Report - stats-media-source-mixing

## Metadata

- Level: **L2** | Track: **C** | Platform: macos
- Topic: stats-media-source-mixing | Recorded: 2026-08-28T10:19:17Z
- Session: `20260828-1747-C-stats-day-window-clip`
- Tooling: Claude Code (Opus 5); sqlite3 + throwaway harness on the real read layer

## 1. What happened

Stats page mixed media_sessions into its app aggregation. Media runs concurrently with the foreground app, and the page total is a sum of per-app unions, so a second covered by both a media row and a different app's frontmost row counted twice (2026-08-04 24.06h, 08-05 24.06h). The page is frontmost-only by design.

## 2. Evidence

Surfaced while verifying the day-window clip fix
([`…-C-stats-day-window-no-clip.md`](20260828-094718-C-stats-day-window-no-clip.md)):
with clipping in place every day fell to <= 24h except two.

```
Aug 04: sum of per-app unions 86627s (24.06h) | true union 86400s | excess 227s
Aug 05: sum of per-app unions 86609s (24.06h) | true union 86400s | excess 209s
```

The excess is exactly the time Elmedia Player was playing while a *different*
app was frontmost:

```
Aug 04   sioyek 162 + Finder 45 + Terminal 13 + Chrome 7            = 227s
Aug 05   sioyek 148 + Finder 24 + VSCode 18 + Claude 12 + Baidu 7   = 209s
```

Same-app concurrency was already free: Elmedia playing *while Elmedia was
frontmost* resolves to one group key and `mergedIntervalSeconds()` collapses it.
Raw frontmost x media overlap on Aug 4 is 1059s but the excess is 227s — the
other 832s was correctly merged. Only cross-app concurrency double-counts.

## 3. Root cause

- Immediate cause: the stats page called `activeSoftwareForWindow` and friends —
  the "active" caliber, foreground union audio. `refreshHistoryFromSqlite()`
  loads both tables into one `m_records` list (`source` = "foreground" /
  "audio"), `aggregateSoftware()` de-overlaps only *within* an app group, and
  `DesktopStatsPage.qml rebuild()` totals with `sum(apps[i].seconds)`. Two apps
  covering the same second are therefore counted twice. Frontmost rows never
  overlap each other (6 pairs / 0.01h across 17,358 rows), so media is the only
  source of a concurrent record.
- Underlying cause: the stats page's caliber was never stated anywhere. "Which
  sources does this page read?" was answered implicitly by whichever method the
  call site happened to reach for, and the method names ("active…", plain
  "dailySecondsForRange") did not carry the answer.
- Why the harness did not prevent it: same gap as the sibling report — no rule
  states what the stats page counts, and no test asserts which read paths it
  may call.

## 4. Fix

- Files: `src/services/usage_stat_manager.{h,cpp}`,
  `qml/desktop/pages/DesktopStatsPage.qml`,
  `tests/stats_day_window_clip_static_test.py`.
- Short description: the stats page is frontmost-only end to end. Its five
  exclusive read paths are renamed to carry the caliber in the name and filter
  to `source == "foreground"`: `foregroundSoftwareForWindow`,
  `foregroundSoftwareSecondsForWindow`, `foregroundDailySecondsForRange`,
  `foregroundMonthlySecondsForYear`, `foregroundFocusStatsForWindow`. Renaming
  rather than adding parallel methods leaves no `active*` entry point that only
  this page used — the next person cannot reintroduce the mix by reaching for
  the obvious name. `allApps()` is split: it stays all-source for the settings
  inventory (which must list every app the service ever saw, including
  audio-only ones), and a new `foregroundApps()` serves the stats page's
  lifetime total / "longest overall" / active-apps denominator, with its own
  memoization slot. The `active*` methods the home, memory-lake and monthly-recap
  pages use are untouched — those pages want device-usage coverage.
- Verification (real read layer + real DB): every day in the DB is now <= 24h.
  ```
  2026-08-04  24.06h -> 24.00h      2026-08-18   8.82h -> 8.76h
  2026-08-05  24.06h -> 24.00h      2026-08-26  10.91h -> 10.89h
  week Aug3-9: total 76.60h == daily bars 76.60h
  allApps 44 apps / 162.13h   foregroundApps 44 apps / 161.87h
  ```
  No app leaves the stats library: both media apps
  (`com.eltima.elmedia6.mas`, `com.tencent.xinWeChat`) also have frontmost rows,
  and there are no media-only apps in the DB. "Longest overall" is unchanged.
  Full sweep: 31/31 static tests, `ctest` 3/3, `build.py` clean.
- Commit: pending commit

## 5. Prevention

`tests/stats_day_window_clip_static_test.py` grew a second section: the stats
page must not call any `active*` / `allApps` / unqualified-series method, the
three hand-rolled record loops it uses must carry a
`matchesSource(record, kForegroundSource)` guard, and the two lifetime calibers
must keep separate caches (one cache keyed only on generation would serve
whichever caller asked first). Confirmed to fail when the page is pointed back
at `activeSoftwareForWindow`.

The deeper prevention is the naming rule this fix adopts: **a read path's name
states its source caliber.** `rules/04-ui-conventions.md` should say so, along
with which surface counts what — filed to `state/open-issues.md`.
