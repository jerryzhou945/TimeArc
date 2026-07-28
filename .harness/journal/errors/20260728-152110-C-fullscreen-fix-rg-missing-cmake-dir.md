# Error Report - fullscreen-fix-rg-missing-cmake-dir

## Metadata

- Level: **L3**
- Track: **C**
- Topic: fullscreen-fix-rg-missing-cmake-dir
- Recorded: 2026-07-28T15:21:10Z
- Session: `../sessions/20260728-2305-C-macos-fullscreen-close-black-screen.md`
- Platform: macOS
- Tooling: source discovery

## 1. What happened

A source-discovery search included a nonexistent cmake directory and exited with an rg path error

## 2. Evidence

`rg` reported: `cmake: No such file or directory`; this repository has CMake
files but no top-level `cmake/` directory.

## 3. Root cause

- Immediate cause: included an inferred `cmake/` path in the search.
- Underlying cause: did not discover matching directories first.
- Why the harness/checklists did not prevent it: one-off inspection mistake.

## 4. Fix

- Files changed: none.
- Short description: reran discovery against existing paths only.
- Commit: not applicable

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: a top-level `cmake/` directory existed.
- Earlier signal available: `rg --files` or `find` before the search.
- Rule file to update: none.
