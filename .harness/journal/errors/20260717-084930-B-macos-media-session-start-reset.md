# Error Report - macos-media-session-start-reset

## Metadata

- Level: **L2**
- Track: **B**
- Topic: macos-media-session-start-reset
- Recorded: 2026-07-17T08:49:30Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

MediaManager.updateTrackedSessions rebuilds background AppMedia values with a new default start timestamp on each tick, losing the original media-session start time.

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
