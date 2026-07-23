# Session Log — macos-tracking-bug-reaudit

## Metadata

- Agent / Author: Codex `/root`
- Track: **A (Stabilize)** — read-only bug review.
- Date: 2026-07-23 15:21 (Asia/Shanghai)
- Branch: `development/macos-support`
- Baseline commit: `aec4316`

## Goal

Re-audit the current macOS Tracking implementation for previously identified
and newly introduced defects without changing implementation files.

## Plan

- Recheck every previously reported compile, transition, and contract issue.
- Trace integration through `TimeArcService.swift` and the CMake source list.
- Run the sanctioned build if the updated source tree is buildable.

## What actually happened

- 15:21 — Began the read-only re-audit.
- 15:21 — Confirmed fixes for state-machine value semantics, media retirement,
  database-adapter naming, PID extraction, and input-based idle measurement.
- 15:21 — Sanctioned build stopped at the stale macOS CMake source list; see
  [`../errors/20260723-072154-B-build-failure.md`](../errors/20260723-072154-B-build-failure.md).
- 15:22 — Recorded the build wrapper's staged-track labeling mismatch; see
  [`../errors/20260723-072214-A-build-report-track-from-index.md`](../errors/20260723-072214-A-build-report-track-from-index.md).
- 15:23 — Compacted superseded index rows after the mandatory reports exceeded
  the line budget; see
  [`../errors/20260723-072309-A-journal-index-line-budget-after-reaudit.md`](../errors/20260723-072309-A-journal-index-line-budget-after-reaudit.md).
- 15:25 — Completed static review of remaining transition, persistence,
  integration, error-semantics, and contract issues.

## Outcome

**done**

- Commits landed: none
- Files touched: this session log and harness-generated build/error records
- Frozen files touched: no
- Follow-ups spun out to `../state/open-issues.md`: none

## Notes for the next agent

The macOS implementation and Tracking folder contained user-owned uncommitted
changes at session start. No implementation files were changed by this review.
