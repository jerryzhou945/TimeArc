# Error Report - installer-regression-red

## Metadata

- Level: **L2**
- Track: **C**
- Topic: installer-regression-red
- Recorded: 2026-08-25T04:55:33Z
- Session: .harness/journal/sessions/20260825-1254-C-installer-execution.md
- Platform: windows
- Tooling: repository-local Python 3.12

## 1. What happened

Installer packaging regression test failed as expected because package-installer.ps1 still selected non-configurable 7zS2.sfx

## 2. Evidence

```
AssertionError: installer must use the configurable 7zSD.sfx module;
7zS2.sfx ignores Installer Config and opens install.ps1 as text
```

## 3. Root cause

- Immediate cause: the new regression assertion correctly rejected the existing `7zS2.sfx` default.
- Underlying cause: this was the intentional RED phase for the user-reported installer defect.
- Why the harness/checklists did not prevent it: not applicable; the failing test was deliberately created before the production fix.

## 4. Fix

- Files changed: `tests/windows_installer_packaging_static_test.py`, `tools/package-installer.ps1`
- Short description: test first failed, then passed after selecting `7zSD.sfx`.
- Commit: pending

## 5. Prevention

Keep the focused packaging test in the regular Windows release verification set.
