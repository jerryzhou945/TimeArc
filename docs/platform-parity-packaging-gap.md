# TimeArc Windows/macOS Parity Before Packaging

Last updated: 2026-06-18

## Summary

The desktop UI is effectively shared across Windows and macOS because it is Qt/QML.
The real parity gap is the background service, platform permissions, and release
packaging. Windows is the current reference implementation. macOS has useful
Swift scaffolding for frontmost app/window identity, idle time, and media
assertion detection, but `TimeArcService.run()` still only keeps the process
alive and does not yet write usage records.

Bottom line: Windows can be packaged first as the real product path. macOS can
share the same UI package, but it should not be called parity until its helper
service writes the same disk records as Windows.

## Current Parity Snapshot

| Area | Windows | macOS | Gap |
| --- | --- | --- | --- |
| UI shell/pages | Shared Qt/QML | Shared Qt/QML | Low |
| Auto-start from UI | UI starts `time-arc-service.exe` on Windows only | Not wired in `src/main.cpp` | Medium |
| Foreground app tracking | Implemented polling loop with idle handling | App/window helpers exist, no tracker loop | High |
| Audio/media tracking | Implemented via Windows audio tracker | Media assertion detection scaffold exists | High |
| Storage writes | Writes SQLite/JSONL/current snapshot | No service write loop yet | High |
| Service lifecycle | Windows verbs: install/uninstall/start/stop/status/run-service | No LaunchAgent lifecycle yet | High |
| Single instance | Windows named mutex | Not implemented | Medium |
| Permissions | Mostly normal user-session APIs | Accessibility and possibly automation/media permissions | Medium |
| Packaging | Portable Windows packaging path exists but needs scripting polish | Needs `.app`/DMG/pkg, helper placement, signing/notarization | High |

## Evidence From Current Code

- `src/main.cpp::startUsageService()` starts `time-arc-service.exe` only under
  `Q_OS_WIN`.
- `src/service/windows/main.c` supports foreground tracking plus lifecycle verbs
  such as `--install`, `--start`, `--stop`, and `--status`.
- `src/service/windows/tracker/usage_tracker.c` owns the session loop, idle
  cutoff, current snapshot writes, and final flush behavior.
- `src/service/windows/tracker/audio_tracker.c` adds Windows audio/media usage
  records.
- `src/service/macos/TimeArcService.swift` currently keeps the process alive
  with `RunLoop.current.run()`.
- `src/service/macos/AppEnv.swift` already exposes useful primitives:
  frontmost app identity, focused window title, idle seconds, app icon path,
  and media assertion classification.

## macOS Work Needed To Match Windows

1. Implement the Swift tracker loop.
   Use `AppEnv.update()`, idle state, and frontmost app/title changes to create
   foreground sessions equivalent to Windows `usage_tracker.c`.

2. Wire storage through the shared disk contract.
   The macOS service must write the same SQLite/JSONL/current snapshot contract
   as Windows. Do not introduce IPC or platform-only schemas.

3. Add media session tracking.
   The current `getMediaType()` scaffold can identify likely media playback,
   but it still needs session start/update/flush behavior matching Windows audio
   records.

4. Add lifecycle and single-instance behavior.
   macOS needs a LaunchAgent-oriented start/stop/status story and a single
   running service guard comparable to the Windows mutex.

5. Wire UI launch/config.
   `src/main.cpp::startUsageService()` currently starts only the Windows helper.
   macOS needs the bundled helper path, permission-aware failure handling, and
   the same `usage_config.json` startup-read behavior.

6. Package, sign, and notarize.
   A macOS release needs an `.app` bundle layout, helper placement, `macdeployqt`
   or equivalent Qt deployment, codesigning, notarization, and permission
   onboarding copy.

## Packaging Readiness

Windows can move toward packaging first. The remaining work is mostly release
automation and compliance polish: repeatable deploy script, bundled license
texts/NOTICE, service helper inclusion, and smoke testing on a clean machine.

macOS should not be treated as packaging-ready yet. The UI can package, but the
core value of TimeArc depends on the background service. A macOS package before
the service loop would be a UI preview rather than a feature-parity release.

## Rough Catch-Up Estimate

Assuming one engineer who already knows this codebase:

| Target | Estimate | Notes |
| --- | --- | --- |
| macOS UI-only preview package | 2-4 days | App bundle + Qt deployment, limited product value |
| macOS MVP service parity | 2-3 weeks | Foreground tracking, idle, storage writes, UI launch |
| macOS useful beta parity | 4-6 weeks | Adds media sessions, LaunchAgent lifecycle, permissions UX |
| macOS release-grade parity | 6-8 weeks | Adds signing/notarization, clean-machine QA, packaging automation |

Fastest pragmatic route: ship a Windows alpha/beta package first, then run macOS
as a focused parity track. Trying to package both at the same time will slow the
Windows release without making macOS truly ready.

With two engineers, a useful macOS beta could probably compress to about 2-4
weeks if one person owns the Swift service loop/storage parity and the other
owns LaunchAgent, permissions, packaging, and clean-machine QA. Release-grade
parity still likely needs 4-6 weeks because signing, notarization, and permission
edge cases tend to expose issues only after repeated install/uninstall testing.

## Recommended Packaging Sequence

1. Windows package hardening.
   Script the current deploy process, include `time-arc-service.exe`, add
   license/NOTICE files, and test on a clean Windows machine.

2. macOS service MVP.
   Implement tracker loop plus disk writes before spending time on polished DMG
   branding.

3. macOS permissions and lifecycle.
   Add LaunchAgent install/start/stop/status and first-run permission guidance.

4. macOS signed beta.
   Only after service data appears correctly in the shared UI should packaging
   move to codesigning/notarization polish.
