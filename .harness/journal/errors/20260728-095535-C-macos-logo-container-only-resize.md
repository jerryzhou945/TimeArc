# Error Report - macos-logo-container-only-resize

## Metadata

- Level: **L1**
- Track: **C**
- Topic: macos-logo-container-only-resize
- Recorded: 2026-07-28T09:55:35Z
- Session: (unknown)
- Platform: macOS
- Tooling: `.harness/tools/build.py`, CMake

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
Error: /Users/jz2025/Desktop/Development/TimeArc/build-macos is not a directory
```

## 3. Root cause

- Immediate cause: the previously used `build-macos` directory no longer
  existed.
- Underlying cause: build-directory state changed externally between the
  preceding successful build and this follow-up.
- Why the harness/checklists did not prevent it: the build wrapper validates
  but does not recreate a missing configured build tree.

## 4. Fix

- Files changed: none
- Short description: Used the available configured `build` tree; the Debug
  build and tests passed.
- Commit: not applicable

## 5. Prevention

One-off workspace-state change; no harness change.
