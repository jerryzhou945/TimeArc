# Error Report - windows-icon-resource-red

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-icon-resource-red
- Recorded: 2026-08-25T05:20:57Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: repository-local Python PE parser

## 1. What happened

Expected RED: built TimeArc.exe has no native RT_ICON resource

## 2. Evidence

```
AssertionError: build/TimeArc.exe has no native RT_ICON resource
```

## 3. Root cause

- Immediate cause: the existing executable contained no native icon resource.
- Underlying cause: intentional RED phase for the confirmed defect.
- Why the harness/checklists did not prevent it: the test was deliberately introduced to prove the missing behavior.

## 4. Fix

- Files changed: `tests/windows_executable_icon_test.py`
- Short description: test failed before implementation and passed after the RC resource was linked.
- Commit:

## 5. Prevention

Keep the PE resource test in Windows release verification.
