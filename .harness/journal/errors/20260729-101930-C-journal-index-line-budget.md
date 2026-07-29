# Error Report - journal-index-line-budget

## Metadata

- Level: **L3**
- Track: **C**
- Topic: journal-index-line-budget
- Recorded: 2026-07-29T10:19:30Z
- Session: `sessions/20260729-1818-C-macos-cmake-frozen-baseline.md`
- Platform: n/a
- Tooling: harness preflight

## 1. What happened

Mandatory error reports pushed the rolling journal index above its 100-line harness limit after the CMake hash mismatch was resolved

## 2. Evidence

`DRIFT: .harness/journal/INDEX.md: 105 lines (limit 100)`

## 3. Root cause

- Immediate cause: new mandatory error rows exceeded the rolling index limit.
- Underlying cause: old concrete rows had not yet been rolled into the
  existing omission marker.
- Why the harness/checklists did not prevent it: preflight correctly detected
  the overflow.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: retained all authoritative reports and JSONL rows while
  trimming the oldest index-only rows to exactly 100 lines.
- Commit: pending

## 5. Prevention

The rolling-index omission convention handled this as designed.

## 6. Lessons for agents (L3)

- Wrong assumption: the index still had room for the required reports.
- Earlier signal available: `wc -l .harness/journal/INDEX.md`.
- Rule file to update: none.
