# verify-ignored-known-launch-memory

- Timestamp: 2026-06-03T17:25:32Z
- Level: L3
- Track: B
- Platform: n-a

## Summary

Visual-verify: forgot to recall existing [timearc-ui-build-verify] memory; spent ~10 cycles rediscovering that build/TimeArc.exe needs Qt bin (C:/Qt/6.11.1/mingw_64/bin) on PATH (else exits 0xC0000135 STATUS_DLL_NOT_FOUND, looks like an app/QML crash), and used focus-stealing SetForegroundWindow+CopyFromScreen instead of the memory's non-intrusive PrintWindow(flag2). Lesson: check the verify memory BEFORE launching for screenshots.

## Notes

Backfilled from `.harness/journal/errors.jsonl` because the D drive checkout referenced this report but the markdown file was absent.
