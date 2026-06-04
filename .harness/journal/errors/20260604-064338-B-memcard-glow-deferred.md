# Error Report - memcard-glow-deferred

## Metadata

- Level: **L3**
- Track: **B**
- Topic: memcard-glow-deferred
- Recorded: 2026-06-04T06:43:38Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Left MemoryCard ambientGlow底灯 on MultiEffect-blur-of-solid-rect (judged 'acceptable, showpiece'), citing per-frame Canvas-repaint cost during flip. User reported it still bands / shows a rectangular silhouette. Reality: only ONE selected card flips at a time, so a Canvas-radial repaint is cheap; the blurred-hard-rect was the same defect class as GlowCircle. Fix: same radial-gradient swap. Lesson: any blurred solid shape (not just GlowCircle) bands + keeps its silhouette; use a radial gradient.

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
