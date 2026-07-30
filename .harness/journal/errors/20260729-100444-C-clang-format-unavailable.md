# Error Report - clang-format-unavailable

## Metadata

- Level: **L3**
- Track: **C**
- Topic: clang-format-unavailable
- Recorded: 2026-07-29T10:04:44Z
- Session: `sessions/20260729-1801-C-macos-app-menu-localization.md`
- Platform: macOS
- Tooling: `clang-format`

## 1. What happened

The optional formatting-validation command could not run.

## 2. Evidence

`/opt/homebrew/bin/bash: clang-format: command not found`

## 3. Root cause

- Immediate cause: `clang-format` is not installed or on `PATH`.
- Underlying cause: the repository does not provision or require the formatter.
- Why the harness/checklists did not prevent it: the checklist requires a
  build, not a particular formatting executable.

## 4. Fix

- Files changed: none
- Short description: verified formatting through successful compilation and
  `git diff --check`.
- Commit: n/a

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: assumed `clang-format` was available without checking.
- Earlier signal available: `command -v clang-format` would have shown it was
  absent.
- Rule file to update: none; the formatter is optional.
