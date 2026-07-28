# Error Report - qt-content-titlebar-still-visible

## Metadata

- Level: **L2**
- Track: **B**
- Topic: qt-content-titlebar-still-visible
- Recorded: 2026-07-28T07:45:47Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Manual expansion of NSWindow.contentView did not remove the visible title bar because Qt's native wrapper continued enforcing its own title-region geometry.

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
