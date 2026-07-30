# Error Report - build-track-default

## Metadata

- Level: **L3**
- Track: **C**
- Topic: build-track-default
- Recorded: 2026-07-28T09:45:59Z
- Session: (unknown)
- Platform: macOS
- Tooling: `.harness/tools/build.py`

## 1. What happened

Invoked build.py without --track C, so its missing-build-directory failure was journaled under the default Track B

## 2. Evidence

```
build.py defaulted its failure journal entry to Track B because --track C was
omitted from the first invocation.
```

## 3. Root cause

- Immediate cause: `--track C` was omitted.
- Underlying cause: the build wrapper permits a default track.
- Why the harness/checklists did not prevent it: preflight does not propagate
  the current track into later build-wrapper invocations.

## 4. Fix

- Files changed: none
- Short description: All subsequent builds explicitly used `--track C`.
- Commit: not applicable

## 5. Prevention

One-off command error; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: the wrapper would infer the preflight-selected track.
- Earlier signal available: the wrapper usage accepts an explicit `--track`.
- Rule file to update: none; the existing build rule is sufficient.
