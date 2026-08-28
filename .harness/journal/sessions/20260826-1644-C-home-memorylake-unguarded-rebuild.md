# Session Log — home-memorylake-unguarded-rebuild

## Metadata

- Agent / Author: Claude Code (Opus 5)
- Track: **C (Debug)**
- Date: 2026-08-26 16:33 → 16:52 (local)
- Branch: feature/ui-statistics
- Baseline commit: b7abaab

## Goal

Stop the首页 / 记忆湖 two pages from redoing full usage aggregations on every
idle 5s tick, by applying the `recordsGeneration()` guard already proven on the
stats page (`docs/stats-backend-performance.md` §2.4 / §4 invariant 4).

## Plan

- File L2 error report (done: `../errors/20260826-084500-C-home-memorylake-unguarded-rebuild.md`).
- Home: drop the duplicate aggregation per tick; timer only `refresh()`; add
  `_builtGen` guard + `onLanguageModeChanged` reset (names are language-dependent).
- Memory Lake: add the same `_builtGen` guard to `recomputeDayModel()`.
- Build via `build.py`, `scan_qt_log.py`, `harness_check.py`.

## What actually happened

- 16:33 — read-only audit of desktop UI caching gaps; 12 findings, this session
  takes the top two.
- 16:44 — preflight --track C clean; error report filed.
- 16:47 — both guards in; `build.py` clean.
- 16:48 — instrumented run (30s) confirms Memory Lake idle ticks go
  ~124 ms → SKIP. Numbers in the error report §2.
- 16:49 — **found while verifying:** `DesktopHomePage.qml` never loads. The
  "Home" nav item routes to `page: "memorylake"` and no code path instantiates
  the file. Item 2's guard is correct but latent; logged as its own open issue
  rather than acted on (deleting or re-linking the page is not track C).
- 16:50 — instrumentation removed, rebuilt, 25s clean run:
  `scan_qt_log.py` recorded 0 L2 reports.

## Outcome

**done** (Memory Lake verified live; Home latent — see error report §6)

- Commits landed: pending commit
- Files touched: `qml/desktop/pages/DesktopHomePage.qml`,
  `qml/desktop/pages/DesktopMemoryLakePage.qml`
- Frozen files touched: n
- Follow-ups: written to `../../../docs/desktop-read-path-caching-backlog.md`
  (linked from `docs/implementation-backlog.md` §3) — (1) the other 10 caching
  findings; (2) `DesktopHomePage.qml` is unreachable dead code. **Not** added to
  `../state/open-issues.md`: that file is already exactly at the harness 100-line
  budget, and pass 1 fails on any addition. Its own header points at
  `docs/implementation-backlog.md` for the actionable version, so that is where
  this went. Someone with a track-A session should retire the ~~struck-through~~
  DONE entries there to make room again.

## Notes for the next agent

Adding the generation guard makes language-dependent output stale, because
`recordsGeneration()` does not bump on a UI language change. Both pages
therefore need `onLanguageModeChanged: { _builtGen = -1; … }` — the stats page
already does this at `DesktopStatsPage.qml:95`. Any future page that adopts the
guard owes the same reset.
