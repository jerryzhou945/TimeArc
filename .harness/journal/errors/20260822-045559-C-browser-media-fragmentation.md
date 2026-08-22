# Error Report - browser-media-fragmentation

## Metadata

- Level: **L2**
- Track: **C**
- Topic: browser-media-fragmentation
- Recorded: 2026-08-22T04:55:59Z
- Session: `.harness/journal/sessions/20260822-1252-C-browser-media-fragmentation.md`
- Platform: Windows 11, Chrome media session
- Tooling: live service SQLite journal, source inspection, focused native tests

## 1. What happened

Live service DB shows continuous Chrome audio split into foreground-tab titles; Bilibili received only 3 seconds before unrelated Chrome pages received the ongoing audio time.

## 2. Evidence

```
2026-08-22 12:25:11-12:25:14  Chrome / Bilibili foreground title  3 sec
2026-08-22 12:25:14-12:25:23  Chrome / unrelated foreground title  9 sec

`timearc_win_preferred_observed_media_title()` currently returns
`matching_foreground_title` before `system_media_title` for every browser.
```

## 3. Root cause

- Immediate cause: the Windows audio sampler changes a browser media identity whenever the foreground Chrome tab changes.
- Underlying cause: the browser title policy unconditionally prefers the matching foreground window title over the stable Windows Global System Media Transport Controls title.
- Why the harness/checklists did not prevent it: the existing title-policy test encodes the foreground-first behavior and does not cover continuous playback while another browser tab becomes foreground.

## 4. Fix

- Files changed: `src/service/windows/platform/audio_win.c`, `src/service/windows/platform/audio_win.h`, `tests/windows_audio_title_policy_test.c`.
- Short description: key browser playback by its stable GSMTC title, enrich it once with a correlated foreground site title, and retain that identity through unrelated tab switches. Added site-retention, foreground-switch, and missing-system-title regression cases.
- Commit: pending

## 5. Prevention

Added a regression case proving that continuous browser playback keeps its Bilibili site identity and is not renamed by an unrelated foreground tab; one-off product test, no harness change.
