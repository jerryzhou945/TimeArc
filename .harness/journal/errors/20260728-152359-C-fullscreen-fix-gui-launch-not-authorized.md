# Error Report - fullscreen-fix-gui-launch-not-authorized

## Metadata

- Level: **L3**
- Track: **C**
- Topic: fullscreen-fix-gui-launch-not-authorized
- Recorded: 2026-07-28T15:23:59Z
- Session: `../sessions/20260728-2305-C-macos-fullscreen-close-black-screen.md`
- Platform: macOS
- Tooling: desktop runtime smoke

## 1. What happened

Runtime verification could not launch the rebuilt GUI because desktop launch approval was declined

## 2. Evidence

The desktop-launch request for `open build/TimeArc.app` returned
`rejected by user`.

## 3. Root cause

- Immediate cause: GUI launch permission was declined.
- Underlying cause: sandboxed verification requires explicit desktop access.
- Why the harness/checklists did not prevent it: approval is intentionally a
  user-controlled boundary.

## 4. Fix

- Files changed: none.
- Short description: retained compile and focused static verification.
- Commit: not applicable

## 5. Prevention

One-off permission boundary; no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: none; approval was requested before launching.
- Earlier signal available: none.
- Rule file to update: none.
