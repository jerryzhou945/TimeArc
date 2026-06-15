# Error Report - ui-followup-build-failure

## Metadata

- Level: **L1**
- Track: **C**
- Topic: ui-followup-build-failure
- Recorded: 2026-06-15T05:30:19Z
- Session: `.harness/journal/sessions/20260615-1312-C-ui-stats-memorylake-language-followups.md`
- Platform: Windows / MinGW
- Tooling: `.harness/tools/build.py`

## 1. What happened

Harness build failed after UI follow-up commits; inspecting build log 20260615-132930-build.log.

## 2. Evidence

`ld.exe: cannot open output file TimeArc.exe: Permission denied`
while linking `build/TimeArc.exe`.

## 3. Root cause

- Immediate cause: an old `build/TimeArc.exe` process was still running.
- Underlying cause: Windows linker cannot overwrite an executing binary.
- Why the harness/checklists did not prevent it: pre-build process cleanup is
  manual today.

## 4. Fix

- Files changed: none.
- Short description: stopped the stale TimeArc process and reran harness build.
- Commit: n/a

## 5. Prevention

Potential harness upgrade: preflight/build could report a clearer active-binary
hint before linking on Windows.
