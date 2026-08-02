# Error Report - rg-access-denied

## Metadata

- Level: **L3**
- Track: **C**
- Topic: rg-access-denied
- Recorded: 2026-08-02T05:08:12Z
- Session: (unknown)
- Platform: n-a
- Tooling: rg / PowerShell Select-String

## 1. What happened

rg.exe access denied while locating backlog milestone; used PowerShell Select-String fallback

## 2. Evidence

```
Program 'rg.exe' failed to run: Access is denied
```

## 3. Root cause

- Immediate cause: the installed rg executable could not be launched in the current sandbox.
- Underlying cause: execution permission on that external binary was unavailable.
- Why the harness/checklists did not prevent it: this was a shell-tool availability issue, not a source validation failure.

## 4. Fix

- Files changed: none.
- Short description: used PowerShell Select-String as the documented fallback.
- Commit: pending verification commit.

## 5. Prevention

One-off environment restriction; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: that the available rg binary remained executable in this sandbox.
- Earlier signal available: none in this session.
- Rule file to update: none; the root instructions already specify using a fallback when rg is unavailable.
