# Error Report - windows-media-activity-policy

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-media-activity-policy
- Recorded: 2026-08-24T16:30:03Z
- Session: (unknown)
- Platform: Windows 11
- Tooling: source audit + read-only service SQLite probe

## 1. What happened

Windows browser media observations require a WASAPI peak even when GSMTC says
the Bilibili video is playing, and Discord requires a peak even while its voice
session remains active, so both can lose valid silent intervals.

## 2. Evidence

```
Last two-hour live DB sample:
Chrome foreground active: 755 sec
Chrome media:              58 sec

audio_win.c session_is_audible() requires peak > 0.005 before querying
the already-available GSMTC media title.
```

## 3. Root cause

- Immediate cause: browser and Discord media inclusion is gated by instantaneous
  audio peak.
- Underlying cause: GSMTC playback status is not returned or used, and Discord
  has no narrow active-session policy.
- Why the harness/checklists did not prevent it: title and checkpoint tests do
  not cover a playing media session whose current audio peak is zero.

## 4. Fix

- Files changed: pending
- Short description: count Bilibili while matching GSMTC status is `Playing`;
  count an active effectively-unmuted Discord session without a peak; preserve
  NetEase/Codex and interval-union semantics.
- Commit: pending

## 5. Prevention

Add a native regression policy test; one-off, no harness rule change needed.
