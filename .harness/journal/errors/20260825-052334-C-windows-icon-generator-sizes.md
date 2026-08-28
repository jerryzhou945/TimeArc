# Error Report - windows-icon-generator-sizes

## Metadata

- Level: **L1**
- Track: **C**
- Topic: windows-icon-generator-sizes
- Recorded: 2026-08-25T05:23:34Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: Pillow 12.3.0 ICO writer

## 1. What happened

Windows icon generator passed integer sizes to Pillow ICO writer, which requires width-height tuples

## 2. Evidence

```
TypeError: 'int' object is not subscriptable
```

## 3. Root cause

- Immediate cause: `sizes` contained integers instead of `(width, height)` tuples.
- Underlying cause: the Pillow ICO API shape was recalled incorrectly.
- Why the harness/checklists did not prevent it: the generator's first execution was the API integration test.

## 4. Fix

- Files changed: `tools/generate-windows-icon.py`
- Short description: supply seven square dimension tuples; generation and frame inspection now pass.
- Commit:

## 5. Prevention

The committed ICO output and seven-size inspection protect the release artifact; no harness change needed.
