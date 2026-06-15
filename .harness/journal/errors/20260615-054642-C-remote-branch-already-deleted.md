# Error Report - remote-branch-already-deleted

## Metadata

- Level: **L3**
- Track: **C**
- Topic: remote-branch-already-deleted
- Recorded: 2026-06-15T05:46:42Z
- Session: `.harness/journal/sessions/20260615-1312-C-ui-stats-memorylake-language-followups.md`
- Platform: Windows / git
- Tooling: `git push origin --delete`

## 1. What happened

After PR #32 merge, git push origin --delete fix/ui-stats-memorylake-language-followups failed because the remote ref no longer existed; local branch cleanup had already succeeded.

## 2. Evidence

`error: unable to delete 'fix/ui-stats-memorylake-language-followups': remote ref does not exist`

## 3. Root cause

- Immediate cause: the remote branch had already been deleted after PR merge.
- Underlying cause: cleanup attempted a second remote delete.
- Why the harness/checklists did not prevent it: GitHub branch-delete behavior is
  repository setting dependent.

## 4. Fix

- Files changed: none.
- Short description: local branch had already been deleted; no further cleanup
  was needed.
- Commit: n/a

## 5. Prevention

One-off cleanup race; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: the remote branch would still exist after merge.
- Earlier signal available: PR merge settings may auto-delete branches.
- Rule file to update: none.
