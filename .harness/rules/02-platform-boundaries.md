# Rule 02 - Platform Boundaries

What compiles on each OS and what each platform implementation must provide.

## 1. Compile-gating

`src/service/CMakeLists.txt` selects exactly one platform source set:

- `APPLE` -> `macos/*.swift`
- `WIN32` -> `windows/{main.c, service_config.c, tracker/*.c, platform/*.c, service/*.c}`
- `UNIX` (non-APPLE) -> `linux/main.c`

Headers in `src/service/shared/app_info.h` and `app_env.h` are included from
Win/Linux builds only. macOS Swift code uses the `data_bridge.h` C ABI via an
`-import-objc-header` bridging header.

## 2. What each platform owes the shared contract

Every platform service must:

1. Produce app and session fields matching `data_bridge.h` and the service tables.
2. Submit completed app/session data through the shared `data_bridge.h` API.
3. Use complete normalized observations as logical session identity for both
   foreground and media tracking. If every captured field is equal, continue
   the same logical session; if any field differs, create a boundary.
4. Honor an idle threshold (default 60 s). Input-idle keeps the session open
   but pauses `active_sec`. Supported foreground-work evidence (video playback
   or meaningful process-tree CPU/I/O) may grant a bounded activity lease;
   process existence alone is never evidence.
5. End media as soon as it is absent from a sample; there is no silence grace.
6. Periodic media persistence checkpoints are optional. Implementations may
   write long-running media incrementally or only at a later boundary; a
   checkpoint does not change the logical session identity.
7. Guarantee single-instance by some OS-appropriate mechanism.
8. Flush pending sessions on orderly shutdown.
9. Keep storage access behind the shared bridge unless a signed change proposal
   extends the disk contract.

## 3. Current state per platform

### Windows - reference implementation

- `main.c`: console handler + named mutex + tracker loop.
- `tracker/usage_tracker.c`: orchestrates app, idle, work, and audio samples.
- `tracker/foreground_state.c`: Win32/SQLite-free lease and session transitions.
- `tracker/audio_tracker.c`: per-process audio sessions; its current timing
  behavior is an implementation detail rather than the portable contract.
- `platform/{active_app_win,app_identity}.c`: app observation + stable identity.
- `platform/audio_win.c`: WASAPI `IAudioMeterInformation` peak read.
- `platform/{idle,process_activity}_win.c`: input idle + process-tree counters.
- `tracker/*.c`: submits completed sessions through `data_bridge.h`; shared
  `database_storage.*` owns SQLite history writes.
- `service/win_service.c`: user-session autostart verbs
  (`--install`/`--uninstall`/`--start`/`--stop`/`--status`) via `schtasks`/Run-key.
  The tracker stays in the interactive user session. A true SCM Session-0
  service is deferred.

### macOS - tracking + CLI skeleton, packaged smoke passing

- `Tracking/TrackingPorts.swift`: record value types, probe protocols, `TrackingError`.
- `Tracking/*Probe.swift`: frontmost app via `NSWorkspace`, titles via the
  accessibility API, idle via `CGEventSource`, playback via
  `IOPMCopyAssertionsByProcess`, audio processes via CoreAudio.
- `Tracking/{Frontmost,Media}StateMachine.swift`: pure session transitions, no OS
  or SQLite calls; `Tracking/DataBridge.swift` writes through `data_bridge.h`.
- `Tracking/TrackingCoordinator.swift`: samples probes, drives both state
  machines, and takes the sample time from its caller.
- `CommandLine/`: total argv parser, `ServiceCommand`, README exit-code table.
- `Runtime/RunCommand.swift`: 1 s poll loop, SIGINT/SIGTERM flush, run exit code.
- `TimeArcService.swift`: `@main` composition root that parses, dispatches, and
  exits. No arguments means `run`, which is how launchd starts the bundled agent.
- On launch, the GUI registers embedded `com.timearc.service.plist` through
  `SMAppService`; the helper ships at `.app/Contents/MacOS/time-arc-service`.
- Still pending: the other seven CLI verbs, the config read, the instance lock,
  Accessibility UX, Developer ID signing, and notarization.

### Linux - not started

- `src/service/linux/main.c` is empty (0 lines). Target both X11 and Wayland.
  Any new Linux dependency must be justified in `rules/06-licensing.md`.

## 4. Adding a new platform

Adding, say, FreeBSD or Android-host support:

1. Add `src/service/<name>/` with at minimum a `main.*` and whatever `platform/`
   probes are needed.
2. Extend `src/service/CMakeLists.txt` in the existing `if(APPLE)/elseif(WIN32)/
   elseif(UNIX)` chain.
3. Document the platform identifier and SQLite mapping in
   `rules/03-data-contract.md`.
4. Document in the main `README.md` project structure section.

## 5. Platform-specific conventions

- Windows paths in records: full exe path (e.g., `C:\...\chrome.exe`).
- macOS `app_id` in records: bundle id (e.g., `com.apple.Safari`).
- macOS paths: bundle path when available; icon providers tolerate missing paths.
- Linux (when added): choose an identifier stable across launches, typically
  `.desktop` id or executable basename, and document it here.
