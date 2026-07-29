# 20260729-1801-C-macos-app-menu-localization

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-07-29 18:01 → 18:09 (local)
- Branch: `development/macos-support`
- Baseline commit: `f160acf`
- Related error report: [`../errors/20260729-100127-C-macos-app-menu-localization.md`](../errors/20260729-100127-C-macos-app-menu-localization.md)

## Goal

Make Qt's native macOS application-menu rows follow TimeArc's in-app language without changing other platforms.

## Plan / active progress checklist

- [x] Add a macOS-only owner for the Qt application-menu translator and connect it to `MacMenuBar`.
- [x] Deploy only the Chinese and Japanese Qt Base catalogs in the macOS package.
- [x] Add focused static/runtime verification and update the inaccurate design note.

## What actually happened

- 18:01 — User explicitly directed implementation to proceed despite the known, unrelated frozen `CMakeLists.txt` baseline drift.
- 18:01 — Root cause recorded in the related L2 report before code changes.
- 18:04 — The broad macOS build-script test hit its pre-existing harness-wrapper mismatch; see [`../errors/20260729-100435-C-macos-build-script-static-baseline.md`](../errors/20260729-100435-C-macos-build-script-static-baseline.md).
- 18:04 — Optional formatter was unavailable; see [`../errors/20260729-100444-C-clang-format-unavailable.md`](../errors/20260729-100444-C-clang-format-unavailable.md).
- 18:05 — Harness build succeeded.
- 18:08 — Menu/status/full-screen checks passed; deployment probe produced the two requested catalogs with translated native-menu rows.
- 18:09 — Final harness rebuild passed after tightening the context-property registration to the macOS compile branch.

## Outcome

**done**

- Commits landed: none
- Files touched: macOS menu localizer, macOS-gated app wiring, `MacMenuBar`,
  macOS packaging, focused test, and design note
- Frozen files touched: no
- Follow-ups spun out: none

## Notes for the next agent

The localizer source is listed only inside `src/CMakeLists.txt`'s `APPLE`
branch, and the only QML caller lives in the macOS-only `MacMenuBar`.
