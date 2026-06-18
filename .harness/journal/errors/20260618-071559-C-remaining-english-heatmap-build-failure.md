# Error Report - remaining-english-heatmap-build-failure

## Metadata

- Level: **L1**
- Track: **C**
- Topic: remaining-english-heatmap-build-failure
- Recorded: 2026-06-18T07:15:59Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

build.py failed after remaining English copy and heatmap changes; inspecting QML build log

## 2. Evidence

```
ld.exe: cannot open output file TimeArc.exe: Permission denied
Get-Process TimeArc -> PID 24696
```

## 3. Root cause

- Immediate cause: the linker could not overwrite `build/TimeArc.exe`.
- Underlying cause: a running TimeArc process (PID 24696) still held the
  executable.
- Why the harness/checklists did not prevent it: local GUI smoke sessions can
  leave the app running between turns.

## 4. Fix

- Files changed: none for this environment issue.
- Short description: stopped the running TimeArc process and reran build.
- Commit: pending.

## 5. Prevention

One-off local environment issue; consider teaching `build.py` to detect a
locked Windows executable and print the owning process.
