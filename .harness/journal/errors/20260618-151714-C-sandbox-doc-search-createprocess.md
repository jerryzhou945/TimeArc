# Error Report - sandbox-doc-search-createprocess

## Metadata

- Level: **L3**
- Track: **C**
- Topic: sandbox-doc-search-createprocess
- Recorded: 2026-06-18T15:17:14Z
- Session: `.harness/journal/sessions/20260618-2316-C-home-tags-platform-doc.md`
- Platform: Windows
- Tooling: PowerShell Select-String under sandbox

## 1. What happened

A parallel `Select-String` documentation search failed with Windows sandbox
`CreateProcessWithLogonW` error 1056 during packaging review.

## 2. Evidence

```text
CreateProcessWithLogonW failed: 1056
```

## 3. Root cause

- Immediate cause: the sandbox failed to create one of the parallel PowerShell
  search processes.
- Underlying cause: this was a tooling/sandbox process-launch failure, not a
  product code failure.
- Why the harness/checklists did not prevent it: broad documentation search is
  an exploratory command and can still hit environment-specific launch limits.

## 4. Fix

- Files changed: none for product behavior.
- Short description: reran the review with smaller direct file reads instead of
  relying on the failed broad parallel search.
- Commit: pending

## 5. Prevention

Prefer narrower file reads when broad searches are not essential in Windows
sandboxed sessions.

## 6. Lessons for agents (L3)

- Wrong assumption: a broad parallel documentation search would be as reliable
  as narrow file reads in this Windows sandbox.
- Earlier signal available: this repo has previous records of `rg`/PowerShell
  search failures under sandboxed Windows runs.
- Rule file to update: none.
