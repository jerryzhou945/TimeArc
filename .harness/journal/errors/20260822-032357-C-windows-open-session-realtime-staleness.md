# Error Report - windows-open-session-realtime-staleness

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-open-session-realtime-staleness
- Recorded: 2026-08-22T03:23:57Z
- Session: (unknown)
- Platform: Windows 11
- Tooling: service source audit + read-only SQLite probe

## 1. What happened

Windows Bilibili playback and Codex autonomous work accrue in open tracker sessions but statistics barely grow because long-running foreground/media sessions are not checkpointed to SQLite.

## 2. Evidence

```
2026-08-22 local service DB, while ChatGPT/Codex remained open:
latest ChatGPT row: start=1787366611 end=1787366626 active=14s
probe time:          1787369205 (about 43 minutes later)

Last 24h Chrome media attribution:
Bilibili-marked media titles: 195s
other Chrome media titles:    403s

The open Windows loop calls foreground close only on identity change/shutdown,
and audio close only on disappearance/shutdown; neither has a max-session checkpoint.
```

## 3. Root cause

- Immediate cause: open foreground and audio sessions are invisible to the read-only UI until a later identity/absence/shutdown boundary writes them.
- Underlying cause: Windows reads only enabled/idle configuration and never implements the macOS `max_session_sec` checkpoint pattern. Browser audio also prefers GSMTC titles before the matching foreground browser title, so some Bilibili playback is grouped under generic Chrome.
- Why the harness/checklists did not prevent it: checkpointing is optional in the portable contract, and the existing Windows static audio test explicitly preserved the deferred-write implementation rather than asserting freshness.

## 4. Fix

- Files changed: `foreground_state.*`, `audio_tracker.*`, `usage_tracker.*`, `audio_win.*`, `CMakeLists.txt`, and focused Windows tracker tests.
- Short description: checkpoint unchanged foreground/audio sessions every 60 seconds; preserve foreground mode/lease and contiguous boundaries; prefer matching browser foreground titles over marker-poor GSMTC titles while native media apps retain GSMTC titles. Discord detection is unchanged.
- Commit: pending

## 5. Prevention

Added real C regression coverage for contiguous foreground/audio checkpoints and browser foreground-title attribution; one-off, no harness rule change needed. Runtime evidence: row 8976 was written exactly `[1787370138, 1787370198]` with `duration_sec=60`, `active_sec=54` while the same Apex foreground identity remained open.
