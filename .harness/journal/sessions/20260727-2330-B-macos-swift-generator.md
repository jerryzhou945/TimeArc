# Track B — Swift-capable macOS generator

## Goal

Make the default macOS release command configure the Swift service reliably.

## Scope

- Build side: prefer Ninja, fall back to Xcode, reject unsupported explicit
  generators, and reset only generated CMake state on a cached mismatch.
- Service/UI sides: source behavior and disk contracts are unchanged.
- Related errors: `20260727-153003-B-macos-unsupported-cmake-generator.md`,
  `20260727-153136-B-macos-build-script-yield.md`, and
  `20260727-153646-B-macos-generator-doc-context.md`.

## Outcome

The original `build-macos` directory migrated from Unix Makefiles to Ninja.
The exact no-option `tools/build-macos.sh` command then completed configure,
Release build, both tests, Qt deployment, ad-hoc signing, and verified DMG
creation.
