# Error Report - fullscreen-fix-index-trim-context

## Metadata

- Level: **L3**
- Track: **C**
- Topic: fullscreen-fix-index-trim-context
- Recorded: 2026-07-28T15:25:00Z
- Session: `../sessions/20260728-2305-C-macos-fullscreen-close-black-screen.md`
- Platform: macOS
- Tooling: patch application

## 1. What happened

Rolling-index trim patch used stale adjacent omission-row context and did not apply

## 2. Evidence

The patch could not find the expected adjacent omission rows in
`.harness/journal/INDEX.md`; no part of that attempt was applied.

## 3. Root cause

- Immediate cause: the trim hunk used stale neighboring lines.
- Underlying cause: the rolling index had changed after another report.
- Why the harness/checklists did not prevent it: one-off patch context error.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: reapplied the trim with current, narrower context.
- Commit: not applicable

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: the old omission rows were still adjacent.
- Earlier signal available: reread the rolling index after recording errors.
- Rule file to update: none.
