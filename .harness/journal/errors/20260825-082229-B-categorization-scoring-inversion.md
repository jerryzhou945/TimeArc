# Error Report - categorization-scoring-inversion

## Metadata

- Level: **L3**
- Track: **B**
- Topic: categorization-scoring-inversion
- Recorded: 2026-08-25T08:22:29Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Design doc's first scoring scheme ranked app-only rules (base 300) above scoped-title rules (base 200), which would have classified YouTube-in-Chrome as Browsing and defeated the refinement mechanism the design exists for. Replaced fixed bases with score = 100 x conditions matched + 50 exactness bonus + longest needle length; caught during review before any code was written.

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
