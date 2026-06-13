# Session Log — git-workflow-rule

## Metadata

- Agent / Author: Codex
- Track: **A (Stabilize)**
- Date: 2026-06-13 16:56 → 17:00 (local)
- Branch: dev
- Baseline commit: c34657d

## Goal

Codify the branch, commit, PR, report, branch cleanup, and rollback workflow.

## Plan

- Add a focused git workflow rule without touching frozen entry files.
- Link the rule from before-coding, before-commit, and review checklists.
- Verify harness checks still pass.

## What actually happened

- Added `.harness/rules/08-git-workflow.md`.
- Updated checklists so future sessions discover and enforce the rule.

## Outcome

**done**

- Commits landed: pending
- Files touched: `.harness/rules/08-git-workflow.md`,
  `.harness/checklists/before-coding.md`,
  `.harness/checklists/before-commit.md`,
  `.harness/checklists/review.md`,
  this session log
- Frozen files touched: no
- Follow-ups spun out to `../state/open-issues.md`: none

## Notes for the next agent

This workflow intentionally treats branch deletion as cleanup, not rollback.
Rollback is via reverting the PR merge commit or the individual feature commit.
