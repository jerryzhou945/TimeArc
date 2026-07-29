# Error Report - desktop-ux-missing-android

## Metadata

- Level: **L1**
- Track: **C**
- Topic: desktop-ux-missing-android
- Recorded: 2026-07-29T10:32:55Z
- Session: `journal/sessions/20260729-1832-C-macos-memo-shortcut-label.md`
- Platform: n-a
- Tooling: python static test

## 1. What happened

Desktop UX static test cannot start because android/src/main/AndroidManifest.xml is absent.

## 2. Evidence

```text
FileNotFoundError: android/src/main/AndroidManifest.xml
```

## 3. Root cause

- Immediate cause: The broad static test reads an absent Android manifest before running any assertions.
- Underlying cause: The test assumes Android project inputs exist in every checkout.
- Why the harness/checklists did not prevent it: This was a pre-existing baseline limitation.

## 4. Fix

- Files changed: `tests/macos_memo_shortcut_label_static_test.py`
- Short description: Added an isolated check without unrelated Android inputs.
- Commit: pending

## 5. Prevention

The broad test should eventually skip unavailable platform inputs; that is outside this targeted fix.
