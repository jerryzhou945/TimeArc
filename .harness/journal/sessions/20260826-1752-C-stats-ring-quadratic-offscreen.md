# Session Log — stats-ring-quadratic-offscreen

## Metadata

- Agent / Author: Claude Code (Opus 5)
- Track: **C (Debug)**
- Date: 2026-08-26 17:52 → 18:22 (local)
- Branch: feature/ui-statistics
- Baseline commit: b7abaab (+ today's three earlier sessions)
- Related error report: [`../errors/20260826-095248-C-stats-ring-quadratic-offscreen.md`](../errors/20260826-095248-C-stats-ring-quadratic-offscreen.md)

## Goal

Stats page Month/Year froze ~3s per range switch. Fix it fully: stop computing the
day-only category ring for other ranges, and de-quadratic the ring pipeline.

## Plan

- Measure before guessing (per-stage timing in `rebuild()`, then inside the ring).
- Guard `rebuildCategoryRing()` on `range === "day"`, clearing ring view state.
- Heap-based `ringResolveOverlap`; allocation-free in-place smoothing.
- Prove equivalence by differential testing old vs new under `qml`.

## What actually happened

- 17:55 — measured: the ring is 94–99% of rebuild; every C++ call is ≤17ms. My
  initial assumption that the backend was at fault was wrong.
- 18:00 — measured *inside* the ring: for month, `resolveOverlap=561ms` but
  `denoise=2298ms`. My second assumption (that overlap resolution dominated) was
  also wrong — good reason to split the timer before rewriting anything.
- 18:05 — three earlier measurement runs produced only `day` rows; the range-cycle
  timer looked broken. It was not: the runs were being killed early. Added a tick
  log, confirmed, moved on.
- 18:10 — sweep-line `ringResolveOverlap` landed; differential test 400/400.
- 18:14 — in-place absorb + coalesce landed; hardened the harness with adversarial
  shapes (gaps/durations straddling the 60s boundaries, nesting, duplicates):
  840/840 identical.
- 18:16 — **mutation-tested the harness itself** so "0 fails" means something:
  bridge `<=`→`<` gave 6 fails, `splice(index,2)`→`splice(index,1)` gave 592.
  A third mutation (heap tiebreak) is undetectable and provably inert — see
  error report §6.
- 18:20 — measured after: month 3051→**86ms**, year 2918→**60ms**, week 267→**50ms**.
  Pipeline alone 4–6.5× faster on identical input.

## Outcome

**done**

- Commits landed: pending commit
- Files touched: `qml/desktop/pages/DesktopStatsPage.qml`,
  `qml/desktop/pages/StatsViewModel.js`, `tests/stats_view_model_test.js`,
  `tests/stats_period_layout_static_test.py`
- Frozen files touched: n
- Follow-ups: `ringSmooth` is now ~N^1.5, not O(N log N) — a full
  linked-list + heap + local-coalesce rewrite would be needed for that, and after
  the day-only guard the input is bounded by one day, so it was not worth the
  regression risk on a *visual* denoiser. Recorded in the backlog doc.

## Notes for the next agent

Two habits this session paid for twice: **measure the stage, not the feature**
(I was wrong about which half of the ring was slow), and **mutation-test the
oracle before trusting a green differential run**. Node is absent on this host, so
`stats_view_model_test.js` cannot run here; its new assertions were executed under
`QT_QPA_PLATFORM=offscreen qml` with an `assert` shim instead, which is the engine
the code actually runs in.
