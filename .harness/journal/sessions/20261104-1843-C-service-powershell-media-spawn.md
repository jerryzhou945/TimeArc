# Session Log — service-powershell-media-spawn

## Metadata

- Agent / Author: Claude Code (Opus 5.5) with Jerry Zhou
- Track: **C (Debug)**
- Date: 2026-11-04 18:43 → 19:05 (local)
- Branch: codex/fix-windows-audio-suspend
- Baseline commit: 40910e9
- Related error report(s): [`../errors/20261105-004444-C-service-powershell-media-spawn.md`](../errors/20261105-004444-C-service-powershell-media-spawn.md)

## Goal

Stop the Windows service from spawning powershell.exe for system media
metadata, and run the resident collector as a background-class process.

## Plan

- Measure child spawns and per-spawn cost of the installed service.
- Replace the `_popen` GSMTC query in `audio_win.c` with in-process WinRT
  calls (combase resolved at runtime; no CMake/link change, no frozen file).
- Enable EcoQoS + below-normal priority in `windows/main.c`.
- Build, ctest, probe native vs. PowerShell output, 2-minute live run.

## What actually happened

- 18:45 — Baseline: installed service spawned 40 `cmd.exe` children in 30 s
  with Chrome open; each `powershell.exe` run = ~550 ms CPU, ~665 ms wall,
  ~89 MB peak (≈0.7 core sustained).
- 18:47 — GSMTC IIDs + vtable order read from the system WinMD via
  PowerShell reflection (MinGW lacks `windows.media.control.h`).
- 18:49 — `build.py` clean, no warnings; ctest 6/6 pass.
- 18:50 — Scratch probe including `audio_win.c`: native query returns the
  same Chrome title as the retired script, Paused → NOT_PLAYING, 15–47 ms
  wall, 0.27 ms CPU per call.
- 18:52 — Swapped installed service for the build for 2 min: 0 cmd/powershell
  children, priority BelowNormal, ~1.4 s CPU/min own time, 19.9 MB WS. DB rows
  continuous across the swap (same titles, 60 s checkpoints). Installed
  service restored afterwards.

## Outcome

**done** (pending commit).

- Files touched: `src/service/windows/platform/audio_win.c`,
  `src/service/windows/main.c`.
- Frozen files touched: n.
- Follow-ups: remaining own CPU is WASAPI enumeration (~8 ms/call) and
  `CreateToolhelp32Snapshot` process sampling (~10 ms/call, up to 2×/s);
  next slice = event-driven foreground + less frequent snapshots.

## Completion report

- Completed: native GSMTC query replaces PowerShell; EcoQoS + below-normal
  priority; Chinese report `docs/windows-service-native-media-query-fix-2026-11-04.md`.
- Incomplete: None.
- Verification: build.py clean, ctest 6/6, harness_check clean, native-vs-script
  probe, 2-minute live service swap (0 shell children).
- Next: backlog B8 (event-driven foreground, fewer process snapshots).
- Risks: hand-declared WinRT vtables; slot order was read from system
  metadata and every used slot ran in the probe, but a future mismatch would
  crash the service rather than fail softly.

## Notes for the next agent

The title-only PowerShell fallback is gone: the native path leaves playback
status empty when `GetPlaybackInfo` fails, which is what that fallback did.
The installer still runs `powershell -ExecutionPolicy Bypass` (separate issue).
