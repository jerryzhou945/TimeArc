# Rule 02 — Platform Boundaries

Which code gets compiled on which OS, and what the per-platform implementation
has to provide.

## 1. Compile-gating

`src/service/CMakeLists.txt` selects exactly one platform source set:

- `APPLE`          → `macos/*.swift`
- `WIN32`          → `windows/{main.c, tracker/*.c, platform/*.c, storage/*.c, service/*.c}`
- `UNIX` (non-APPLE) → `linux/main.c`

Headers in `src/service/shared/app_info.h` and `app_env.h` are included from
Win/Linux builds only. macOS Swift code uses the `data_bridge.h` C ABI via an
`-import-objc-header` bridging header.

## 2. What each platform owes the shared contract

Every platform service must:

1. Produce records that validate against `usage_record.schema.json`.
2. Call `ta_storage_init()` before the first write and `ta_storage_shutdown()`
   on exit.
3. Split sessions when **either** the `app_id` or the `window_title` changes.
4. Honor an idle threshold (default 60 s). While idle, close the foreground
   session and clear the live snapshot.
5. Guarantee single-instance by some OS-appropriate mechanism.
6. Flush pending sessions on orderly shutdown.

## 3. Current state per platform

### Windows — reference implementation

- `main.c`: console handler + named mutex + tracker loop.
- `tracker/usage_tracker.c`: 1 s poll, idle check, same-app check, audio poll.
- `tracker/audio_tracker.c`: per-process audio sessions, 3 s silence grace,
  15 s long-run split.
- `platform/active_app_win.c`: `GetForegroundWindow` + `GetWindowText` + exe path.
- `platform/audio_win.c`: WASAPI `IAudioMeterInformation` peak read.
- `platform/idle_win.c`: `GetLastInputInfo`.
- `storage/usage_storage.c`: JSONL append + atomic rename for live snapshot.
- `service/win_service.c`: **TODO** — SCM registration stubs only.

### macOS — sampling primitives done, loop idle

- `AppEnv.swift`: frontmost app via `NSWorkspace`, idle via `CGEventSource`,
  media playback via `IOPMCopyAssertionsByProcess`.
- `WindowIdentifying.swift`: focused-window title via accessibility API.
- `AppInfo.swift`, `BinaryFloatingPoint+ToUInt.swift`: helpers.
- `TimeArcService.swift`: **the loop is still `RunLoop.current.run()` — no
  sampling is performed.** Filling this in is the next macOS milestone. It
  must mirror `windows/tracker/usage_tracker.c`'s contract.

### Linux — not started

- `src/service/linux/main.c` is empty (0 lines). Target both X11 and Wayland.
  Any new Linux dependency must be justified in `rules/06-licensing.md`.

## 4. Adding a new platform

Adding, say, FreeBSD or Android-host support:

1. Add `src/service/<name>/` with at minimum a `main.*` and whatever `platform/`
   probes are needed.
2. Extend `src/service/CMakeLists.txt` in the existing `if(APPLE)/elseif(WIN32)/
   elseif(UNIX)` chain.
3. Add `<name>` to the enum in `usage_record.schema.json` (data-contract change
   — go through rule 03).
4. Document in the main `README.md` project structure section.

## 5. Platform-specific conventions

- Windows paths in records: full exe path (e.g., `C:\...\chrome.exe`).
- macOS `app_id` in records: bundle id (e.g., `com.apple.Safari`).
- Linux (when added): choose an identifier stable across launches — typically
  `.desktop` id or executable basename — and document it here.
