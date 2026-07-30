# Track B — Disable GUI-owned service launch

## Goal

Make TimeArc UI startup independent from the background service lifecycle.

## Scope

- Service side: no service code or disk behavior changes; the executable remains
  built and packaged for external/manual lifecycle management.
- UI side: remove the detached service launch from `src/main.cpp` on every
  desktop platform.
- Rules/docs: update the UI/service ownership description and startup guidance.
- Keep untouched: frozen CMake files, service implementation, and disk contract.

## Progress

- [x] Remove the GUI startup launcher and add a regression check.
- [x] Build, test, and run the harness audit.

## Outcome

Removed detached service startup on Windows and macOS while retaining the
standalone service build/install target. Release compilation, both CTest smoke
tests, the focused startup-isolation check, and the full harness audit pass.
Follow-up session `20260727-1958` adds macOS launchd registration without
restoring direct helper execution.
