# Error Report - codex-media-under

## Metadata

- Level: **L2**
- Track: **C**
- Topic: codex-media-under
- Recorded: 2026-08-24T21:36:45Z
- Session: `journal/sessions/20260825-0537-C-agent-media-timing.md`
- Platform: windows
- Tooling: live SQLite inspection, process-tree/state tests, Windows build

## 1. What happened

Codex task runtime is undercounted when the UI loses foreground, and long Bilibili playback is split into generic Chrome after the site hint expires.

## 2. Evidence

Live SQLite totals showed both current and previous Codex package versions at
378 seconds of foreground duration (364 active), matching the visible six
minutes even though the two agent tasks ran for about ten minutes. Bilibili
media rows totaled about 615 seconds, but marker-free GSMTC titles were grouped
under Chrome after the 90-second site hint expired.

## 3. Root cause

- Immediate cause: Codex work sampling is driven only by the current foreground
  PID, and browser-site attribution forgets Bilibili after 90 seconds.
- Underlying cause: the service has no independent background agent lease, and
  GSMTC commonly exposes only the video title rather than the hosting site.
- Why the harness/checklists did not prevent it: existing tests cover Codex
  process-tree filtering and immediate Bilibili navigation, not foreground loss
  during a task or delayed media-session creation.

## 4. Fix

- Files changed: Windows audio/process samplers, usage tracker, focused tests.
- Short description: persist verified Codex worker activity through the existing
  `unknown` media type, discover sibling ChatGPT worker branches, extend the
  site hint to 10 minutes, and add Oopz/KOOK voice-session policy.
- Commit: pending

## 5. Prevention

Regressions now cover delayed Bilibili navigation, sibling Codex workers,
background agent lease/checkpoint behavior, and silent voice sessions.
