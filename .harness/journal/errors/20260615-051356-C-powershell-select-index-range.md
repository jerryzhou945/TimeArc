# Error Report - powershell-select-index-range

## Metadata

- Level: **L3**
- Track: **C**
- Topic: powershell-select-index-range
- Recorded: 2026-06-15T05:13:56Z
- Session: `.harness/journal/sessions/20260615-1312-C-ui-stats-memorylake-language-followups.md`
- Platform: Windows PowerShell
- Tooling: `Get-Content`, `Select-Object`

## 1. What happened

Used Select-Object -Index with a string range; PowerShell requires an array expression or Skip/First. Retrying with Skip/First.

## 2. Evidence

`Select-Object : Cannot bind parameter 'Index'. Cannot convert value "210..310"`.

## 3. Root cause

- Immediate cause: used a string range with `Select-Object -Index`.
- Underlying cause: PowerShell requires an array expression or `-Skip/-First`.
- Why the harness/checklists did not prevent it: this was command syntax, not
  project behavior.

## 4. Fix

- Files changed: none.
- Short description: retried with `Select-Object -Skip ... -First ...`.
- Commit: n/a

## 5. Prevention

One-off agent command mistake; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: Bash-style range syntax would bind as a PowerShell array.
- Earlier signal available: PowerShell syntax rules.
- Rule file to update: none.
