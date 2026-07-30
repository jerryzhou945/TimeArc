# Error Report - macos-unsupported-cmake-generator

## Metadata

- Level: **L1**
- Track: **B**
- Topic: macos-unsupported-cmake-generator
- Recorded: 2026-07-27T15:30:03Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

build-macos.sh defaulted to Unix Makefiles, which CMake cannot use when enabling the Swift service target.

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
