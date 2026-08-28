# Error Report - stale-windows-rc-compiler

## Metadata

- Level: **L1**
- Track: **C**
- Topic: stale-windows-rc-compiler
- Recorded: 2026-08-25T05:27:41Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: CMake 3.30.5, Ninja, MinGW windres

## 1. What happened

CMake regeneration kept a stale F: drive windres path in CMakeRCCompiler.cmake, so the new RC source could not compile

## 2. Evidence

```
CMakeCache.txt: CMAKE_RC_COMPILER=D:/TimeArc/.../windres.exe
CMakeRCCompiler.cmake: CMAKE_RC_COMPILER=F:/TimeArc/.../windres.exe
```

## 3. Root cause

- Immediate cause: Ninja used the compiler-information file's stale F: path.
- Underlying cause: CMake compiler metadata is initialized once and did not follow the cache/workspace relocation.
- Why the harness/checklists did not prevent it: Windows resources were not previously compiled in this target.

## 4. Fix

- Files changed: generated build metadata only
- Short description: remove `CMakeRCCompiler.cmake`, reconfigure with D: windres, and rebuild.
- Commit:

## 5. Prevention

The release build now exercises windres; no source-level workaround or drive-specific path was committed.
