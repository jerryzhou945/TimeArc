# Rule 07 — Product Direction, Cards, and AI

This rule applies to Daily Card, Memory Lake, AI summary, mobile planning, and
any feature that turns raw time data into user-facing meaning.

## 1. Direction lock

TimeArc is a local-first life timeline tool, not a surveillance recorder and
not a generic productivity dashboard. Agents must preserve this direction:

- Cards are the primary product surface.
- AI is a content editor over filtered summaries, not a data collector.
- Desktop is the first implementation target; mobile consumes the same card
  model later.
- Privacy boundaries are product requirements, not optional polish.

Read `docs/life-timeline-product-direction.md` and
`docs/card-ai-development-spec.md` before changing this area.

## 2. Minimum runnable slice

Always implement the smallest useful vertical slice that can run end to end.

For Daily Card this means:

1. Build or extend a local summary model.
2. Generate one or a few deterministic cards.
3. Render them in the existing desktop UI.
4. Verify the app can launch and the cards are visible.

Do not start with mobile, cloud sync, plugin APIs, screenshots, OCR, raw audio,
or broad AI workflows before a local desktop card exists.

## 3. Quality bar for small slices

"Small" does not mean throwaway.

Every slice must:

- respect the two-process disk contract,
- avoid schema changes unless truly necessary,
- keep QML display separate from raw-log parsing,
- handle missing or empty data gracefully,
- avoid blocking I/O in QML,
- include a focused smoke path in the session log.

## 4. No detours

Reject scope expansion unless the user explicitly asks for it or the current
slice cannot work without it.

Examples of detours:

- choosing the final mobile stack before Card Model is stable,
- adding a new dependency for formatting or classification,
- building AI before local template cards,
- refactoring unrelated QML pages during card work,
- changing the service schema to store derived UI concepts.

If a detour looks valuable, write it as a follow-up in docs or open issues.

## 5. AI hard limits

AI-facing code must follow:

```text
raw records -> local summary -> privacy filter -> user confirmation -> AI
```

AI must never receive chat content, screenshots, raw audio, browser history,
full raw logs, or protected titles. Redacted fields may be described as
redacted, but AI must not infer their private content.

## 6. Documentation

Any Card/AI feature that changes product behavior must update at least one of:

- `docs/card-ai-development-spec.md`
- `docs/life-timeline-product-direction.md`
- `README.md` if user-visible

Keep product notes in `docs/`; keep harness rules short and enforceable.

## 7. Memory Lake data path

Memory Lake (`qml/desktop/memorylake/`) renders **real local data**, not
`MemoryLakeMock.js` (kept only as design-time fallback). It reuses the homepage
read-only path — `usageStatManager.activeSoftwareForRange` /
`foregroundSegmentsForRange` + `refresh` + `onUsageStatsChanged` — so its security
surface equals the homepage's. The view model is assembled in C++ by
`DailyCardService::memoryLakeDay` (local deterministic templates over
`classifyApp`); QML only renders. Visuals use shared
`components/AppVisual.js` (appColor + `image://appicon`) and `GenerativeCover.qml`
(no per-app artwork; missing icon → appColor). No new data path, no IPC, no AI
over raw logs. Plan: `docs/memory-lake-backend-integration-plan.md`.
