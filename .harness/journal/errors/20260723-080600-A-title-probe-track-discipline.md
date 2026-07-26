# Error Report - title-probe-track-discipline

## Metadata

- Level: **L3**
- Track: **A**
- Topic: title-probe-track-discipline
- Recorded: 2026-07-23T08:06:00Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The traversal-limit edit was initially classified as Track A, but harness_check correctly rejected it because TitleProbe belongs to the still-untracked new macOS Tracking feature and therefore requires Track B.

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

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
