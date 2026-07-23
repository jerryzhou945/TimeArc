# Error Report - macos-tracking-probes-baseline

## Metadata

- Level: **L1**
- Track: **B**
- Topic: macos-tracking-probes-baseline
- Recorded: 2026-07-18T12:09:59Z
- Session: .harness/journal/sessions/20260718-2008-B-macos-tracking-probes.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
ninja: error: '/Users/jz2025/Desktop/Development/TimeArc/src/service/macos/WindowIdentifying.swift', needed by 'src/service/CMakeFiles/time_arc_service.dir/macos/TimeArcService.swift.o', missing and no known rule to make it
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
