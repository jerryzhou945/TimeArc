# Error Report - home-english-generated-tags-chinese

## Metadata

- Level: **L2**
- Track: **C**
- Topic: home-english-generated-tags-chinese
- Recorded: 2026-06-18T15:39:40Z
- Session: `.harness/journal/sessions/20260618-2338-C-english-tags-icons-mac-doc.md`
- Platform: Windows
- Tooling: user screenshot, Node i18n check

## 1. What happened

English Home summary text still contained raw Chinese category names such as
`社交、开发`.

## 2. Evidence

```text
Today had 4 continuous sessions. Longest about 54m, mainly in 社交、开发.
```

## 3. Root cause

- Immediate cause: `I18n.smartText()` translated a single category only.
- Underlying cause: generated DailyCardService text can contain category lists
  joined with `、`, and the English translation path did not split them.
- Why the harness/checklists did not prevent it: previous checks used one
  category sample only.

## 4. Fix

- Files changed: `qml/desktop/components/I18n.js`
- Short description: add `categoryList()` and use it for continuous-session
  summaries.
- Commit: pending

## 5. Prevention

Keep multi-category generated-copy samples in i18n checks when touching Home.
