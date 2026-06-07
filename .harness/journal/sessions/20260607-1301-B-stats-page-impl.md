# Session 20260607-1301 · Track B · stats-page-impl

## Goal
Implement v88「统计」(Stats) page per `docs/stats-implementation-kickoff.md` +
the 3 authoritative specs (functional / render-pipeline / backend-data-gaps).
Visual 1:1 dark-glass reskin + real read-only backend data + honest placeholders.
Preflight clean. Scope grew (user request) to Stage 1 + Stage 2 + Stage 3.

## Hard constraints honored
Read-only (zero usage/SQLite writes, C11); no faking → empty/honest placeholder
(G5/C6); db_smoke contract (DailyCardService never references UsageStatManager;
data passed from QML, G4); zero inline hex (MemoryLakeStyle tokens, G1); no new
.cpp/.h → frozen CMakeLists untouched (no change proposal); RoundedFrame round-clip
(G7); src/service/ (daemon) untouched.

## Result — Stage 1 (PR #27 commit)
- DesktopAppShell: fullBleedPage / 42px grid / requestNavigate each += "stats".
- MemoryLakeStyle: + changeUp token. DailyUsageShare: + glassStrength (render §4.1)
  + titleKicker/titleText/showInsight (homepage defaults unchanged).
- usage_stat_manager: matchesRange "week" (Mon-first) + dailySecondsForRange.
- DesktopStatsPage: full reskin — 250+1fr shell, week/month/year tabs (default 周),
  topbar, metric row, BarChart, downgraded pie, month LineArea+Heatmap (A-2),
  RankingList, local-template insight/recs (aiGenerated:false), toast, ESC,
  return-home, empty-state, ≤1200 left-collapse. Switch-count derived in QML.

## Result — Stage 2 + Stage 3 (second commit)
usage_stat_manager only (no new files): window aggregates (activeSoftwareForWindow/
SecondsForWindow/foregroundSegmentsForWindow via foregroundSegmentsImpl(predicate));
monthlySecondsForYear (G-7); focusStatsForWindow (G-6/A-5: 开发/办公/笔记 blocks,
gap≤10min/min≥5min); exportReport (G-10, report file not usage data).
QML: window-based data layer + periodOffset (period prev/next G-9, › clamped);
real WoW/MoM/YoY (G-8/G-2, honest absent w/o prior data A-7); real focus metrics
(月·专注天数 / 年·年度专注, replaced "—"); year 12-bar via monthlySecondsForYear; export.
NOT done (deliberate): 3D real-AI — gated (zero-code pipeline; CLAUDE.md "no AI over
raw logs"); local deterministic templates retained.

## Adversarial review (workflow) — fixes applied
DST-safe week-end (real next-Monday midnight, matches month/year); rebuild() total
summed from apps (drop redundant activeSoftwareSecondsForWindow re-aggregate / 5s);
buildExportJson try/catch + failure toast; exportReport sanitize-order + short-write
check. Left (defensible): focusDays counts each local day a block touches.

## Verification (PrintWindow-by-PID, own instance)
week/month/year × night/day; period offset −1. month 专注天数 7天, MoM +70.7h
(June 84.5h vs May 13.8h); year 年度专注 38.6h; week offset−1 "5月25日 – 5月31日"
13.8h (cross-validates MoM). Export → ~/Downloads/timearc-month-stats.json (valid,
aiGenerated:false). build.py clean; scan_qt_log 0 warnings; harness_check exit 0.

## Errors recorded
L1 (build.py, x3): "TimeArc.exe Permission denied" at link — verification instance
left running before rebuild (exe-lock, known trap). QML/C++ compiled fine each time;
resolved by kill + rebuild. No code defect.

## Perf fix — ~10s open freeze + perpetual 5s stalls (commit 54a7081)
Measured (16MB/46k JSONL, temp instrumentation since removed): open = refresh()
3.9s + rebuild() 3.3s ×2; each rebuild = activeSoftwareForWindow 1.4s +
focusStatsForWindow 1.0s + …; 5s Timer re-ran ~7s every 5s → app unresponsive.
Fixes (usage_stat_manager + DesktopStatsPage):
- Incremental refresh(): parse only newly-appended complete lines (offset/size;
  full reparse on shrink). + recordsGeneration() bumps only on real m_records change.
- aggregateSoftware(): was `value()`-copy + `[key]=` write-back per record →
  O(N²) deep-copy of growing interval vectors → accumulate by reference in place.
- Memoize classifyActivity/activityGroupKey (pure, process-static cache).
- rebuild() guard on (generation, range, periodOffset): idle 5s ticks skip.
- onCompleted single rebuild (was refresh-signal + direct double).
Result: open ~10s→0.56s; rebuild-on-change ~2.9s→0.13s; idle ticks 0 work. Data
unchanged (week total/ranking/pie verified). All app-wide (homepage benefits too).

## Notes
- Empirical findings logged in docs/stats-backend-data-gaps.md §12 (H-1..H-5).
- No automated tests touched; db_smoke contract preserved.
