# Error Report - journal-index-line-budget-main

## Metadata

- Level: **L3**
- Track: **C**
- Topic: journal-index-line-budget-main
- Recorded: 2026-07-23T19:40:20Z
- Session: `20260724-0339-C-macos-tracking-main.md`
- Platform: repository harness
- Tooling: `preflight.py`

## 1. What happened

The required macOS main error report pushed the rolling journal index one line over its harness limit.

## 2. Evidence

```
.harness/journal/INDEX.md: 101 lines (limit 100)
```

## 3. Root cause

- Immediate cause: the required L1 report inserted one new rolling-index row.
- Underlying cause: the index was already at its 100-line capacity.
- Why the harness/checklists did not prevent it: report insertion does not compact old display-only rows automatically.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: removed two oldest display rows; their authoritative JSONL records and reports remain.
- Commit: pending

## 5. Prevention

Teach `record_error.py` to compact the rolling index before exceeding 100 lines.

## 6. Lessons for agents (L3)

- Wrong assumption: adding one mandatory report would leave the index within budget.
- Earlier signal available: the index was already exactly 100 lines.
- Rule file to update: `.harness/tools/record_error.py` should enforce the documented rolling-index limit.
