# Error Report - frozen-manifest-nesting

## Metadata

- Level: **L3**
- Track: **C**
- Topic: frozen-manifest-nesting
- Recorded: 2026-07-29T10:17:32Z
- Session: `sessions/20260729-1818-C-macos-cmake-frozen-baseline.md`
- Platform: n/a
- Tooling: Python JSON inspection, `jq`

## 1. What happened

After correcting the files list assumption, iterated the manifest's top-level object instead of its files member; switched to jq for the exact CMake entry

## 2. Evidence

`AttributeError: 'str' object has no attribute 'get'`

## 3. Root cause

- Immediate cause: iterated the top-level object instead of `.files`.
- Underlying cause: corrected only half of the first parsing assumption.
- Why the harness/checklists did not prevent it: this was an ad hoc diagnostic.

## 4. Fix

- Files changed: none
- Short description: queried `.files[]` directly with `jq`; hashes were then
  confirmed exactly.
- Commit: n/a

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: the manifest itself was the records array.
- Earlier signal available: the printed top-level `files` key.
- Rule file to update: none.
