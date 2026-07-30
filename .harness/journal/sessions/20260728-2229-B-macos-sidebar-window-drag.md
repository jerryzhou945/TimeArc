# 20260728-2229-B-macos-sidebar-window-drag

## Goal

Enable native macOS window dragging from non-interactive sidebar regions
without changing sidebar controls or behavior on other platforms.

## Plan

- [x] Add a background-level macOS drag region behind sidebar controls.
- [x] Build, test, and verify that existing interactive regions stay above it.

## Design

- Service side: no service output or disk contract is involved.
- UI side: the sidebar background starts the owning window's native system
  move operation on a macOS left-button press; existing child MouseAreas retain
  priority.

## Scope

- Expected: `qml/desktop/DesktopAppShell.qml`, `README.md`.
- Hands off: service code, data contracts, native traffic lights, sidebar
  control geometry, other platforms, frozen files, and rules.
- Rules needing updates: none; this follows the existing QML and platform
  isolation conventions.

## Manual smoke path

Launch on macOS, drag from empty sidebar space or the decorative logo/title,
and confirm the window moves; click collapse/navigation controls and confirm
their actions still fire without moving the window.

## Outcome

The macOS sidebar now starts the owning QQuickWindow's native system move from
its background layer. Existing controls are later siblings and retain pointer
priority. The Debug build and both CTest smoke tests pass; live GUI verification
was not repeated after the earlier app-launch approval was declined.
