# Error Report - remote-branch-already-deleted

## Metadata

- Level: **L3**
- Track: **C**
- Topic: remote-branch-already-deleted
- Recorded: 2026-06-18T04:19:53Z
- Session: (unknown)
- Platform: n-a
- Tooling: git, GitHub pull request merge

## 1. What happened

After PR #36 merged, GitHub had already deleted the remote branch; manual git push --delete returned remote ref does not exist during cleanup.

## 2. Evidence

```
error: unable to delete 'codex/fix-english-copy-gaps': remote ref does not exist
error: failed to push some refs to 'https://github.com/jerryzhou945/TimeArc.git'
git fetch --prune then reported origin/codex/fix-english-copy-gaps deleted.
```

## 3. Root cause

- Immediate cause: Manual remote branch deletion ran after GitHub had already
  removed the PR head branch.
- Underlying cause: Cleanup assumed the remote branch still existed.
- Why the harness/checklists did not prevent it: The branch existence check was
  skipped before running `git push origin --delete`.

## 4. Fix

- Files changed: none for product code.
- Short description: Confirmed local branch deletion and remote branch absence
  with `git branch -r --list` / `git fetch --prune`.
- Commit: pending

## 5. Prevention

One-off cleanup issue; before deleting a remote PR branch manually, check
whether GitHub already deleted it.

## 6. Lessons for agents (L3)

- Wrong assumption: PR merge did not delete the remote branch.
- Earlier signal available: `git fetch --prune` can reveal deleted remote refs.
- Rule file to update: none.
