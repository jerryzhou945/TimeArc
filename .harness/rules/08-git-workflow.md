# Rule 08 — Git Workflow

This rule defines the required branch, commit, PR, and rollback shape for
feature and fix work.

## 1. Branch Shape

- All implementation work starts from the latest `dev`.
- Create a dedicated feature branch before the first implementation commit.
  Use a clear prefix such as `feat/`, `fix/`, `docs/`, or `codex/`.
- Do not commit implementation work directly on `dev` unless the maintainer
  explicitly asks for it.
- Keep the branch scoped to one track and one coherent goal.

## 2. Commit Shape

- Each independent small feature or fix gets one commit.
- Each commit must be safely revertible on its own.
- Large work is split by phase: one phase, one commit.
- Do not mix unrelated cleanup, docs, UI, service, or contract changes into
  the same commit unless they are required for that phase to work.
- If a commit cannot be safely reverted as a unit, split it before review.

## 3. Completion Report

- When a feature/fix is complete, write a Chinese summary report under
  `docs/`.
- The report should cover: goal, scope, changed files, verification, known
  gaps, and rollback notes.
- At the same time, update `docs/implementation-backlog.md` and
  `.harness/state/open-issues.md` so shipped work is marked done and deferred
  work remains visible.
- Keep detailed session chronology in `.harness/journal/sessions/`; keep the
  `docs/` report human-facing and concise.

## 4. Push And PR

- Push the feature branch to the remote.
- Open a PR targeting `dev`.
- The PR body must mention the relevant commits or phases, the Chinese report,
  verification commands, and any deferred follow-ups.
- Do not merge a PR whose branch contains unrelated work or undocumented
  follow-ups.

## 5. After Merge

- After the PR is merged into `dev`, delete the remote feature branch.
- Delete the local feature branch after confirming local `dev` contains the
  merge.
- Branch deletion is cleanup only; it is not the rollback mechanism.

## 6. Rollback

- Roll back merged work by reverting the PR merge commit, or by reverting the
  specific feature/fix commit when the PR was merged as individual commits.
- Prefer revert over history rewrite on shared branches.
- The rollback note in the Chinese report must say which commit or PR merge
  should be reverted.
