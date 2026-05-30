# Session 20260530-2211-B-daily-card-mvp

## Goal

Implement the first Daily Card vertical slice: generate two deterministic local
cards (today's mainline + top app usage) and render them in the Memory Lake
page. No AI, no persistence, no service schema change. Follows rule 07 §2.

## Frozen-file change proposal

This session edits one frozen file:

- `src/CMakeLists.txt` — add `services/DailyCardService.cpp` and `.h` to
  `TIME_ARC_DATABASE_SOURCES` (same group as `StatsService`, which the new
  service depends on). This is a pure source-registration entry; no target,
  install rule, or structural CMake change. Frozen hash will be re-bootstrapped
  via `harness_check.py --bootstrap` after the edit.

No other frozen files are touched. The two-process disk contract
(`usage_record.schema.json`, `data_bridge.h`, `usage_paths.*`) is unchanged.

## Service side

No background-service behavior changed. The service remains the producer of
lightweight disk records only.

## UI side

New `DailyCardService` (UI-side QObject) reuses `StatsService` aggregation and
produces UI-agnostic card maps (`QVariantMap`, fields per
`docs/card-ai-development-spec.md`). QML reads `cardData.*` only; all parsing
stays in C++ (rule 07 §3). `DesktopMemoryLakePage` renders cards via a reused
`SoftCard`-based delegate. Empty data shows a friendly placeholder.

## Outcome

Memory Lake shows real "今日主线" and "App 使用" cards from today's recorded
data. Segmenter/Classifier and the remaining card types are deferred to the
next slice.
