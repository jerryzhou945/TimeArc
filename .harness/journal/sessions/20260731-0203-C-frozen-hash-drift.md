# Debug Session — frozen hash drift

## Metadata

- Author: Codex
- Track: **C (Debug)**
- Date: 2026-07-31 02:03 (local)
- Session goal: Preserve the approved Pomodoro build-file changes and reconcile their frozen-file hashes.
- Branch: `development/macos-support`
- Related error report(s): `../errors/20260730-180318-C-frozen-hash-drift.md`
- Active progress checklist: `../../checklists/before-coding.md`

## Goal

Resolve the two frozen-file hash mismatches without changing or reverting the
staged `CMakeLists.txt` and `src/CMakeLists.txt` feature work.

## What happened

Preflight reported only those two files as drifted. Their staged changes are
already covered by the earlier change proposal
`20260730-2358-B-pomodoro-cpp-wall-clock.md`, which names both frozen files and
documents motivation, process impact, migration, rollback, and verification.
This session therefore updates only the frozen-file registry to accept their
current contents.

## Outcome

Regenerated exactly two registry hashes. The full seven-pass
`harness_check.py` audit then completed cleanly.
