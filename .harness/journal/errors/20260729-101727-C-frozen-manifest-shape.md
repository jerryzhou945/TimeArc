# Error Report - frozen-manifest-shape

## Metadata

- Level: **L3**
- Track: **C**
- Topic: frozen-manifest-shape
- Recorded: 2026-07-29T10:17:27Z
- Session: `sessions/20260729-1818-C-macos-cmake-frozen-baseline.md`
- Platform: n/a
- Tooling: Python JSON inspection

## 1. What happened

Assumed frozen-files.json stored a keyed object, but it stores its file records as a list; switched to direct manifest inspection

## 2. Evidence

`AttributeError: 'list' object has no attribute 'get'`

## 3. Root cause

- Immediate cause: treated the nested `files` array as a keyed object.
- Underlying cause: guessed the manifest shape before reading it.
- Why the harness/checklists did not prevent it: no schema assumption is
  prescribed; this was a local inspection mistake.

## 4. Fix

- Files changed: none
- Short description: read the manifest directly before the next query.
- Commit: n/a

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: `files` was a mapping by path.
- Earlier signal available: the manifest contents.
- Rule file to update: none.
