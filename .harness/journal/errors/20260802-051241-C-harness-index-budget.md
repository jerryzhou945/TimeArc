# Error Report - harness-index-budget

## Metadata

- Level: **L2**
- Track: **C**
- Topic: harness-index-budget
- Recorded: 2026-08-02T05:12:41Z
- Session: (unknown)
- Platform: n-a
- Tooling: harness_check.py / rolling journal index

## 1. What happened

harness_check found journal INDEX.md at 105 lines after automatic error entries; compact index below 100 lines

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause: automatic error entries pushed INDEX.md to 105 lines.
- Underlying cause: the rolling human-readable index retained too many older entries.
- Why the harness/checklists did not prevent it: harness_check detected the drift at the intended pre-commit gate.

## 4. Fix

- Files changed: .harness/journal/INDEX.md.
- Short description: removed older rows while retaining the authoritative errors.jsonl and a rolling omission marker.
- Commit: pending verification commit.

## 5. Prevention

The existing line-budget check worked as designed; no harness change.
