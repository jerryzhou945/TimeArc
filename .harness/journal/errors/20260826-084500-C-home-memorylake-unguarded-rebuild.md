# Error Report - home-memorylake-unguarded-rebuild

## Metadata

- Level: **L2**
- Track: **C**
- Topic: home-memorylake-unguarded-rebuild
- Recorded: 2026-08-26T08:45:00Z
- Session: `../sessions/20260826-1644-C-home-memorylake-unguarded-rebuild.md`
- Platform: n-a (macOS dev host used for measurement)
- Tooling: build.py + temporary `console.warn("GUARDPERF …")` timing, per
  `docs/stats-backend-performance.md` §5

## 1. What happened

`docs/stats-backend-performance.md` §4 invariant 4 says UI recomputation must be
de-duplicated by `recordsGeneration()`. Only the stats page ever adopted it. The
記憶湖 and 首页 pages kept recomputing on every 5s tick regardless of whether any
new record had arrived:

- `DesktopMemoryLakePage.recomputeDayModel()` — **six** full aggregations per
  tick: `activeSoftwareForRange("day")` + `foregroundSegmentsForRange("day")`,
  then `enrichDurations` adds `day` / `month` / `year` / **`all`**. The `"all"`
  pass aggregates every record ever collected and grows without bound.
- `DesktopHomePage.refreshTodaySoftwareStats()` — called `usageStatManager.refresh()`
  and *then* assigned `todaySoftwareStats`; because `refresh()` emits
  `usageStatsChanged` **synchronously**, the `Connections` handler had already
  assigned it. So: two aggregations per tick, and two reassignments of a property
  that feeds four function-call `model:` bindings — i.e. every Repeater delegate
  on the page destroyed and rebuilt twice per tick. Same double-rebuild shape as
  perf-doc §2.4.

## 2. Evidence

Measured on the dev host with temporary instrumentation, Memory Lake as landing page:

```
08:48:34  ml RECOMPUTE ms=356   <- startup / first SQLite load
08:48:34  ml RECOMPUTE ms=53
08:48:34  ml RECOMPUTE ms=83
08:48:40  ml RECOMPUTE ms=124   <- genuine new data (generation -> 4)
08:48:45  ml SKIP gen=4         <- idle tick, 0 ms   (was ~124 ms)
08:48:50  ml SKIP gen=4
08:48:55  ml SKIP gen=4
08:49:00  ml SKIP gen=4
```

Every idle 5s tick previously paid the ~124 ms shown on the last real recompute.

## 3. Root cause

- Immediate cause: neither page consulted `recordsGeneration()`; Home additionally
  re-entered its own recompute via `refresh()`'s synchronous signal.
- Underlying cause: the §2.4 guard was written as a stats-page fix rather than as a
  shared pipeline, so the invariant recorded in §4 had no enforcement and the two
  other consumers of the same read path never picked it up.
- Why the harness did not prevent it: `rules/04-ui-conventions.md` §7 fixes the
  *range vocabulary* shared by the aggregation consumers but says nothing about the
  *refresh discipline* they share.

## 4. Fix

- Files changed: `qml/desktop/pages/DesktopMemoryLakePage.qml`,
  `qml/desktop/pages/DesktopHomePage.qml`
- Short description: added the `_builtGen` / `recordsGeneration()` guard to both
  pages; Home's 5s Timer now only calls `refresh()` and lets the resulting
  synchronous `usageStatsChanged` drive one guarded recompute. Both pages reset
  `_builtGen` on `onLanguageModeChanged`, because display names resolve through
  `uiLanguage()` while `recordsGeneration()` does **not** bump on a language
  change — without the reset the guard would freeze names in the old language.
  Both guards fall back to unconditional recompute if `recordsGeneration` is
  absent, so a missing method can never strand a page in the empty state.
- Commit: pending commit

## 5. Prevention

Not a one-off. Concrete harness upgrade: add to
`rules/04-ui-conventions.md` §7 that every consumer of a `UsageStatManager`
range aggregation must de-duplicate on `recordsGeneration()` **and** invalidate
that guard on `languageMode` change. §7 already owns the shared-vocabulary rule
for these two managers, so the refresh discipline belongs beside it rather than
buried in a perf doc that a page author has no reason to open.

## 6. Notes

`DesktopHomePage.qml` is currently **unreachable at runtime**: the shell's "Home"
nav entry maps to `page: "memorylake"`, `currentPageSource` never returns
`DesktopHomePage.qml`, and nothing else instantiates it — it is listed only in
`qml/CMakeLists.txt`, so it compiles and ships but never loads. The fix above is
therefore verified live on Memory Lake and **latent** on Home. Whether the page
should be deleted or re-linked is a separate (track A / B) decision; logged in
`docs/desktop-read-path-caching-backlog.md` alongside the 10 caching findings this
session did not take. (`state/open-issues.md` sits exactly on the harness 100-line
budget, so the detail lives in `docs/` — the header of that file already designates
`docs/implementation-backlog.md` as the actionable expansion.)
