# Error Report - memo-loader-autosize

## Metadata

- Level: **L2**
- Track: **C**
- Topic: memo-loader-autosize
- Recorded: 2026-06-05T04:51:13Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Object delegate Loader had anchors.fill:parent; a sized Loader force-resizes its loaded item, so sticky notes ballooned to overlay size on window fullscreen toggle and text layers were overlay-sized at creation. Fix: wrap each object in an overlay-filling shell Item so the Loader stretches the shell, not the note/text.

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
