# Session Log — stats-page-research

## Metadata

- Agent / Author: Claude (Opus 4.8, ultracode workflow)
- Track: **B (Feature)** — planning/product-docs for the v88 Statistics page replication.
- Date: 2026-06-07 01:16 → 02:05 (local)
- Branch: fix/memorylake-responsive-minmax
- Baseline commit: 2b09357

## Goal

Research the v88 统计 (Statistics) page (art + function) vs the existing QML/backend and
write the replication playbook + a backend-data-gaps "问题文档" — **no code touched**, docs only.
User requirement: gather all backend data the page could need; pie chart reuses the home
donut with *reduced* (not removed) glassmorphism.

## Plan

- Read v88 stats CSS/markup/JS from `TimeArcDesign_v88.stripped.html`.
- Fan-out research workflow (backend managers / disk contract / classify-focus / QML-arch+pie / doc-style + gap matrix).
- Read firsthand the linchpin files (stats_service, daily_card_service, DailyUsageShare, MemoryLakeStyle,
  DesktopStatsPage, usage_stat_manager.h, DesktopAppShell nav).
- Produce three paired docs mirroring the calendar/memo precedent.

## What actually happened

- 01:16 — preflight --track B → clean (exit 0).
- 01:20 — extracted stats page: DOM 14243–14465, CSS 10705–11370, JS 15280–15413.
  Confirmed v88 stats JS is 100% mock (no data model; only section toggle + animation restart + stub export).
- 01:30 — ran fan-out workflow `stats-page-research` (6 agents, ~947k tokens, ~27min); read all findings + gap matrix.
- 01:40 — firsthand reads corroborated/refined findings:
  - `StatsService` is TODAY-only (range-generic primitives) on SQLite repos (prod-unreliable).
  - prod path = `UsageStatManager` (JSONL); `DailyCardService.memoryLakeDay/Recap` fed by QML via
    `activeSoftwareForRange`/`foregroundSegmentsForRange`/`activeSoftwareForMonth`/`dailySecondsForMonth`.
  - per-app already carries category/launches/longest/sessionCount; MoM delta exists; **no `week` range**.
  - category classifier exists (11 buckets) but mismatches v88 (no 设计/学习 auto-bucket) → product decision.
  - switch-count / YoY / year-focus / period-nav / export = missing; heatmap/weekly-bin/distinct = QML-derivable.
  - home pie = `DailyUsageShare.qml`; glass = MultiEffect blurMax 28/opacity .85 + GlowCircle + breathing ring
    → reduce via a `glassStrength` knob (≈0.45) keeping crisp Canvas slices.
  - `DesktopStatsPage.qml` already exists (legacy cream dashboard) → reskin target; `stats` already routed
    in `DesktopAppShell` nav but NOT in `fullBleedPage` (must add).
- 02:00 — wrote the three docs.

## Outcome

**done** (research/planning deliverable).

- Commits landed: none (docs only; user has not asked to commit).
- Files touched (new, non-frozen):
  - `docs/stats-functional-replication.md` (行为/数据/复刻规则·标准·步骤 + GAPS)
  - `docs/stats-render-pipeline-replication.md` (渲染管线 / CSS→QML / 降玻璃甜甜圈 / 诚实天花板)
  - `docs/stats-backend-data-gaps.md` (后端数据缺口与接入计划 = 问题文档；G-1..G-10 + 三阶段 + 实测登记)
  - `.harness/journal/sessions/20260607-0116-B-stats-page-research.md` (this log)
- Frozen files touched: **n**.
- Follow-ups: implementation is staged in `stats-backend-data-gaps.md` §8 (阶段一纯 QML; 阶段二/三 need
  new C++ → change-proposal for frozen `src/CMakeLists.txt`).

## Notes for the next agent

- Biggest decisions before coding: A-1 category taxonomy (recommend show REAL buckets, don't fake v88 labels),
  and G-1 week range (no `week` anywhere — needs `dailySecondsForRange`/ISO-week in `usage_stat_manager.cpp`).
- 阶段一 is achievable with ZERO C++ (month/year real data + QML-derived heatmap/weekly/distinct + honest
  placeholders for week/switch/YoY/focus/period-nav/export).
- Pie reuse: add `glassStrength` to `DailyUsageShare.qml`; home keeps default 1.0, stats passes ~0.45.
- Only one new style token strictly required: `MemoryLakeStyle.changeUp` rgba(125,255,178,.78).
