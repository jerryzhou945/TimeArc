# Error Report - powershell-quote-pattern

## Metadata

- Level: **L3**
- Track: **C**
- Topic: powershell-quote-pattern
- Recorded: 2026-06-18T04:05:54Z
- Session: (unknown)
- Platform: n-a
- Tooling: PowerShell Select-String

## 1. What happened

A Select-String command used an invalid quoted pattern while locating settings license copy; split into simpler searches.

## 2. Evidence

```
The string is missing the terminator: '.
```

## 3. Root cause

- Immediate cause: A complex `Select-String -Pattern` argument mixed quotes
  incorrectly.
- Underlying cause: Tried to combine too many search terms in one PowerShell
  string after switching away from `rg`.
- Why the harness/checklists did not prevent it: This was a command-entry
  mistake during investigation.

## 4. Fix

- Files changed: none for product code.
- Short description: Split the search into simpler patterns.
- Commit: pending

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: The composed PowerShell pattern was quoted safely.
- Earlier signal available: The command contained both single and double quote
  delimiters.
- Rule file to update: none.
