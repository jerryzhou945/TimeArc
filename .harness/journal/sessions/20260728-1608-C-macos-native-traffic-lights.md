# 20260728-1608-C-macos-native-traffic-lights

## Goal

Replace the simulated macOS traffic-light behavior with the owning
`NSWindow`'s standard controls over full-size sidebar content, with no visible
title-bar band.

## Plan

- [x] Configure the Qt macOS window as a full-size-content AppKit window and
  use only its native close, minimize, and fullscreen buttons.
- [x] Build, launch, inspect the result, and scan the Qt runtime log.

## Scope

- Expected: `qml/main.qml`, `src/services/macos/macos_traffic_lights.{h,mm}`.
- Hands off: service code, disk contract, schema, and additional CMake changes.
- Related error report: `errors/20260728-080933-C-macos-native-traffic-lights.md`.

## Outcome

AppKit now owns the traffic lights and their actions. The sidebar remains
full-height behind a transparent title region, with no visible title-bar band.
The root cause of the visible strip was Qt 6.9+'s automatic
`ApplicationWindow` safe-area padding, not the native view frame. The macOS
shell now overrides only that top padding. A post-load screenshot confirms the
sidebar reaches the top edge behind the three window-owned controls. The final
harness build and both CTest smoke tests passed; the required log scan completed
and rotated its external log. The desktop static test remains blocked by its
pre-existing missing Android manifest dependency.
