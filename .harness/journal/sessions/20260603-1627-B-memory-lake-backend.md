# 20260603-1627 · Track B · Memory Lake backend data wiring (Phase E)

Authoritative plan: `docs/memory-lake-backend-integration-plan.md` (§8 order).
Issue ledger: `docs/memory-lake-integration-issues.md` (§10 data-safety, mandatory).

## Goal
Replace hardcoded `MemoryLakeMock.js` with real local data. Two stages, two commits:
- Stage 1: Memory Lake body (daily three columns + ambient bg). Real, no fakes.
- Stage 2: Monthly Recap (dynamic slides, theme-neutral, anti-mismatch).

## Two-sided design

**Service side (untouched).** The capture daemon `src/service/` is frozen and NOT
edited. It already writes one foreground record per continuous focus session to
`usage_records.jsonl` + live `usage_current.json` (verified: `usage_tracker.c`
closes a session on exe/title change or idle). We only consume that on-disk
contract — no IPC, no schema change, no new file/db access.

**UI / backend-of-UI side (the work).** Producer = existing read-only UI services
(extended, no new source files, frozen `src/CMakeLists.txt` untouched):
- `UsageStatManager` (reads the JSONL — same path the homepage uses): ADD read-only
  aggregations over its own `m_records`: per-app foreground session segments
  (gap-merged), monthly per-day series, explicit-month app list. No new disk path.
- `DailyCardService` (owns `classifyApp` + local deterministic templates): ADD the
  Memory Lake model builders (`memoryLakeDay`, later `memoryLakeRecap`) that compose
  USM aggregations + classify + copy templates into Mock-shaped QVariant models.
  Inject a `UsageStatManager*` (constructor change; `main.cpp` is non-frozen).
Consumer = QML renders only (rule 07 §3): page swaps `Mock.apps/overview/recap`
for the real same-shaped model; no log parsing / sentence assembly in QML.

## Key reuse (homepage read-only path — guarantees 1 & 2)
`usageStatManager.activeSoftwareForRange("day"|"month")` + `refresh()` +
`onUsageStatsChanged` + 5s Timer + `currentSoftware()`; security surface identical
to homepage. Launches/longest/time-river derived from USM's own `m_records` (NOT
the SQLite `frontmost_sessions`, whose production population is unverified — see
issue ledger), so all Memory Lake data rides the one verified path.

## Images (§4)
Shared `qml/desktop/components/AppVisual.js` (appColor/appIconSource extracted from
homepage). Small = appColor block + `image://appicon`. Large = generative cover
(`GenerativeCover.qml`: appColor gradient + centered icon + name). Ambient bg =
appColor gradient cross-fade in `DesktopAppShell` (was poster blur). Missing icon →
appColor bottom-out. No new third-party dep.

## Files expected to change
- `src/services/usage_stat_manager.{h,cpp}` (read-only aggregations)
- `src/services/daily_card_service.{h,cpp}` (model builders + templates)
- `src/main.cpp` (inject USM into DailyCardService — non-frozen)
- `qml/desktop/pages/DesktopMemoryLakePage.qml`, `qml/desktop/DesktopAppShell.qml`
- `qml/desktop/memorylake/{MemoryCard,DetailPanel,UsageRankList,TimeRiver,RecapOverlay,RecapSlide}.qml`
- NEW `qml/desktop/components/AppVisual.js`, `qml/desktop/memorylake/GenerativeCover.qml`
  + register in non-frozen `qml/CMakeLists.txt`
- Docs: plan, issue ledger, `.harness/state/open-issues.md`, this log.
Frozen files: NONE. `src/service/`: UNTOUCHED.

## Rules to update
`rules/07-product-ai-cards.md` if Memory Lake data path becomes documented; README
if user-visible behavior changes. Checked during exit.

## Smoke path
Launch app → Memory Lake (3rd nav). Expect: left overview/theme/ranking, center
cards, right detail/time-river, ambient bg — all real per-app data, generic copy,
appColor+icon visuals, no game posters, no fake numbers; empty state when no data.
Build via `python .harness/tools/build.py`; `scan_qt_log.py`; `harness_check.py`.

## Errors / mismatches
Every implement-time mismatch → `docs/memory-lake-integration-issues.md` + level
`record_error.py`. No fake data; missing data → empty state.
