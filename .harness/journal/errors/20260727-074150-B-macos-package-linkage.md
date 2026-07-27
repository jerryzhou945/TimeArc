# Error Report - macos-package-linkage

## Metadata

- Level: **L1**
- Track: **B**
- Topic: macos-package-linkage
- Recorded: 2026-07-27T07:41:50Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

macdeployqt copied over-broad Homebrew Qt/QML dependencies and left development-machine paths in the staged app; portable-linkage gate correctly refused the package

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
