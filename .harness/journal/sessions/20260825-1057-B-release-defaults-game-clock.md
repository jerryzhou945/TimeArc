# Session Log — Release defaults, game timing, and compact clock

## Metadata

- Agent / Author: Codex
- Track: **B (Feature)**
- Date: 2026-08-25
- Branch: `codex/stats-period-layout`

## Goal

Make the Windows test release start collecting after login by default, count
recognized foreground games accurately through controller/cutscene idle, and
tighten the desktop application clock without changing recorded intervals.

## Service side

The Windows collector continues emitting the same foreground-session schema.
Recognized game executables gain a foreground-work signal so a frontmost game
remains active through keyboard/mouse idle; background processes and launchers
do not gain process-existence timing. No database or C ABI change is planned.

## UI side

On Windows, the UI performs a one-time default registration of its existing
`--start-in-tray` current-user Run entry, while a persisted decision marker
ensures a later user opt-out is never reversed. Statistics keep the same clock
segments but render the three concurrent lanes closer together. The read model
adds stable game names/categories for supported gacha titles.

## Expected files

- `src/main.cpp`
- `src/services/settings_repository.{h,cpp}`
- `src/service/windows/platform/process_activity_win.{h,c}` or a focused game policy helper
- `src/service/windows/tracker/usage_tracker.c`
- `src/services/usage_stat_manager.cpp`
- `qml/desktop/pages/DesktopStatsPage.qml`
- focused Windows/QML/database regression tests

## Boundaries

- Rules touched: `01-architecture`, `02-platform-boundaries`, `04-ui-conventions`.
- No schema, `data_bridge.h`, CMake, frozen-file, macOS, or mobile changes.
- Existing unrelated dirty-tree work remains unstaged and unmodified.

## Outcome

- Completed: Windows first-run current-user autostart with durable opt-out;
  foreground-only main-game policy and stable identities for Genshin Impact,
  Honkai: Star Rail, Zenless Zone Zero, and Wuthering Waves; compact three-lane
  application clock with unchanged source segments and interaction model.
- Incomplete: No macOS/mobile changes and no new game beyond the four explicit
  identities; these are intentional boundaries, not unfinished work.
- Verification: Expected RED tests observed. Wrapped full build passed; CTest
  6/6 passed; StatsViewModel JS, desktop UX, and period layout checks passed.
  Real-user runtime verified the HKCU Run value and both UI/collector processes.
  Qt log scanner ran and found no pending harness log.
- Next: Maintainer chooses commit/PR integration after reviewing the running UI.
- Risks: New games with shared Unreal executable names require a path-specific
  adapter before receiving the idle override; generic process existence remains
  intentionally insufficient evidence.
