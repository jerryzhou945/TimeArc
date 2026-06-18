# Error Report - home-tag-combobox-red-test

## Metadata

- Level: **L2**
- Track: **C**
- Topic: home-tag-combobox-red-test
- Recorded: 2026-06-18T15:18:40Z
- Session: `.harness/journal/sessions/20260618-2316-C-home-tags-platform-doc.md`
- Platform: Windows
- Tooling: PowerShell structural red check

## 1. What happened

Expected red structural check confirmed the Home add-project ComboBox still used
`fixedTags` and `currentText` directly in English mode.

## 2. Evidence

```text
Home tag ComboBox still displays/saves translated text unsafely
```

## 3. Root cause

- Immediate cause: the intentionally failing structural check found the
  untranslated ComboBox model and unsafe save path.
- Underlying cause: Home tag editing used the same string for UI display and
  storage.
- Why the harness/checklists did not prevent it: this was a focused TDD red
  check added after the user pointed out the remaining leak.

## 4. Fix

- Files changed: `qml/desktop/pages/DesktopHomePage.qml`
- Short description: replace direct `fixedTags/currentText` usage with
  translated display labels and canonical saved values.
- Commit: pending

## 5. Prevention

One-off, no harness change. Keep display text and saved value separate for any
future localized ComboBox.
