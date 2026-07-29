# Error Report - journal-index-line-budget

## Metadata

- Level: **L1**
- Track: **C**
- Topic: journal-index-line-budget
- Recorded: 2026-07-29T10:33:38Z
- Session: `journal/sessions/20260729-1832-C-macos-memo-shortcut-label.md`
- Platform: n-a
- Tooling: harness_check.py

## 1. What happened

Harness audit found journal/INDEX.md at 102 lines after required debug reports were added.

## 2. Evidence

```text
DRIFT: .harness/journal/INDEX.md: 102 lines (limit 100)
```

## 3. Root cause

- Immediate cause: Required reports appended rows beyond the rolling index budget.
- Underlying cause: Redundant old omission markers had accumulated at the end of the index.
- Why the harness/checklists did not prevent it: The recorder does not automatically compact the human-readable rolling index.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: Removed redundant old omission markers while preserving the authoritative `errors.jsonl` history.
- Commit: pending

## 5. Prevention

The recorder should compact redundant omission markers before appending.
