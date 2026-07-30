# Error Report - macos-gui-screenshot-tcc-blocked

## Metadata

- Level: **L3**
- Track: **B**
- Topic: macos-gui-screenshot-tcc-blocked
- Recorded: 2026-07-30T06:00:14Z
- Session: 20260730-1347-B-macos-memo-traffic-lights
- Platform: macos
- Tooling: (fill in)

## 1. What happened

Screen Recording and Automation are not granted to the agent shell, so screencapture -l and osascript both fail; the before-commit full-bleed 1280x720/maximized screenshot step could not run for the memo overlay change.

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
