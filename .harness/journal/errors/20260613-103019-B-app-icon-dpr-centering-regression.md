# Error Report - app-icon-dpr-centering-regression

## Metadata

- Level: **L3**
- Track: **B**
- Topic: app-icon-dpr-centering-regression
- Recorded: 2026-06-13T10:30:19Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

AppIconImageProvider transparent-padding crop used QPixmap coordinates and mislabeled scope as E5; caused native icons to render at top-left on high-DPI pixmaps

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

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
