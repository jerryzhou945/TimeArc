# Error Report - appkit-traffic-lights-bottom

## Metadata

- Level: **L2**
- Track: **B**
- Topic: appkit-traffic-lights-bottom
- Recorded: 2026-07-28T07:24:54Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

AppKit standard traffic lights rendered at the bottom-left because the Qt NSView uses flipped coordinates and the host assumed a bottom-left origin.

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
