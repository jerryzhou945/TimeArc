# 20260729-0138-B-macos-sidebar-double-click-zoom

## Goal

Support macOS double-click zoom from the same non-interactive sidebar regions
that already provide native window dragging.

## Plan

- [x] Add double-click maximize/restore without intercepting sidebar controls.
- [x] Build, test, and document the macOS interaction.

## Design

- Service side: no service output or disk contract is involved.
- UI side: a background-level tap handler toggles the owning QQuickWindow
  between maximized and normal states on a macOS double-click; existing child
  controls retain pointer priority.

## Scope

- Expected: `qml/desktop/DesktopAppShell.qml`, `README.md`.
- Hands off: native traffic lights, service code, data contracts, other
  platforms, frozen files, and rules.
- Rules needing updates: none.

## Manual smoke path

Launch on macOS, double-click empty sidebar space or the decorative brand area,
confirm the window zooms, double-click again to restore, then confirm sidebar
controls still click normally and dragging still moves the window.

## Outcome

The macOS sidebar background now combines a thresholded native drag handler
with double-click maximize/restore. Fullscreen is left unchanged, and later
sidebar controls retain pointer priority. The Debug build and both CTest smoke
tests pass; live GUI verification was not repeated after the earlier app-launch
approval was declined.
