# Change Proposal — AppKit traffic lights

## Metadata

- Author: Codex `/root`
- Track: **B (Feature)**
- Date: 2026-07-28 15:18 (Asia/Shanghai)
- Session goal: Replace the macOS QML traffic-light approximation with AppKit standard window buttons while keeping the window frameless.
- Branch: `development/macos-support` (`.git` is read-only)
- Related error reports: `errors/20260728-065636-B-macos-sidebar-titlebar-misread.md`

## 1. Frozen files touched

- `src/CMakeLists.txt` — compile a macOS-only Objective-C++ traffic-light host.

## 2. Motivation

The frameless/sidebar geometry is correct, but the QML circles in the supplied
screenshot do not receive AppKit's native rendering, hover glyphs, inactive
state, or accessibility behavior. AppKit standard buttons must be hosted over
the frameless Qt content view without restoring a title bar.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | None; service sources, launch, sampling, and storage are unchanged. |
| Consumer | macOS GUI overlays AppKit standard buttons on the sidebar. |

## 4. Migration plan

No on-disk impact.

## 5. Rollback plan

Revert the AppKit host and restore `MacTrafficLights.qml`; no data restoration.

## 6. Test plan

- Pre-change reproduction: QML circles appear without native hover glyphs.
- Post-change verification: AppKit buttons render at the same sidebar location and close/minimize/fullscreen work without a title bar.
- New test artifacts: macOS build, launch, QML log scan, and user screenshot check.

## 7. Sign-off

- [x] `rules/*.md` update (none required; existing macOS UI isolation applies).
- [ ] `CHARTER.md` version bump (not applicable).
- [x] `state/frozen-files.json` refreshed for the approved source-list change.
- [x] Main `README.md` update.

## Completion facts

- Completed: AppKit standard-button host and QML approximation removal.
- Incomplete: External Qt log rotation (approval not granted).
- Verification: Full build passed; flipped-coordinate top-left fix launched.
- Next: User visual confirmation of native hover/inactive states.
- Risks: Multi-display alignment still needs manual smoke coverage.
