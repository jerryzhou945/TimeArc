# Session Log — macos-tracking-problem-reaudit

## Metadata

- Agent / Author: Codex `/root`
- Track: **B (Feature)** — review of the staged macOS Tracking feature.
- Date: 2026-07-23 16:09 (Asia/Shanghai)
- Branch: `development/macos-support`
- Baseline commit: `aec4316`

## Goal

Recheck the current macOS Tracking implementation against all previously
identified integration, transition, persistence, and reliability problems.

## Service side

Review the staged native service implementation and verify that its probes,
coordinators, state machines, and database bridge preserve the service
contract.

## UI side

No UI changes are planned. The review verifies that service output remains
compatible with the UI's existing read-only database model.

## Plan

- Trace current types, dependencies, entry-point wiring, and build sources.
- Recheck every previously reported issue and look for regressions.
- Run available scoped validation without modifying implementation files.

Rule files needing updates: none for this read-only review. Schema,
`data_bridge.h`, and frozen files remain unchanged.

## What actually happened

- 16:09 — Began the read-only re-audit.
- 16:11 — Confirmed fixes for coordinator initialization, explicit shutdown
  flushing, media retirement, zero-duration media filtering, and bounded
  accessibility traversal.
- 16:13 — Found a foreground zero-duration guard regression that prevents a
  fresh active record from ever accumulating or transitioning to idle.
- 16:15 — Reconfirmed the stale CMake/entry-point integration, coordinator
  coupling, probe-failure ambiguity, persistence-error loss, and media timing
  contract gaps.
- 16:16 — Swift frontend parsing and scoped diff checks passed; no Tracking
  tests exist.
- 16:20 — At user direction, excluded intentional architectural choices and
  compared observable behavior with the Charter, platform/data rules, service
  README, root README, and macOS lifecycle reports.
- 16:23 — Catalogued code-versus-contract mismatches separately from
  contradictions among the documentation files themselves.

## Outcome

**done**

- Commits landed: none
- Files touched: this session log only
- Frozen files touched: no
- Follow-ups spun out to `../state/open-issues.md`: none

## Notes for the next agent

The macOS implementation contains staged user-owned feature work. Do not alter
or unstage it during review.
