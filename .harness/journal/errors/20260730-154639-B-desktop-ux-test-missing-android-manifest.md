# Error Report - desktop-ux-test-missing-android-manifest

## Metadata

- Level: **L3**
- Track: **B**
- Topic: desktop-ux-test-missing-android-manifest
- Recorded: 2026-07-30T15:46:39Z
- Session: `20260730-2344-B-about-settings-page.md`
- Platform: n-a
- Tooling: Python 3.12 static test

## 1. What happened

desktop_ux_static_test.py aborts before UI assertions because android/src/main/AndroidManifest.xml is absent in this checkout

## 2. Evidence

`FileNotFoundError: android/src/main/AndroidManifest.xml`

## 3. Root cause

- Immediate cause: The script unconditionally reads a missing Android manifest.
- Underlying cause: A broad cross-platform test owns unrelated desktop assertions.
- Why the harness/checklists did not prevent it: The test has no prerequisite guard.

## 4. Fix

- Files changed: `tests/about_settings_page_static_test.py`
- Short description: Added a focused test without the unrelated Android dependency.
- Commit: pending

## 5. Prevention

Keep page-specific assertions in a focused test with only relevant prerequisites.

## 6. Lessons for agents (L3)

- Wrong assumption: The broad desktop test was runnable in this checkout.
- Earlier signal available: `android/` was absent from the repository tree.
- Rule file to update: one-off, no rule change needed.
