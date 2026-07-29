# 20260729-0138-B-macos-sidebar-double-click-zoom

## Goal

Respect the macOS title-bar double-click preference from the same
non-interactive sidebar regions that already provide native window dragging.

## Plan

- [x] Route all four configured actions: minimize, zoom, fill, and no-op.
- [x] Build, test, and document the macOS interaction.

## Design

- Service side: no service output or disk contract is involved.
- UI side: a background-level tap handler calls the existing macOS AppKit
  controller, which reads `AppleActionOnDoubleClick` and invokes the owning
  window's minimize, zoom, or maximized action, or does nothing; existing child
  controls retain pointer priority.

## Scope

- Expected: `qml/desktop/DesktopAppShell.qml`, `README.md`,
  `src/services/macos/macos_traffic_lights.{h,mm}`,
  `tests/macos_sidebar_double_click_static_test.py`.
- Hands off: service code, data contracts, other platforms, frozen files, and
  rules.
- Rules needing updates: none.

## Manual smoke path

For each Desktop & Dock double-click preference, launch on macOS and
double-click empty sidebar space or the decorative brand area: Minimize sends
the window to the Dock, Zoom toggles its standard/user frame, Fill maximizes
the window, and Do Nothing leaves it unchanged. Confirm controls still click
and dragging still moves.

## Outcome

Sidebar double-click now enters the existing AppKit controller, reads
`AppleActionOnDoubleClick`, and performs native minimize, zoom, or Fill
maximization; `None` and other non-action values are ignored. A missing
preference falls back to the system-default zoom behavior. The Debug build,
targeted static regression, and both CTest smoke tests pass; live GUI
verification was not repeated after the earlier app-launch approval was
declined. Final harness validation is blocked only by an unrelated concurrent
committed `CMakeLists.txt` frozen-hash drift.
