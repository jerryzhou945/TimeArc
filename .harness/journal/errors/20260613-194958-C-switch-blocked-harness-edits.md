# Error Report - switch-blocked-harness-edits

## Metadata

- Level: **L3**
- Track: **C**
- Topic: switch-blocked-harness-edits
- Recorded: 2026-06-13T19:49:58Z
- Session: .harness/journal/sessions/20260614-0339-C-app-icon-small-corner.md
- Platform: windows
- Tooling: git branch management in PowerShell

## 1. What happened

git switch -c codex/app-icon-normal-centered origin/dev was blocked by tracked harness journal/current-track edits; renaming current branch instead.

## 2. Evidence

```
error: Your local changes to the following files would be overwritten by checkout:
  .harness/journal/INDEX.md
  .harness/journal/errors.jsonl
  .harness/state/current-track
Please commit your changes or stash them before you switch branches.
```

## 3. Root cause

- Immediate cause: `git switch -c ... origin/dev` would have overwritten tracked harness edits from this active C-track session.
- Underlying cause: the session began on a stale merged branch whose upstream was later pruned, and the harness modifies tracked journal/current-track files early in the session.
- Why the harness/checklists did not prevent it: branch cleanup happened after the session log and error journal had already changed tracked files.

## 4. Fix

- Files changed: no source changes for this error; branch metadata only.
- Short description: renamed the current branch to `codex/app-icon-normal-centered` and unset its stale gone upstream instead of switching bases mid-session.
- Commit: pending commit.

## 5. Prevention

One-off workflow issue; no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: a new branch could be created from `origin/dev` after harness tracked files were modified.
- Earlier signal available: `git status --short --branch` already showed tracked `.harness` edits.
- Rule file to update: none.
