# Error Report - zero-byte-timearc-exe

## Metadata

- Level: **L2**
- Track: **C**
- Topic: zero-byte-timearc-exe
- Recorded: 2026-06-14T09:42:55Z
- Session: (unknown)
- Platform: Windows desktop
- Tooling: `launch.cmd`, `.harness/tools/build.py`

## 1. What happened

Runtime launch failed because build/TimeArc.exe was zero bytes after prior relink/start attempt

## 2. Evidence

```
`launch.cmd` printed `Access is denied.`
`Get-ChildItem build\TimeArc.exe` showed length `0`.
```

## 3. Root cause

- Immediate cause: the previous clean-first build timed out before the final link completed, leaving `build\TimeArc.exe` as a zero-byte output.
- Underlying cause: the build command timeout interrupted a Windows relink after the output file had been recreated but before content was written.
- Why the harness/checklists did not prevent it: the timeout occurred outside build.py's normal failure handling, so a follow-up file-size check was needed.

## 4. Fix

- Files changed: none.
- Short description: reran `build.py -- --target time-arc` to complete the link; `TimeArc.exe` returned to normal size and launched.
- Commit: not applicable.

## 5. Prevention

One-off local build interruption; no harness change needed.
