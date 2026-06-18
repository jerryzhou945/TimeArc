# Error Report - rg-access-denied-english-icons-mac-doc

## Metadata

- Level: **L3**
- Track: **C**
- Topic: rg-access-denied-english-icons-mac-doc
- Recorded: 2026-06-18T15:40:18Z
- Session: `.harness/journal/sessions/20260618-2338-C-english-tags-icons-mac-doc.md`
- Platform: Windows
- Tooling: ripgrep under sandbox

## 1. What happened

`rg` failed with Access denied while searching QML/C++ files.

## 2. Evidence

```text
Program 'rg.exe' failed to run: Access is denied
```

## 3. Root cause

- Immediate cause: sandbox refused the `rg.exe` process.
- Underlying cause: intermittent Windows sandbox/tooling issue already seen in
  this repo.
- Why the harness/checklists did not prevent it: search tooling is exploratory.

## 4. Fix

- Files changed: none for product behavior.
- Short description: fell back to `Get-ChildItem` and `Select-String`.
- Commit: pending

## 5. Prevention

One-off, no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: `rg` would be available in this sandbox turn.
- Earlier signal available: prior Access denied reports.
- Rule file to update: none.
