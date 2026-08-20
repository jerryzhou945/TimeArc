# Error Report - windows-codex-sibling-activity

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-codex-sibling-activity
- Recorded: 2026-08-20T15:24:19Z
- Session: (unknown)
- Platform: Windows 11
- Tooling: Win32 Toolhelp process snapshot, PowerShell CIM verification

## 1. What happened

Windows autonomous activity samples only the foreground PID subtree; Codex commands run under sibling codex.exe and can be misclassified idle

## 2. Evidence

```
Foreground application family observed on 2026-08-20:
8320 ChatGPT.exe
  7680 codex.exe
    32796 codex-code-mode-host.exe
    22128 pwsh.exe

The visible window is served by ChatGPT.exe, while command work is rooted at
the sibling codex.exe branch. usage_tracker.c passes only next_app.process_id
to timearc_win_process_activity_sample().
```

## 3. Root cause

- Immediate cause: autonomous counters covered only descendants of the foreground PID.
- Underlying cause: the original synthetic tests modeled a single rooted process tree and did not represent Electron UI/backend sibling branches; Release also removed all assertions through `NDEBUG`.
- Why the harness/checklists did not prevent it: the platform contract required meaningful process-tree work but had no multi-root desktop-app fixture or Release-assertion guard.

## 4. Fix

- Files changed: `process_activity_win.c/.h`, `usage_tracker.c`, `windows_foreground_state_test.c`.
- Short description: detect every `codex.exe` backend in the same official packaged ChatGPT process family, aggregate changing CPU/I/O without double counting, and keep Release test assertions active.
- Commit: pending commit.

## 5. Prevention

Regression test now models foreground ChatGPT plus multiple sibling Codex backends and runs assertions in Release.
