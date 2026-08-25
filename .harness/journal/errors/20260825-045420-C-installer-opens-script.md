# Error Report - installer-opens-script

## Metadata

- Level: **L2**
- Track: **C**
- Topic: installer-opens-script
- Recorded: 2026-08-25T04:54:20Z
- Session: .harness/journal/sessions/20260825-1254-C-installer-execution.md
- Platform: windows
- Tooling: Windows 7-Zip LZMA SDK 26.02, PowerShell packaging script

## 1. What happened

Windows self-extracting installer opens install.ps1 as text instead of executing installation

## 2. Evidence

```
User screenshot shows the literal contents of install.ps1 after double-clicking
TimeArc-0.1-beta-20260825-win64-setup.exe.

LZMA SDK DOC/installer.txt:
"Small SFX modules ... No installer Configuration file"
```

## 3. Root cause

- Immediate cause: `7zS2.sfx` selected `install.ps1` as the extracted file and invoked its shell association, which displayed it as text.
- Underlying cause: `tools/package-installer.ps1` appended an Installer Config block to the small `7zS2.sfx` module even though that module explicitly does not parse Installer Config.
- Why the harness/checklists did not prevent it: verification checked archive integrity and payload shape, but did not execute a minimal SFX command or assert that the selected module supports configuration.

## 4. Fix

- Files changed: `tools/package-installer.ps1`, `tests/windows_installer_packaging_static_test.py`, `tests/windows_installer_sfx_smoke_test.ps1`
- Short description: replace non-configurable `7zS2.sfx` with `7zSD.sfx`, enable system executable lookup, and cover both configuration and execution.
- Commit: pending

## 5. Prevention

Add a focused packaging regression test that rejects the non-configurable small SFX module.
