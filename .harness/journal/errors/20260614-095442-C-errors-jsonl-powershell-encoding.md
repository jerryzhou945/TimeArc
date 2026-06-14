# Error Report - errors-jsonl-powershell-encoding

## Metadata

- Level: **L3**
- Track: **C**
- Topic: errors-jsonl-powershell-encoding
- Recorded: 2026-06-14T09:54:42Z
- Session: (unknown)
- Platform: Windows / PowerShell
- Tooling: `Set-Content`, `harness_check.py`

## 1. What happened

PowerShell Set-Content rewrote errors.jsonl with a non-UTF-8 encoding while removing duplicate qt-warning rows

## 2. Evidence

```
harness_check.py: internal error: 'utf-8' codec can't decode bytes
in errors.jsonl after PowerShell filtering.
```

## 3. Root cause

- Immediate cause: `Set-Content` wrote `errors.jsonl` with a non-UTF-8 encoding.
- Underlying cause: Windows PowerShell defaults are not safe for repository UTF-8 JSONL rewrites unless `-Encoding utf8` is explicit.
- Why the harness/checklists did not prevent it: the error was detected by the next harness_check pass.

## 4. Fix

- Files changed: `.harness/journal/errors.jsonl`.
- Short description: reconstructed the file from the committed UTF-8 base and re-appended the three retained records as UTF-8 JSONL.
- Commit: final cleanup/docs commit.

## 5. Prevention

One-off agent tool mistake; use Python or `Set-Content -Encoding utf8` for JSONL rewrites on Windows.

## 6. Lessons for agents (L3)

- Wrong assumption: PowerShell `Set-Content` would preserve UTF-8 for JSONL.
- Earlier signal available: Windows PowerShell encoding defaults differ from repository expectations.
- Rule file to update: none; this is covered by the project UTF-8 harness check.
