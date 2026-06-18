# Error Report - home-english-category-list-red-test

## Metadata

- Level: **L2**
- Track: **C**
- Topic: home-english-category-list-red-test
- Recorded: 2026-06-18T15:43:19Z
- Session: `.harness/journal/sessions/20260618-2338-C-english-tags-icons-mac-doc.md`
- Platform: Windows
- Tooling: Node i18n red check

## 1. What happened

Expected red test confirmed generated English Home summaries leaked Chinese
category lists.

## 2. Evidence

```text
Chinese leaked: Today had 4 continuous sessions. Longest about 54m, mainly in 社交、开发.
```

## 3. Root cause

- Immediate cause: `category()` was called on a whole category list.
- Underlying cause: no helper existed for generated list text.
- Why the harness/checklists did not prevent it: no multi-category sample.

## 4. Fix

- Files changed: `qml/desktop/components/I18n.js`
- Short description: split and translate category lists.
- Commit: pending

## 5. Prevention

Keep this Node sample in ad-hoc i18n verification.
