# Session Log — macos-fullscreen-close-black-screen

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-07-28 23:05 → 23:08 (local)
- Branch: `development/macos-support`
- Baseline commit: `b9c3bf9`

## Goal

Diagnose why closing TimeArc from macOS full screen leaves a black Space and
identify the smallest safe fix without changing application code.

## Plan

- [x] Trace QML close-to-tray and native macOS window lifecycle code.
- [x] Route macOS close-to-tray through the native full-screen exit lifecycle.
- [x] Build and verify the macOS-only structure and harness state.

## What actually happened

- 23:05 — Filed the reported runtime issue and traced it to `onClosing`.
- 23:06 — Corrected an inferred status-bar filename; see
  [`../errors/20260728-150612-C-macos-status-bar-path-assumption.md`](../errors/20260728-150612-C-macos-status-bar-path-assumption.md).
- 23:07 — Qt documentation confirmed that hiding a macOS full-screen window
  leaves its dedicated desktop blank.
- 23:07 — Compacted the rolling journal after the fast audit caught its line
  budget; see
  [`../errors/20260728-150729-C-fullscreen-diagnosis-index-line-budget.md`](../errors/20260728-150729-C-fullscreen-diagnosis-index-line-budget.md).
- 23:22 — Implemented the AppKit completion observer; both builds and the
  focused macOS structural regression passed.

## Outcome

**done** — fix implemented and compiled; interactive smoke remains manual.

- Commits landed: none
- Files touched: `qml/main.qml`, macOS traffic-light controller, focused test,
  and harness records
- Frozen files touched: no
- Follow-ups: manually verify full screen → close → desktop → status restore.

## Notes for the next agent

The implementation observes AppKit completion directly; do not replace it
with a fixed timer.
