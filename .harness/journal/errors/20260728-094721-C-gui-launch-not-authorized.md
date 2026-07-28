# Error Report - gui-launch-not-authorized

## Metadata

- Level: **L3**
- Track: **C**
- Topic: gui-launch-not-authorized
- Recorded: 2026-07-28T09:47:21Z
- Session: (unknown)
- Platform: macOS
- Tooling: Launch Services

## 1. What happened

Visual verification could not launch the newly built app because the macOS open approval was declined

## 2. Evidence

```
The approval request for `open -n .../build-macos/TimeArc.app` was declined.
```

## 3. Root cause

- Immediate cause: launching the GUI app requires approval outside the sandbox,
  and that approval was declined.
- Underlying cause: visual runtime verification crosses the sandbox boundary.
- Why the harness/checklists did not prevent it: user approval is external to
  the repository checks.

## 4. Fix

- Files changed: none
- Short description: Did not retry the declined action; relied on successful
  build, tests, and deterministic layout geometry.
- Commit: not applicable

## 5. Prevention

One-off approval outcome; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: none; approval was correctly requested.
- Earlier signal available: GUI launch is an approval-gated action.
- Rule file to update: none.
