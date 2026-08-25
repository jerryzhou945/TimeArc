# Error Report - bilibili-browser-site-attribution

## Metadata

- Level: **L2**
- Track: **C**
- Topic: bilibili-browser-site-attribution
- Recorded: 2026-08-24T20:42:36Z
- Session: `journal/sessions/20260825-0537-C-agent-media-timing.md`
- Platform: Windows 11
- Tooling: live service SQLite inspection, Windows audio title-policy test

## 1. What happened

Windows recorded seven minutes of Bilibili playback as Chrome because the video and GSMTC titles omitted every Bilibili site marker after navigation.

## 2. Evidence

The live DB contained eight Chrome media checkpoints totaling 417 seconds.
Immediately beforehand the foreground title was
`哔哩哔哩 (゜-゜)つロ 干杯~-bilibili - Google Chrome`; after navigation both
foreground and GSMTC titles became `王中王夺冠自战解说 - Google Chrome`, so
`site:bilibili` matching lost every site hint while duration continued growing.

## 3. Root cause

- Immediate cause: site attribution requires a Bilibili marker in each sampled title.
- Underlying cause: Chrome removes the site suffix on some Bilibili video pages and
  GSMTC exposes only the media title, while the sampler forgets the explicit site
  identity observed seconds earlier on the Bilibili navigation page.
- Why the harness/checklists did not prevent it: existing tests cover a matching
  foreground/media title and later tab changes, but not navigation from an explicit
  site title to a marker-free media title.

## 4. Fix

- Files changed: `src/service/windows/platform/audio_win.{c,h}` and focused Windows tests.
- Short description: retain a 10-minute explicit browser-site hint and attach it to the
  stable media identity when the immediate video title has no site suffix.
- Commit: pending

## 5. Prevention

Added regressions for immediate and 150-second-delayed marker-free video titles.
