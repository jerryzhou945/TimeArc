# Error Report - resource-followup-index-line-budget

## Metadata

- Level: **L1**
- Track: **C**
- Topic: resource-followup-index-line-budget
- Recorded: 2026-07-25T12:59:52Z
- Session: `20260725-2057-C-resource-path-followup.md`
- Platform: macOS
- Tooling: `harness_check.py`

## 1. What happened

Mandatory Track C error entry pushed the rolling journal index from 100 to 101 lines

## 2. Evidence

`harness_check.py` reported `.harness/journal/INDEX.md: 101 lines (limit 100)`.

## 3. Root cause

- Immediate cause: The mandatory Track C report added a row to an index already at its limit.
- Underlying cause: `record_error.py` appends without rolling old index rows off.
- Why the harness/checklists did not prevent it: The recorder does not enforce the same line budget as the audit.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: Omitted two oldest index rows while retaining their reports and JSONL entries.
- Commit: pending

## 5. Prevention

Teach `record_error.py` to cap the human-readable index automatically.
