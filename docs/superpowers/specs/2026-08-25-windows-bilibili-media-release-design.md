# Windows Bilibili Media Release Design

## Goal

Make Bilibili playback use Windows media playback evidence, keep connected
Discord voice sessions alive without requiring speech, preserve the accepted
Codex/NetEase rules, and hide desktop Memory Recap for the beta release.

## Confirmed scope

- Chrome remains a normal frontmost application for ordinary web browsing.
- Bilibili playback contributes an audio/media interval while GSMTC reports
  `Playing`, including silent or low-volume video segments.
- Paused, stopped, or missing Bilibili media ends the media observation on the
  next successful sample.
- Audible WASAPI peak remains the fallback when a usable GSMTC playback state
  is unavailable; a known paused/stopped state is authoritative.
- Discord counts while its WASAPI session is active and effectively unmuted,
  even with zero peak; leaving voice makes the session inactive or absent and
  ends the interval. Other silent background apps do not receive this rule.
- NetEase Cloud Music keeps the existing audible-media behavior.
- Codex keeps the macOS-style rule: it must be frontmost, but meaningful
  CPU/I/O changes in the official packaged worker family renew activity while
  input is idle. Process presence alone never renews it.
- Foreground and media overlap continues to be merged as an interval union.
- The desktop bottom navigation and macOS application menu hide Memory Recap;
  the home dashboard, source files, and stored data remain intact.

## Design

The Windows GSMTC query will return playback status with source, title, and
artist. The audio sampler will normalize evidence through a small pure policy:
a browser media observation is active when its matching GSMTC session is
`Playing`; known non-playing states stop it; unavailable status falls back to
the existing active, unmuted, nonzero-volume WASAPI peak rule. Discord has a
narrow executable allowlist override that accepts an active, effectively
unmuted WASAPI session without requiring a peak. Existing stable browser-title
caching keeps Bilibili identity through unrelated Chrome tab switches.

The policy stays in `audio_win.*` and does not change the service database or
the UI/service disk boundary. `audio_tracker.*`, checkpointing, adapters, and
aggregation remain unchanged. Existing Codex code changes only if the current
packaged-process regression fails.

Memory Recap is release-gated in `DesktopAppShell.qml`: it is filtered from the
bottom navigation and direct `recap` navigation falls back to the home route.
`MacMenuBar.qml` hides the matching menu item. No page or user data is deleted.

## Failure handling

- GSMTC timeout, malformed output, or no matching Chrome session falls back to
  the existing WASAPI peak rule.
- A successful GSMTC sample reporting `Paused`, `Stopped`, or `Closed` ends the
  Bilibili observation; peak fallback is only for unavailable media status.
- A Discord session that is inactive, absent, muted, or effectively at zero
  output volume does not count.
- A failed WASAPI enumeration preserves the tracker's existing behavior and
  does not synthesize new sessions.

## Verification

- Native policy tests first fail for: `Playing` plus zero peak counts;
  `Paused` never counts; Discord active/silent counts; Discord inactive/muted
  stops; unrelated silent applications do not count.
- A current packaged Codex topology fixture includes `codex.exe`,
  `codex-code-mode-host.exe`, and a command runner and proves changing worker
  CPU/I/O renews the foreground lease while unchanged counters do not.
- Existing browser-title, checkpoint, foreground-state, adapter, statistics,
  and desktop UX tests remain green.
- A real service smoke verifies Bilibili produces fresh media checkpoints and
  the desktop log contains no Qt/QML warnings.
- A read-only DB probe confirms Bilibili rows advance while the video is
  playing and stop after pause.

## Non-goals

- No generic background-video or browser-extension integration.
- No Discord private API, IPC, or UI scraping; WASAPI session state is the
  connection proxy.
- No background Codex accounting when another application is frontmost.
- No mobile UI change and no database migration.
