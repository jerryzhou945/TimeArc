# Error Report - powershell-angle-filter

## Metadata

- Level: **L3**
- Track: **C**
- Topic: powershell-angle-filter
- Recorded: 2026-06-15T07:20:42Z
- Session: (unknown)
- Platform: n-a
- Tooling: PowerShell

## 1. What happened

Used a PowerShell -Filter pattern containing angle brackets while locating the preflight session file, causing an illegal path character error; switching to literal-safe listing.

## 2. Evidence

```
Get-ChildItem -Filter '*<slug>*' failed because angle brackets are not valid
path characters in the provider filter.
```

## 3. Root cause

- Immediate cause: Used the placeholder text `<slug>` inside a PowerShell `-Filter`
  argument as if it were literal search text.
- Underlying cause: Treated the suggested session filename template as a safe glob.
- Why the harness/checklists did not prevent it: This was a command-entry mistake
  while locating a journal file, outside build/runtime gates.

## 4. Fix

- Files changed: none for product code.
- Short description: Switched to literal-safe listing and created the actual
  session file with a concrete slug.
- Commit: pending

## 5. Prevention

One-off command mistake; avoid copying angle-bracket placeholders into
PowerShell path filters.

## 6. Lessons for agents (L3)

- Wrong assumption: Placeholder syntax was safe inside a PowerShell filter.
- Earlier signal available: The preflight output showed `<slug>` as a template,
  not a real filename.
- Rule file to update: none.
