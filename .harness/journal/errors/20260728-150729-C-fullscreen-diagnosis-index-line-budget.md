# Error Report - fullscreen-diagnosis-index-line-budget

## Metadata

- Level: **L3**
- Track: **C**
- Topic: fullscreen-diagnosis-index-line-budget
- Recorded: 2026-07-28T15:07:29Z
- Session: `../sessions/20260728-2305-C-macos-fullscreen-close-black-screen.md`
- Platform: macOS
- Tooling: harness fast check

## 1. What happened

Harness fast check found journal/INDEX.md at 102 lines after adding diagnosis records

## 2. Evidence

`harness_check.py --fast` reported:
`DRIFT: .harness/journal/INDEX.md: 102 lines (limit 100)`.

## 3. Root cause

- Immediate cause: two new reports pushed the rolling index over 100 lines.
- Underlying cause: redundant historical omission rows had not been compacted.
- Why the harness/checklists did not prevent it: the check correctly detected
  the drift immediately.

## 4. Fix

- Files changed: `.harness/journal/INDEX.md`
- Short description: removed redundant old omission rows while retaining the
  authoritative history in `errors.jsonl`.
- Commit: not applicable

## 5. Prevention

One-off rolling-index maintenance; no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: the index had enough remaining line budget.
- Earlier signal available: current line count before recording reports.
- Rule file to update: none; the existing line-budget check worked.
