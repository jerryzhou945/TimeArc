# Error Report - live-service-no-db-write

## Metadata

- Level: **L2**
- Track: **C**
- Topic: live-service-no-db-write
- Recorded: 2026-08-24T21:52:12Z
- Session: journal/sessions/20260825-0537-C-agent-media-timing.md
- Platform: windows
- Tooling: (fill in)

## 1. What happened

Live rebuilt service stayed responsive but the expected service database mtime and rows did not advance, invalidating the first agent smoke result.

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.
