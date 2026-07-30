# Error Report - swift-config-toolchain-cache

## Metadata

- Level: **L1**
- Track: **C**
- Topic: swift-config-toolchain-cache
- Recorded: 2026-07-28T09:41:07Z
- Session: (unknown)
- Platform: macOS
- Tooling: CMake, Swift

## 1. What happened

Recreating the missing build directory failed because Swift used an unwritable home module cache and the active CommandLineTools SDK does not match the Swift compiler

## 2. Evidence

```
error: unable to build module 'SwiftShims'
SDK was built with Swift 6.2.3, while the compiler is Swift 6.2.4
module cache path under /Users/jz2025/.cache was not writable
```

## 3. Root cause

- Immediate cause: the active Command Line Tools SDK and Swift compiler
  versions did not match, and the default module-cache location was outside
  the writable sandbox.
- Underlying cause: an unnecessary attempt was made to recreate the absent
  default build tree instead of using the existing `build-macos` tree.
- Why the harness/checklists did not prevent it: preflight does not validate
  the selected Apple SDK/compiler pair or choose among build directories.

## 4. Fix

- Files changed: none
- Short description: Used the already configured `build-macos` tree, which
  built successfully through the harness.
- Commit: not applicable

## 5. Prevention

One-off environment issue; no harness change.
