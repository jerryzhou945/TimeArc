# Error Report - installer-powershell-lookup

## Metadata

- Level: **L2**
- Track: **C**
- Topic: installer-powershell-lookup
- Recorded: 2026-08-25T04:57:29Z
- Session: .harness/journal/sessions/20260825-1254-C-installer-execution.md
- Platform: windows
- Tooling: Windows 7-Zip LZMA SDK 26.02 executable smoke test

## 1. What happened

Minimal corrected-module SFX smoke test exited 1 because RunProgram defaulted to the extraction directory and could not resolve powershell.exe

## 2. Evidence

```
smoke SFX exited with 1
LZMA SDK DOC/installer.txt states that Directory="" enables system lookup.
```

## 3. Root cause

- Immediate cause: `powershell.exe` was searched beneath the extracted temporary directory.
- Underlying cause: `RunProgram` defaults to `Directory=".\\"`; external system commands require `Directory=""`.
- Why the harness/checklists did not prevent it: the original packaging verification never launched a harmless test SFX.

## 4. Fix

- Files changed: `tools/package-installer.ps1`, `tests/windows_installer_packaging_static_test.py`, `tests/windows_installer_sfx_smoke_test.ps1`
- Short description: set `Directory=""`, assert it statically, and verify the real SFX invocation creates a marker.
- Commit: pending

## 5. Prevention

Retain the executable smoke test for future installer packaging changes.
