# Error Report - i18n-category-label-locale

## Metadata

- Level: **L2**
- Track: **B**
- Topic: i18n-category-label-locale
- Recorded: 2026-08-25T16:35:47Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Today Conclusion / Today's Theme rendered a Chinese category inside an English sentence ('Today's main theme: 社交 Focus'). daily_card_service categoryName() hardcoded displayLabel(..., 'zh'), which was correct while cards shipped finished Chinese prose that I18n.smartText re-parsed downstream; English-first removed that translator, so the Chinese label reached the screen unmediated. Fixed to request 'en' (the source language) with QML translating per reader. Same fix applied to the Top Share chip, which still glued category+percent into one string.

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.
