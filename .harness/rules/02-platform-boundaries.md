# Rule 02 - Platform Boundaries

Which code gets compiled on which OS, and what the per-platform implementation
has to provide.

## 1. Compile-gating

`src/service/CMakeLists.txt` selects exactly one platform source set:

- `APPLE` -> `macos/*.swift`
- `WIN32` -> `windows/{main.c, tracker/*.c, platform/*.c, storage/*.c, service/*.c}`
- `UNIX` (non-APPLE) -> `linux/main.c`

Headers in `src/service/shared/app_info.h` and `app_env.h` are included from
Win/Linux builds only. macOS Swift code uses the `data_bridge.h` C ABI via an
`-import-objc-header` bridging header.

## 2. What each platform owes the shared contract

Every platform service must:

1. Produce normalized sessions matching `usage_record.h` and the service tables.
2. Call `ta_storage_init()` before the first write and `ta_storage_shutdown()`
   on exit.
3. Split foreground sessions when either `app_id` or `window_title` changes.
4. Honor an idle threshold (default 60 s). While idle, close the foreground
   session.
5. Guarantee single-instance by some OS-appropriate mechanism.
6. Flush pending sessions on orderly shutdown.
7. Keep storage access behind the shared bridge unless a signed change proposal
   extends the disk contract.

## 3. Current state per platform

### Windows - reference implementation

- `main.c`: console handler + named mutex + tracker loop.
- `tracker/usage_tracker.c`: 1 s poll, idle check, same-app check, audio poll.
- `tracker/audio_tracker.c`: per-process audio sessions, 3 s silence grace,
  15 s long-run split.
- `platform/active_app_win.c`: `GetForegroundWindow` + `GetWindowText` + exe path.
- `platform/audio_win.c`: WASAPI `IAudioMeterInformation` peak read.
- `platform/idle_win.c`: `GetLastInputInfo`.
- `storage/usage_storage.c`: SQLite history writes.
- `service/win_service.c`: user-session autostart verbs
  (`--install`/`--uninstall`/`--start`/`--stop`/`--status`) via `schtasks`/Run-key.
  The tracker stays in the interactive user session. A true SCM Session-0
  service is deferred.

### macOS - foreground/config/media/lifecycle MVP, Mac smoke pending

- `AppEnv.swift`: frontmost app via `NSWorkspace`, idle via `CGEventSource`,
  media playback via `IOPMCopyAssertionsByProcess`.
- `WindowIdentifying.swift`: focused-window title via accessibility API.
- `AppInfo.swift`, `BinaryFloatingPoint+ToUInt.swift`: helpers.
- `TimeArcService.swift`: initializes shared storage, reads
  `~/Library/Application Support/TimeArc/usage/usage_config.json` for `idle_threshold_ms` and
  `track_enabled`, takes a per-user file lock, writes foreground sessions,
  writes media assertions as `source=audio`, clears current state on idle/exit,
  flushes pending sessions on `SIGTERM`/`SIGINT`, and provides
  `--install`/`--uninstall`/`--start`/`--stop`/`--status` verbs backed by a
  per-user LaunchAgent.
- `src/main.cpp::startUsageService()`: starts the macOS helper when found in a
  bundle-adjacent, install-prefix, or development-build location.
- Still pending: Mac-host compile/runtime smoke, Accessibility permission UX,
  final helper bundle layout, packaging, signing, and notarization.

### Linux - not started

- `src/service/linux/main.c` is empty (0 lines). Target both X11 and Wayland.
  Any new Linux dependency must be justified in `rules/06-licensing.md`.

## 4. Adding a new platform

Adding, say, FreeBSD or Android-host support:

1. Add `src/service/<name>/` with at minimum a `main.*` and whatever `platform/`
   probes are needed.
2. Extend `src/service/CMakeLists.txt` in the existing `if(APPLE)/elseif(WIN32)/
   elseif(UNIX)` chain.
3. Document the platform identifier and SQLite mapping in `usage_record.md`
   (data-contract change goes through rule 03).
4. Document in the main `README.md` project structure section.

## 5. Platform-specific conventions

- Windows paths in records: full exe path (e.g., `C:\...\chrome.exe`).
- macOS `app_id` in records: bundle id (e.g., `com.apple.Safari`).
- macOS paths in records: bundle path when available; UI icon providers must
  tolerate missing or permission-blocked bundle paths.
- Linux (when added): choose an identifier stable across launches, typically
  `.desktop` id or executable basename, and document it here.
