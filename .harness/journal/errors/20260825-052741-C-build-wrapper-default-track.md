# Error Report - build-wrapper-default-track

## Metadata

- Level: **L3**
- Track: **C**
- Topic: build-wrapper-default-track
- Recorded: 2026-08-25T05:27:41Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: `.harness/tools/build.py`

## 1. What happened

The first wrapped build omitted --track C, so build.py auto-filed its failure under default Track B

## 2. Evidence

```
build.py defaults --track to B when the option is omitted.
```

## 3. Root cause

- Immediate cause: the initial invocation omitted `--track C`.
- Underlying cause: the wrapper does not infer `state/current-track` and defaults to B.
- Why the harness/checklists did not prevent it: the command contract allows an explicit track but does not require it.

## 4. Fix

- Files changed: journal only
- Short description: all subsequent builds pass `--track C` and the active session path.
- Commit:

## 5. Prevention

Potential harness improvement: infer the current track when `--track` is omitted.

## 6. Lessons for agents (L3)

- Wrong assumption: build.py would read the current-track state automatically.
- Earlier signal available: `build.py --help` and source show the default is B.
- Rule file to update: no project rule change; invocation fixed in this session.
