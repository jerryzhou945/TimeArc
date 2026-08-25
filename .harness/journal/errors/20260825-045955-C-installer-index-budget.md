# Error Report - installer-index-budget

## Metadata

- Level: **L2**
- Track: **C**
- Topic: installer-index-budget
- Recorded: 2026-08-25T04:59:55Z
- Session: .harness/journal/sessions/20260825-1254-C-installer-execution.md
- Platform: windows
- Tooling: repository harness checker

## 1. What happened

Final harness check found journal INDEX at 105 lines after installer debugging reports

## 2. Evidence

```
DRIFT: .harness\journal\INDEX.md: 105 lines (limit 100)
```

## 3. Root cause

- Immediate cause: five new installer-debug reports pushed the rolling index beyond its line limit.
- Underlying cause: old L1/L3 rows were not compacted by `record_error.py`, which only bounds L2 rows.
- Why the harness/checklists did not prevent it: the checker is intentionally the enforcement point for this rolling documentation budget.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: retain recent entries and replace older indexed rows with one omission marker; authoritative history remains in `errors.jsonl`.
- Commit: pending

## 5. Prevention

Future harness improvement: compact old L1 and L3 rows as well as L2 rows in `record_error.py`.
