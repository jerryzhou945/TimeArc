# Error Report - macos-build-script-static-baseline

## Metadata

- Level: **L1**
- Track: **C**
- Topic: macos-build-script-static-baseline
- Recorded: 2026-07-29T10:04:35Z
- Session: `sessions/20260729-1801-C-macos-app-menu-localization.md`
- Platform: macOS
- Tooling: `tests/macos_build_script_static_test.py`

## 1. What happened

The existing macOS build-script static test failed before reaching the new
translation assertions.

## 2. Evidence

`AssertionError: missing harness-wrapped compilation:
"$REPO_ROOT/.harness/tools/build.py"`

## 3. Root cause

- Immediate cause: the test requires the harness wrapper while the release
  script still contains a bare `cmake --build`.
- Underlying cause: this pre-existing build-script/test drift was already
  documented by the active menu-bar session but remains unresolved.
- Why the harness/checklists did not prevent it: the branch already contained
  the mismatch before this debug session.

## 4. Fix

- Files changed: none for this unrelated failure
- Short description: left out of scope; translation packaging is covered by
  the passing focused menu test instead.
- Commit: n/a

## 5. Prevention

Resolve the existing wrapper mismatch in its own harness/build-system session.
