# 20260728-1739-C-macos-collapsed-logo-alignment

## Goal

Resize and reposition the complete macOS TimeArc sidebar logo so its left and
right edges align with the collapsed navigation controls below it, using the
same size in collapsed and expanded states.

## Plan

- [x] Uniformly scale the complete logo on macOS in both sidebar states.
- [x] Build and verify the resulting sidebar geometry and project tests.

## Scope

- Expected: `qml/desktop/DesktopAppShell.qml`.
- Hands off: native traffic lights, sidebar/navigation geometry, other
  platforms, service code, and disk contracts.
- Related error report:
  `errors/20260728-093936-C-macos-collapsed-logo-alignment.md`.

## Outcome

- The complete macOS logo now scales uniformly to 52-by-52, including the
  glyph and corner geometry.
- Collapsed and expanded macOS sidebars use the same logo size; non-macOS
  layouts retain the original 36-by-36 logo.
- Debug build and both CTest smoke tests passed. A live screenshot was not
  captured because approval to launch the app was declined earlier.
