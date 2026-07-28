# Error Report - traffic-light-hover-dimming

## Metadata

- Level: **L2**
- Track: **B**
- Topic: traffic-light-hover-dimming
- Recorded: 2026-07-28T07:54:55Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

AppKit traffic-light colors dimmed on hover because the host forced NSButton.highlighted, which represents the pressed state rather than native group hover.

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
