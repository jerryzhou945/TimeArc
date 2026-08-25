# Error Report - native-icon-index-budget

## Metadata

- Level: **L2**
- Track: **C**
- Topic: native-icon-index-budget
- Recorded: 2026-08-25T05:35:37Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: repository harness line-budget gate

## 1. What happened

Windows icon debug reports expanded the rolling journal INDEX to 104 lines before final verification

## 2. Evidence

```
INDEX.md: 104 lines before the final verification gate.
```

## 3. Root cause

- Immediate cause: this debug session added multiple required error rows.
- Underlying cause: the rolling index retains old L1/L3 rows while JSONL is already authoritative.
- Why the harness/checklists did not prevent it: line-budget enforcement is the mechanism that surfaces the need to compact.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: replace older indexed rows with one aggregate omission marker; keep full history in `errors.jsonl`.
- Commit:

## 5. Prevention

Future harness improvement: bound old L1/L3 rows automatically, as it already does for L2 rows.
