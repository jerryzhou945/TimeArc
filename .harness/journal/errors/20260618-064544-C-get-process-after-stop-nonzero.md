# Error Report - get-process-after-stop-nonzero

## Metadata

- Level: **L3**
- Track: **C**
- Topic: get-process-after-stop-nonzero
- Recorded: 2026-06-18T06:45:44Z
- Session: (unknown)
- Platform: n-a
- Tooling: PowerShell

## 1. What happened

After stopping TimeArc, a follow-up Get-Process check returned non-zero because the process was gone.

## 2. Evidence

```
Stop-Process succeeded; the chained follow-up `Get-Process TimeArc` returned
non-zero because no matching process remained.
```

## 3. Root cause

- Immediate cause: A verification command treated "process absent" as a shell
  failure.
- Underlying cause: `Get-Process` without a fallback returns non-zero when the
  process is gone.
- Why the harness/checklists did not prevent it: This was a command composition
  issue during local cleanup.

## 4. Fix

- Files changed: none for product code.
- Short description: Recorded the non-zero command and continued after confirming
  the subsequent build passed.
- Commit: pending

## 5. Prevention

One-off command issue; use a success-producing absence check when verifying a
stopped process.

## 6. Lessons for agents (L3)

- Wrong assumption: `Get-Process -ErrorAction SilentlyContinue` would exit 0
  when no process was found.
- Earlier signal available: PowerShell process lookup semantics.
- Rule file to update: none.
