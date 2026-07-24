# Change Proposal — Git workflow completion contract

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-07-24 12:00 (Asia/Shanghai)
- Session goal: Route all delivery work to the existing Rule 08 and require auditable completion status.
- Branch: `codex/cross-sync-e0-delivery-rules`
- Related design: `docs/superpowers/specs/2026-07-24-cross-device-sync-design.md`

## 1. Frozen files touched

- `.harness/AGENTS.md` — add the Rule 08 routing entry.

## 2. Motivation

The project already defines branch, commit, PR, merge, and cleanup behavior in
Rule 08, but the mandatory reading router does not point delivery work to it and
the rule does not require the five-part status record requested for cross-device
delivery.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | None; the native collector and service database are unchanged. |
| Consumer | None at runtime; only agent delivery behavior changes. |

## 4. Migration plan

No on-disk application data impact.

## 5. Rollback plan

Revert the E0 PR; no data restoration is required.

## 6. Test plan

- Pre-change: the new workflow static test fails on missing route/status markers.
- Post-change: the static test and full harness audit pass.
- New artifact: `tests/harness_git_workflow_static_test.py`.

## 7. Sign-off

- [x] `rules/08-git-workflow.md` will reflect the new reality.
- [x] `state/frozen-files.json` was regenerated after the frozen edit.
- [x] No CHARTER version bump is required.
- [x] No user-visible README change is required.

## 8. Outcome

Completed: Rule 08, AGENTS routing, checklist enforcement, static test, report.

Incomplete: PR merge and branch cleanup.

Verification: workflow static test and full harness pass.

Next: merge the E0 PR, clean its branch, then write the E1 execution plan.

Risks: GitHub branch protection remains an external repository setting.
