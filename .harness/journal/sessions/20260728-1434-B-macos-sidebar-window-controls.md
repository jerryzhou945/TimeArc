# 20260728-1434-B-macos-sidebar-window-controls

## Goal

Implement a macOS-only window-chrome redesign that embeds traffic-light
close/minimize/fullscreen controls in the left sidebar while preserving the
existing Windows frameless controls and all mobile behavior.

## Service side / UI side

**Service side.** No service, sampling, launch-agent, SQLite, configuration, or
disk-contract behavior changes. The native code is GUI-process-only and guarded
for macOS.

**UI side.** Use a genuinely frameless macOS window, host AppKit standard
traffic-light buttons directly over a borderless edge-to-edge sidebar, and keep
the existing drag/resize layer without its Windows caption buttons. Windows
continues using `WindowChrome.qml` unchanged.

## Plan / outcome

The final implementation uses a macOS-only Objective-C++ host to create AppKit
standard buttons without restoring a title bar. `DesktopAppShell.qml` owns the
edge-to-edge sidebar, while `WindowChrome.qml` retains drag/resize hit areas and
hides its Windows caption buttons on macOS. No service or disk contract changed.

- Completed: Frameless sidebar chrome with AppKit-native traffic-light controls.
- Incomplete: Manual click-through on additional macOS displays.
- Verification: AppKit build passes and the rebuilt app launches.
- Next: Final harness audit.
- Risks: External Qt log rotation was not approved during the final smoke.
