# Error Report - installer-output-locked

## Metadata

- Level: **L2**
- Track: **C**
- Topic: installer-output-locked
- Recorded: 2026-08-25T04:56:10Z
- Session: .harness/journal/sessions/20260825-1254-C-installer-execution.md
- Platform: windows
- Tooling: PowerShell process inspection and packaging script

## 1. What happened

Repackaging could not replace the old setup EXE because the user-launched SFX process still held it open

## 2. Evidence

```
Remove-Item: Access to ...TimeArc-0.1-beta-20260825-win64-setup.exe is denied.
PID 29088  TimeArc-0.1-beta-20260825-win64-setup
```

## 3. Root cause

- Immediate cause: PID 29088 still held the old setup executable open.
- Underlying cause: the broken small SFX waits for the shell-opened child document to close.
- Why the harness/checklists did not prevent it: runtime lock is external state created by the reproduction.

## 4. Fix

- Files changed: none
- Short description: stopped only the identified broken setup process, then regenerated the artifact.
- Commit: pending

## 5. Prevention

One-off reproduction state; no harness change needed.
