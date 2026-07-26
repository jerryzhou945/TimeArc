# Error Report - macos-icon-frozen-hash-drift

## Metadata

- Level: **L1**
- Track: **B**
- Topic: macos-icon-frozen-hash-drift
- Recorded: 2026-07-25T13:07:13Z
- Session: `20260725-2104-B-macos-bundle-icon.md`
- Platform: macOS
- Tooling: `harness_check.py`

## 1. What happened

Post-change harness audit found the approved CMakeLists.txt frozen hash change and the rolling journal index at 101 lines

## 2. Evidence

The audit reported `CMakeLists.txt: hash mismatch` and
`.harness/journal/INDEX.md: 101 lines (limit 100)`.

## 3. Root cause

- Immediate cause: An approved frozen-file edit changed its hash and a new error row exceeded the rolling index.
- Underlying cause: Frozen hashes require explicit bootstrap; the recorder does not roll the index automatically.
- Why the harness/checklists did not prevent it: Both conditions are detected by the audit and require post-change maintenance.

## 4. Fix

- Files changed: `.harness/state/frozen-files.json`, `.harness/journal/INDEX.md`
- Short description: Bootstrapped the one approved hash and omitted two oldest index rows without deleting reports.
- Commit: pending

## 5. Prevention

Teach `record_error.py` to enforce the rolling index limit automatically.
