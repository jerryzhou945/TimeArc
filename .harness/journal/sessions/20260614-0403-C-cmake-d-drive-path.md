# Session Log - cmake-d-drive-path

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-06-14 04:03 -> 04:10 (local)
- Branch: codex/app-icon-normal-centered
- Baseline commit: bafb2fc

## Goal

Restore harness builds after the toolchain moved from F: to D:, then summarize remaining backlog.

## Plan

- Reproduce CMake lookup failure and locate D-drive CMake candidates.
- Update PATH/cache to use the Qt D-drive toolchain and verify via harness build.
- Count implementation backlog items and report the alpha-test minimum.

## What actually happened

- 04:03 - Preflight passed on track C.
- 04:06 - Filed CMake PATH error: [`../errors/20260613-200641-C-cmake-not-in-path.md`](../errors/20260613-200641-C-cmake-not-in-path.md).
- 04:07 - Added `D:\TimeArc\QT\Tools\CMake_64\bin` to User PATH.
- 04:07 - Codex child shell did not reload User PATH; see [`../errors/20260613-200750-C-shell-path-not-reloaded.md`](../errors/20260613-200750-C-shell-path-not-reloaded.md).
- 04:08 - Reconfigured `build/` so `CMAKE_RC_COMPILER` points to D-drive `windres.exe`.
- 04:08 - Harness build passed with per-command PATH prefix.
- 04:08 - Backlog count script first used bash heredoc in PowerShell; see [`../errors/20260613-200855-C-powershell-python-heredoc.md`](../errors/20260613-200855-C-powershell-python-heredoc.md).
- 04:09 - Backlog count completed: 16 open, 2 partial, 13 done.

## Outcome

One of: **done**.

- Commits landed: none by user request.
- Files touched: harness journal files only; build cache changed under untracked/ignored `build/`.
- Frozen files touched: n
- Follow-ups spun out to `../state/open-issues.md`: none.

## Notes for the next agent

This Codex process may still need `$env:Path = 'D:\TimeArc\QT\Tools\CMake_64\bin;' + $env:Path`
inside build commands, but new user shells should inherit the User PATH update.
