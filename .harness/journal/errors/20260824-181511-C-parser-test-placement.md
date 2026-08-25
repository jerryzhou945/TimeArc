# Error Report - parser-test-placement

## Metadata

- Level: **L3**
- Track: **C**
- Topic: parser-test-placement
- Recorded: 2026-08-24T18:15:11Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Playback parser RED was invalid because the new test block landed before includes and enum declarations; moving it after audio_win.h, then rerunning for the intended undefined-reference failure.

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
