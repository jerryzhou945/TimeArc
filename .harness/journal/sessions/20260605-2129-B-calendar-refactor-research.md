# Session Log — calendar-refactor-research

## Metadata

- Agent / Author: Claude (Opus 4.8, ultracode workflow)
- Track: **B (Feature)** — planning/product-docs for the upcoming calendar UI refactor.
- Date: 2026-06-05 21:29 → 21:55 (local)
- Branch: dev
- Baseline commit: 466741b

## Goal

Research the v88 calendar design (art + function) vs the existing QML and write the
refactor playbook (steps / 法规 / 知识库) — **no code touched**, docs only.

## Plan

- Read v88 calendar CSS/markup/JS + existing `DesktopCalenderPage.qml` + `calendar_manager`.
- Fan-out research workflow (8 agents: art×2, function, existing-QML, rules, KB, gap-matrix, critic).
- Settle the two product-decision pivots with the user (route-vs-overlay; keep-vs-drop legacy features).
- Produce the two paired replication docs mirroring the memo precedent.

## What actually happened

- 21:29 — preflight --track B → clean (exit 0).
- 21:30 — verified by direct read: calendar CSS 9109–9606, markup 14167–14241, render JS 18181–18265;
  `CalendarManager` is a thin JSON-string bridge; existing page is Sunday-first, v88 is Monday-first.
- 21:35 — ran fan-out workflow `calendar-refactor-research` (8 agents, 747k tokens, ~10min); read all findings.
- 21:50 — user decided: **D-ROUTE = keep routed page** (opaque dark-glass substitute for backdrop-filter);
  **D-KEEP = preserve all legacy features** (anniversaries/countdowns, day-photos, 记录 tab) by extending the v88 layout.
- 21:55 — wrote the two docs.

## Outcome

**done** (research/planning deliverable).

- Commits landed: none (docs only; user has not asked to commit).
- Files touched (new, non-frozen):
  - `docs/calendar-refactor-render-pipeline-replication.md` (美术/渲染复刻)
  - `docs/calendar-refactor-functional-replication.md` (功能/行为/法规/验收/GAPS)
  - this session log.
- Frozen files touched: **n**.
- Follow-ups: the refactor itself (F-B1..F-B7 / M-B1..M-B6 batches in the docs); open A-class decisions
  A3 (adopt time/type taxonomy) and A5 (专注块/本周任务 data source) still need a final call before F-B3/F-B4.

## Notes for the next agent

- This is a **reskin + behavior-preservation**, NOT greenfield. Backend (`calendar_manager` + `DesktopCalendarAnniversaryData`
  Settings + `projectManager` round-trip) is correct and stays. Work is ~all in the QML visual layer.
- Highest-leverage reuse: **`MemoDatePicker.qml`** (already implements v88 Monday-first 42-cell dark-neon grid) and
  **`CalendarSyncList.qml`** (proves the `calendarManager.savedTodos` binding + glass/glow/grid recipe). Do not re-derive.
- Hard contracts to not break: `startTodoProject(name,tag,dateKey,linkedProject)` 4-arg signal; `completeTodo` text-match;
  the `DesktopCalendarAnniversaryData` Settings category (byte-exact or users lose anniversaries).
- Track caveat: Monday-first + new surfaces are observable changes → Track B. Don't force the reskin into Track A.
- The two docs ARE the playbook — read them before coding; they carry the verbatim v88 line citations.
