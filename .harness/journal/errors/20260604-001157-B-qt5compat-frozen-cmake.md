# Error Report - qt5compat-frozen-cmake

## Metadata

- Level: **L3**
- Track: **B**
- Topic: qt5compat-frozen-cmake
- Recorded: 2026-06-04T00:11:57Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Donut center glow first used import Qt5Compat.GraphicalEffects (Glow), but Qt5Compat is not in the frozen top-level CMakeLists Qt6 COMPONENTS and not deployed; would break the real app at runtime. Switched to QtQuick.Effects.MultiEffect (already used) — same night-gated glow, no frozen-file change.

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
