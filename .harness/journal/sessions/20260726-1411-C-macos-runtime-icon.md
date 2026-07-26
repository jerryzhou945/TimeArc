# Session Log — macos-runtime-icon

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-07-26 14:11 → 14:17 (local)
- Branch: development/macos-support
- Baseline commit: 7c76842
- Related error report(s):
  - [`../errors/20260726-061231-C-macos-runtime-icon-override.md`](../errors/20260726-061231-C-macos-runtime-icon-override.md)
  - [`../errors/20260726-061231-C-macos-icon-cmake-premise.md`](../errors/20260726-061231-C-macos-icon-cmake-premise.md)
- Active progress checklist: This session log.

## Goal

Stop the runtime SVG icon override on macOS so the app uses its correctly bundled `TimeArc.icns` as the default icon.

## Plan

- Verify the current CMake bundle metadata and the `.icns` representations.
- Guard the cross-platform SVG runtime icon assignment off macOS.
- Run the sanctioned build and inspect the generated bundle.

## What actually happened

- 14:11 — Preflight passed on Track C.
- 14:12 — Confirmed `Info.plist` names `TimeArc.icns`, the resource is bundled, and the icon contains all standard macOS representations.
- 14:12 — Found the unconditional runtime SVG override; see the related L2 report.
- 14:12 — Corrected the initial CMake premise; see the related L3 report.
- 14:15 — Guarded the SVG assignment off macOS.
- 14:16 — Sanctioned build succeeded; generated plist/resource checks and CTest 1/1 passed.
- 14:17 — Harness audit passed all seven checks.
- 14:24 — Maintainer removed the standalone static test and requested removal
  of its related documents; stale references were removed in the Track A
  follow-up session.

## Outcome

**done**

- Completed: macOS now relies on the native bundle icon; other platforms retain the QRC SVG assignment.
- Incomplete: None.
- Verification: Harness build succeeded; generated `CFBundleIconFile` is `TimeArc.icns`; bundled and source icons match; CTest passed 1/1; harness audit passed 7/7.
- Next: Replace any previously installed app bundle with the rebuilt bundle and relaunch it.
- Risks: macOS icon caching can hide a correct replacement temporarily.

- Commits landed: None (pending commit).
- Files touched: `src/main.cpp` and harness journal/state records. The
  standalone test and product documentation were removed in the follow-up.
- Frozen files touched: no.
- Follow-ups spun out to `../state/open-issues.md`: None.

## Notes for the next agent

The top-level CMake bundle configuration is already correct and should not be edited for this fix.
