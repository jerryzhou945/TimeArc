# macOS Status Bar Icon

## Change Proposal Metadata

- Author: `/root`
- Track: **B (Feature)**
- Date: 2026-07-28 03:20 (Asia/Shanghai)
- Branch: `development/macos-support`
- Related errors: `20260727-191343-B-build-failure.md`,
  `20260727-191353-B-macos-status-controller-moc.md`, and
  `20260727-191412-B-build-failure.md`

**Goal.** Replace the colorful macOS status-bar icon with a monochrome,
system-recolorable TimeArc “T” while retaining the existing app, Dock, window,
and non-macOS tray icons.

## Design

**Service side.** The background service continues to emit the same foreground
and media records; this presentation-only feature does not touch the two-process
disk contract, service lifecycle, or sampling behavior.

**UI side.** macOS uses a native status item with an in-memory 22×18 template
icon and explicit 1×/2×/3× representations so it matches the system input-source
item footprint. The QML tray keeps the original colorful SVG on other platforms.

Rules reviewed: `rules/01-architecture.md` and
`rules/02-platform-boundaries.md`; neither needs a claim update.

Expected files: `src/main.cpp`, `src/services/macos/macos_status_bar_icon.*`,
`src/CMakeLists.txt`,
`qml/desktop/memorylake/NotifierTray.qml`,
`tests/desktop_ux_static_test.py`, and `README.md`. Frozen CMake files, service
sources, and the data contract remain untouched except for the source-list
addition described below.

## Frozen-file change

`src/CMakeLists.txt` will add the new macOS-only UI integration source and
header to `TIME_ARC_APP_SOURCES` under an `APPLE` guard. Without this source-list
change, the implementation cannot leave `main.cpp` as requested.

| Side | Effect |
|------|--------|
| Producer | None; the background service and its target are unchanged. |
| Consumer | The GUI links the extracted macOS status-item implementation. |

There is no on-disk impact or migration. A code revert is sufficient rollback.
Verification will rebuild through the harness, run CTest and focused static
assertions, and audit frozen hashes. `rules/05-build-system.md` already describes
this source-list pattern, so no rule update is needed; the README update remains.

## Progress

- [x] Implement and verify the macOS template tray icon.
- [x] Document the smoke path and outcome.

## Outcome

The macOS status item now receives an in-memory masked `QIcon` rendered at
22×18 logical pixels with 1×/2×/3× pixmaps. Its menu, restore action, quit
action, and notifications remain connected; non-macOS QML still uses
`resources/app/TimeArc.svg`. No new SVG file was added.

The renderer and native status-item behavior live in
`src/services/macos/macos_status_bar_icon.*`; `main.cpp` only constructs the
integration, exposes its Qt object to QML, and attaches it to the root window.
The macOS entry point uses `QApplication` because the native status menu is
`QMenu`-backed; other platforms retain `QGuiApplication`.

Verification: the sanctioned build passed, as did both CTest smoke tests and
focused source assertions. The broad desktop static script remains blocked by
the repository's absent `android/src/main/AndroidManifest.xml`.
After switching the macOS entry point to `QApplication`, a launch smoke stayed
running through QML shell load instead of aborting during `QMenu` construction.

Manual smoke path: quit existing TimeArc instances, launch the rebuilt
`TimeArc.app`, confirm the rounded “T” occupies the same 22×18 footprint as the
system input-source item and recolors with the menu bar, then use the item to
restore and quit the app.
