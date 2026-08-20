# Error Report - alpha3-package-qt-path

## Metadata

- Level: **L1**
- Track: **C**
- Topic: alpha3-package-qt-path
- Recorded: 2026-08-20T15:43:14Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

package-release.ps1 defaulted to missing C:/Qt windeployqt although this workspace uses D:/TimeArc/QT; rerun with explicit verified Qt and MinGW paths

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
