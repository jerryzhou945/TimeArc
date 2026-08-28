# Error Report - icon-check-after-generate-failure

## Metadata

- Level: **L3**
- Track: **C**
- Topic: icon-check-after-generate-failure
- Recorded: 2026-08-25T05:23:35Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: PowerShell command sequencing

## 1. What happened

Chained icon inspection commands ran after generation failed and produced avoidable missing-file errors

## 2. Evidence

```
Generation failed, then Get-Item and Get-FileHash reported the expected missing ICO.
```

## 3. Root cause

- Immediate cause: semicolon-separated inspection commands ran after the generator exited non-zero.
- Underlying cause: the command did not gate later steps on generation success.
- Why the harness/checklists did not prevent it: this was an agent command-composition mistake.

## 4. Fix

- Files changed: journal only
- Short description: reran generation and inspection as separate gated commands.
- Commit:

## 5. Prevention

One-off; keep failure-prone generation separate from artifact inspection.

## 6. Lessons for agents (L3)

- Wrong assumption: later read-only checks would not obscure the primary failure.
- Earlier signal available: the generator traceback was already sufficient.
- Rule file to update: none; existing command-sequencing guidance applies.
