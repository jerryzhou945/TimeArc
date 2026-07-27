# Error Report - macos-qt-deploy-symlinks

## Metadata

- Level: **L3**
- Track: **B**
- Topic: macos-qt-deploy-symlinks
- Recorded: 2026-07-27T07:45:59Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The first generated Qt deployment attempt preserved two Homebrew QML plugin symlinks and pruned the wrong plugin subdirectory, so macdeployqt could not open the staged plugins; interrupted the failing temporary package run

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
