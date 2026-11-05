# Error Report - service-powershell-media-spawn

## Metadata

- Level: **L2**
- Track: **C**
- Topic: service-powershell-media-spawn
- Recorded: 2026-11-05T00:44:44Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Windows service spawns cmd+powershell.exe for GSMTC media metadata about 1.3 times per second while a browser holds an audio session (40 children in 30s); each spawn costs ~550ms CPU and ~89MB peak, about 0.7 core sustained, and the -ExecutionPolicy Bypass -EncodedCommand pattern is an antivirus heuristic trigger.

## 2. Evidence

Repro: installed service (pid 30436) with Chrome holding an audio session;
poll `Win32_Process` children every 150 ms for 30 s.

```
children seen in 30s: 40   (39 cmd.exe, 1 conhost.exe)
powershell GSMTC query x5: avg wall 664.6 ms, avg cpu 553 ms, peak WS 89 MB
```

## 3. Root cause

- Immediate cause: `query_gsmtc_media_info` ran `_popen("powershell.exe ...")`
  and `TIMEARC_GSMTC_PLAYBACK_CACHE_SEC` is 0, so every browser audio session
  re-spawned it each sampling second; a miss also ran the title-only fallback.
- Underlying cause: MinGW has no WinRT projection for Windows.Media.Control,
  so the API was reached through a PowerShell child instead of in-process.
- Why the harness did not prevent it: no resource budget for the resident
  service; child-process cost is invisible in the service's own CPU time.

## 4. Fix

- Files changed: `src/service/windows/platform/audio_win.c`,
  `src/service/windows/main.c`.
- Short description: call GSMTC through a minimal hand-declared WinRT ABI
  (combase.dll resolved at runtime, IIDs from system metadata), same match /
  merge / cache logic; enter EcoQoS + below-normal priority at tracker start.
- Verification: same title + state as the script; 0 shell children in 60 s;
  0.27 ms CPU per native query vs ~550 ms per spawn.
- Commit: pending commit.

## 5. Prevention

Rule: the resident service must not spawn helper processes on its sampling
path. Candidate harness upgrade: a smoke check that counts service child
processes over 30 s and fails on any non-conhost child.
