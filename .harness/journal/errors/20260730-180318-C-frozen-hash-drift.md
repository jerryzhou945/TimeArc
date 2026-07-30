# Error Report - frozen-hash-drift

## Metadata

- Level: **L3**
- Track: **C**
- Topic: frozen-hash-drift
- Recorded: 2026-07-30T18:03:18Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Preflight found hash mismatches in CMakeLists.txt and src/CMakeLists.txt; preserve the existing locked-file changes and reconcile the frozen-file manifest.

## 2. Evidence

```
[pass 2] frozen-file hashes
  DRIFT: CMakeLists.txt: hash mismatch
  DRIFT: src/CMakeLists.txt: hash mismatch
harness_check.py: 2 drift finding(s)
```

## 3. Root cause

- Immediate cause: The two approved frozen-file edits were staged before their
  hashes were regenerated.
- Underlying cause: The feature session intentionally deferred registry
  regeneration until the frozen-file changes had reached their final contents.
- Why the harness/checklists did not prevent it: The harness correctly caught
  the expected intermediate drift; the prior change proposal explicitly marks
  hash regeneration as the remaining sign-off step.

## 4. Fix

- Files changed: `.harness/state/frozen-files.json`
- Short description: Regenerate the registry for the already-approved current
  contents of `CMakeLists.txt` and `src/CMakeLists.txt`.
- Commit: pending commit

## 5. Prevention

One-off, no harness change needed; the existing audit detected the drift and
the existing feature proposal authorized the locked-file changes.

## 6. Lessons for agents (L3)

- Wrong assumption: None; this report captures an expected gated reconciliation.
- Earlier signal available: The unchecked hash-regeneration item in the feature
  proposal.
- Rule file to update: None; `.harness/AGENTS.md` §5 already defines the flow.
