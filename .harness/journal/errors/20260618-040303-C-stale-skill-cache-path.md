# Error Report - stale-skill-cache-path

## Metadata

- Level: **L3**
- Track: **C**
- Topic: stale-skill-cache-path
- Recorded: 2026-06-18T04:03:03Z
- Session: (unknown)
- Platform: n-a
- Tooling: PowerShell

## 1. What happened

Attempted to read superpowers skill files from stale plugin cache paths; files were not present in this session cache.

## 2. Evidence

```
Get-Content against the previous `D:\codex\plugins\cache\openai-curated`
superpowers skill path failed with "Cannot find path".
```

## 3. Root cause

- Immediate cause: Reused a stale plugin cache path from an earlier session.
- Underlying cause: Plugin cache versions are session-local and should not be
  treated as stable paths.
- Why the harness/checklists did not prevent it: This was an agent-side tool
  lookup mistake before code edits.

## 4. Fix

- Files changed: none for product code.
- Short description: Continued with project harness rules and recorded the
  failed lookup.
- Commit: pending

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: Cached plugin skill paths are stable between sessions.
- Earlier signal available: The path came from prior context, not current
  filesystem discovery.
- Rule file to update: none.
