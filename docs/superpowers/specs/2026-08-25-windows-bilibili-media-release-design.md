# Windows Bilibili Media Release Design

## Goal

Make Bilibili playback use Windows media playback evidence instead of audio
peak alone, keep the already-working Discord, NetEase Cloud Music, and Codex
rules unchanged, and hide the desktop Memory Recap entry for the beta release.

## Confirmed scope

- Chrome remains a normal frontmost application for ordinary web browsing.
- Bilibili playback contributes an audio/media interval while GSMTC reports
  `Playing`, including silent or low-volume video segments.
- Paused, stopped, or missing Bilibili media ends the media observation on the
  next successful sample.
- Audible WASAPI peak remains the fallback when a usable GSMTC playback state
  is unavailable.
- Discord, NetEase Cloud Music, and the current foreground Codex autonomous
  CPU/I/O lease are not behaviorally changed.
- Foreground and media overlap continues to be merged as an interval union.
- The desktop bottom navigation and macOS application menu hide Memory Recap;
  the home dashboard, source files, and stored data remain intact.

## Design

The Windows GSMTC query will return playback status with source, title, and
artist. The audio sampler will normalize that result into a small pure policy:
a browser media observation is active when its matching GSMTC session is
`Playing`; otherwise the existing active, unmuted, nonzero-volume WASAPI peak
rule applies. Existing stable browser-title caching remains responsible for
keeping Bilibili identity through unrelated Chrome tab switches.

The policy stays in `audio_win.*` and does not change the service database or
the UI/service disk boundary. `audio_tracker.*`, checkpointing, adapters, and
aggregation remain unchanged unless a failing regression proves otherwise.

Memory Recap is release-gated in `DesktopAppShell.qml`: it is filtered from the
bottom navigation and direct `recap` navigation falls back to the home route.
`MacMenuBar.qml` hides the matching menu item. No page or user data is deleted.

## Failure handling

- GSMTC timeout, malformed output, or no matching Chrome session falls back to
  the existing WASAPI peak rule.
- A successful GSMTC sample reporting `Paused`, `Stopped`, or `Closed` cannot
  keep Bilibili alive without audible fallback evidence.
- A failed WASAPI enumeration preserves the tracker's existing behavior and
  does not synthesize new sessions.

## Verification

- Native policy tests first fail for: `Playing` plus zero peak counts;
  `Paused` plus zero peak does not count; unrelated silent Chrome does not
  count; current music/Discord policy remains unchanged.
- Existing browser-title, checkpoint, foreground-state, adapter, statistics,
  and desktop UX tests remain green.
- A real service smoke verifies Bilibili produces fresh media checkpoints and
  the desktop log contains no Qt/QML warnings.
- A read-only DB probe confirms Bilibili rows advance while the video is
  playing and stop after pause.

## Non-goals

- No generic background-video or browser-extension integration.
- No new Discord voice-channel detector.
- No background Codex accounting when another application is frontmost.
- No mobile UI change and no database migration.
