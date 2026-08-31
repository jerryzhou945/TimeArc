# Session Log — stats-day-window-clip

## Metadata

- Agent / Author: Claude Code (Opus 5), driven by Jeff Zhang
- Track: **C (Debug)**
- Date: 2026-08-28 17:47 → 20:05 (local)
- Branch: `feature/ui-statistics`
- Baseline commit: `59d87e6`

## Goal

Make the desktop read layer report time actually spent: clip windowed reads,
count `active_sec`, read frontmost only on stats, honour per-app hiding.

## Plan

- Reproduce from the real service DB; establish writer-vs-reader fault first.
- One shared window type; every windowed path through it.
- Verify against the real DB and raw SQL; regression-test each contract.

## Related error report(s)

Five, each filed before its code:
[`no-clip`](../errors/20260828-094718-C-stats-day-window-no-clip.md),
[`media-source-mixing`](../errors/20260828-101917-C-stats-media-source-mixing.md),
[`wall-clock-not-active`](../errors/20260828-114958-C-ui-counts-wall-clock-not-active.md),
[`hidden-key-drift`](../errors/20260828-114958-C-hidden-apps-key-scheme-drift.md), [`name-key-drift`](../errors/20260828-125749-C-display-name-override-key-drift.md).

## What actually happened

- 17:50 — reproduced: Aug 3 is 36.32h under the page's caliber, 24.00h clipped,
  4.58h active. Two `loginwindow` sessions (17.6h, 13.5h) both start that day.
  Checked the writer before blaming it: 6 overlapping adjacent pairs in 17,358
  rows, 0.01h. Clean timeline; a read bug — "the records overlap" would have
  been the wrong fix.
- 18:00 — the defect was in six places, not two. `ClipWindow` +
  `forEachLocalDaySlice()` so the boundary reasoning exists once. Aug 3 → 24.00h;
  week bars now sum to the week total. Two days read 24.06h — a *different*
  defect (cross-app sum), filed rather than chased.
- 18:40 — user: stats reads frontmost only. Checked every caller first (the four
  window paths are stats-exclusive, `allApps()` is shared with settings), then
  renamed the five to `foreground*` and split `allApps()`/`foregroundApps()`.
- 19:10 — user: count `active_sec`, honour the hide, app-wide. Blast radius
  first: `statsService`/`getTodayCards()` reach no QML, so the desktop UI reads
  through `UsageStatManager` — app-wide is one file.
- 19:25 — the hide bug was not where I expected. `hidden_apps` holds
  `exe:loginwindow`, which now resolves to `app:macos-shell`, so the stored key
  matched nothing. Read-side alias matching + settings-side canonicalization.
- 20:40 — same treatment for `app_display_name_overrides`, which the previous
  report predicted would drift the same way. Wiring it surfaced a second defect:
  the map was pushed only from `DesktopProfilePage.onCompleted`, and `pageLoader`
  builds one page at a time, so renames did not apply until Settings was opened.
  Push moved to the shell.
- 20:55 — mobile checked, not changed: `foreground_sec` is Android's own
  `UsageStats.totalTimeInForeground` (no idle component, so `active_sec` has no
  analogue), and mobile has no hiding at all. Track B, not a fix.

## Outcome

**done** — day filter, stats source caliber, `active_sec`, per-app hiding, and
renames; the last three across the whole desktop read layer. Five fixes, five
reports.

- Commits landed: pending commit
- Files touched: `src/services/usage_stat_manager.{h,cpp}`,
  `qml/desktop/pages/DesktopStatsPage.qml`, `qml/desktop/DesktopAppShell.qml`,
  `qml/desktop/pages/DesktopProfilePage.qml`,
  `tests/stats_day_window_clip_static_test.py` (new). `state/open-issues.md` was
  at its 100-line budget, so follow-ups only fit after compacting entries
  already marked resolved — no live item lost.
- Frozen files touched: **n**
- Follow-ups in `../state/open-issues.md`: mobile has no per-app hiding (a track
  B feature, needs its own settings surface and a package-name key scheme);
  `rules/04` should state the windowed-read invariant, name-declares-caliber,
  and derived-keys-need-migration; the cross-app sum still stands for the
  `active*` pages, it is only unreachable from stats now.

## Notes for the next agent

`active_sec` is a **length, not a placement** — nothing records which seconds
inside a session were active. Intervals anchor at `start`, so totals are exact
and clock positions can be off by up to `maxSessionSec` (300s). Do not "fix"
that by reverting to `duration_sec`; it puts the locked screen back in.

The stats page is **frontmost-only** by product decision, not optimization:
media sessions are genuinely concurrent with the foreground app, so counting
both makes a day exceed 24h. The `foreground*` names are the contract — do not
"simplify" them to `active*`. Home / memory-lake / monthly-recap deliberately
use `active*`, because "how much was this device in use" is another question.

`clipWindowForBounds()` takes the **closed** `[start, end]` QML passes and stores
`end + 1`; do not route an exclusive-end caller through it. Day arithmetic uses
`startOfDay()`, never `+ 86400` — a DST day is 23 or 25 hours.

The >24h days here (Aug 3–5) predate `677d856`'s `maxSessionSec = 300`. Do not
read a clean recent week as evidence a windowing change is right; the defect was
latent there. No fixture in this repo has a cross-midnight session, so verifying
meant driving the real read layer against the real DB and reconciling with raw
SQL — which is what caught the hide bug living in the stored key, not the filter.
