# Error Report - env-fs-overlay-wrong-branch

## Metadata

- Level: **L3**
- Track: **B**
- Topic: env-fs-overlay-wrong-branch
- Recorded: 2026-06-09T11:00:22Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

File tools (Edit/Write) landed in an overlay FS the compiler/git don't read; real git HEAD stayed on feat/a1 despite a phantom 'switched to b1', so S1 first committed to the wrong branch. Recovery: write source via Bash heredoc + dangerouslyDisableSandbox, verify every change with git diff, switch branches verified by HEAD hash (not branch name), cherry-pick S1 onto b1. Edits also silently reverted until written through the real-FS path.

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
