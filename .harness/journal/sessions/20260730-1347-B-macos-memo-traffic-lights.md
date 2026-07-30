# 20260730-1347-B-macos-memo-traffic-lights

## Goal

Keep the native macOS traffic lights visible and usable above the memo board
(备忘黑板) instead of hiding them while the modal overlay is open.

## Plan

- [x] Stop driving `MacTrafficLightsController.setVisible` from `memoOpen`.
- [x] Clear the button band inside the overlay (save-status pill inset).
- [x] Reconcile the ⌘W gate that assumed the red button was unreachable.
- [x] Flush the memo document before the window closes.
- [x] Static regression test, build, docs, comment corrections.

## Design

- Service side: no service output, sampling source, or disk contract is
  involved. The memo document stays UI-private key-value state.
- UI side: the AppKit buttons already live in the `NSWindow` title-bar view,
  which composites above the Qt content view, so no z-order work is needed —
  the overlay only has to stop asking the controller to hide them and has to
  keep its own top-left chrome out of the button band. The window-close path
  gains a memo flush because the red button is now reachable mid-stroke.

## Scope

- Touched: `qml/main.qml`, `qml/desktop/DesktopAppShell.qml`,
  `qml/desktop/MacMenuBar.qml`, `qml/desktop/memorylake/MemoOverlay.qml`,
  `tests/macos_memo_traffic_lights_static_test.py`,
  `.harness/rules/04-ui-conventions.md`,
  `docs/macos-memo-traffic-lights-report.md`. (Static tests are standalone here,
  not CTest-registered, so no `tests/CMakeLists.txt` change.)
- Hands off: service code, data contracts, other platforms, frozen files,
  `MemoToolbar`/`MemoPageFolder` layout, and the overlay's board coordinates.
- Rules needing updates: `rules/04-ui-conventions.md` §8 (the overlay is no
  longer "hides the traffic lights" chrome).

## Manual smoke path

Launch on macOS, open 备忘 (⌘⇧N): the three traffic lights stay drawn over the
blackboard, glyphs light on hover, and the save-status pill sits clear of them.
Click green → window zooms with the overlay still open; ⌘M minimizes and
restores; red closes the window and the memo document survives the reopen from
the Dock. Repeat with the window in fullscreen (lights follow the system
title-bar reveal) and at the 1280×720 minimum.

## Outcome

Completed: traffic lights stay visible over the memo overlay; the save-status
pill takes an 88 px macOS inset; ⌘W matches the now-clickable red button;
`MemoOverlay.flushPendingSave()` runs from `ApplicationWindow.onClosing` so a
window close cannot drop the 600 ms autosave debounce.

Incomplete: no drag/double-click affordance was added to the overlay's top
band — the canvas keeps priority there (see Risks).

Verification: `preflight.py --track B` clean, `cmake --build build` clean before
and after with no new warnings, `tests/macos_memo_traffic_lights_static_test.py`
passes, the other macOS static tests and both CTest smokes pass, and the app
launches with no new QML warnings (only the pre-existing window-geometry
`binding.removal` info lines and the unsigned-dev-build LaunchAgent error).
Pre-existing unrelated failures, both already reported:
`macos_build_script_static_test` (`20260729-100435`) and
`desktop_ux_static_test` (`20260729-103255`).
**Not verified: screenshots.** The agent shell has no Screen Recording or
Automation grant, so `screencapture -l` and `osascript` are refused by TCC and
the before-commit full-bleed 1280×720/maximized capture could not run — logged
as `20260730-060014-B-macos-gui-screenshot-tcc-blocked`. The manual smoke path
above still needs a human pass.

Next: human runs the manual smoke path; then decide whether the overlay should
mark the button band as a canvas no-go region.

Risks: content saved in the top-left of an existing memo (≈ logical 16–107 ×
5–37 board units) is now click-blocked by the buttons; the overlay's top band
still cannot drag or double-click-zoom the window even though visible traffic
lights imply a title bar.
