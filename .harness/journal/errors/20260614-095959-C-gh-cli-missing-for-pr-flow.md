# Error Report - gh-cli-missing-for-pr-flow

## Metadata

- Level: **L3**
- Track: **C**
- Topic: gh-cli-missing-for-pr-flow
- Recorded: 2026-06-14T09:59:59Z
- Session: (unknown)
- Platform: Windows / GitHub publish flow
- Tooling: `gh --version`, GitHub connector fallback

## 1. What happened

GitHub publish flow requested but gh is not available in PATH; attempting GitHub connector fallback

## 2. Evidence

```
gh : The term 'gh' is not recognized as the name of a cmdlet,
function, script file, or operable program.
```

## 3. Root cause

- Immediate cause: GitHub CLI is not available in PATH.
- Underlying cause: this environment has GitHub connector tools but no local `gh` executable.
- Why the harness/checklists did not prevent it: the publish flow checks `gh` only when PR creation starts.

## 4. Fix

- Files changed: none.
- Short description: use GitHub connector tools for PR creation/merge after pushing the branch with git.
- Commit: pending publish cleanup commit.

## 5. Prevention

One-off environment limitation; no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: `gh` would be available because GitHub work was requested.
- Earlier signal available: `where.exe gh` would have shown it before publish.
- Rule file to update: none.
