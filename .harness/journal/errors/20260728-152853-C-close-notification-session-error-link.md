# Error Report - close-notification-session-error-link

## Metadata

- Level: **L3**
- Track: **C**
- Topic: close-notification-session-error-link
- Recorded: 2026-07-28T15:28:53Z
- Session: `../sessions/20260728-2327-C-macos-close-tray-notification.md`
- Platform: macOS
- Tooling: harness full audit

## 1. What happened

Harness track-discipline check did not recognize the new session's relative error-report link

## 2. Evidence

Pass 7 reported that the Track C session did not link any error report.

## 3. Root cause

- Immediate cause: the report appeared only in the narrative.
- Underlying cause: the session metadata omitted `Related error report(s):`.
- Why the harness/checklists did not prevent it: pass 7 correctly caught it.

## 4. Fix

- Files changed: current session log.
- Short description: added explicit related-error metadata.
- Commit: not applicable

## 5. Prevention

No harness change needed; the existing check worked.

## 6. Lessons for agents (L3)

- Wrong assumption: a narrative description was sufficient.
- Earlier signal available: recent Track C session metadata.
- Rule file to update: none.
