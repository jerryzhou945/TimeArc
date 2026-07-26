# Error Report - macos-runtime-icon-override

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-runtime-icon-override
- Recorded: 2026-07-26T06:12:31Z
- Session: `20260726-1411-C-macos-runtime-icon.md`
- Platform: macOS
- Tooling: Qt 6, CMake/Ninja, `plutil`, `sips`, `iconutil`

## 1. What happened

QGuiApplication::setWindowIcon loads the qrc SVG on macOS and overrides the correctly configured TimeArc.icns bundle icon

## 2. Evidence

`build/TimeArc.app/Contents/Info.plist` contains
`CFBundleIconFile = TimeArc.icns`, and the matching bundle resource contains
all standard icon representations. However, `src/main.cpp` unconditionally
calls `QGuiApplication::setWindowIcon` with
`:/qt/qml/time_arc/resources/app/TimeArc.svg` immediately after constructing
the application.

## 3. Root cause

- Immediate cause: The unconditional `setWindowIcon` call replaces the native
  macOS bundle icon at runtime with the QRC SVG.
- Underlying cause: The cross-platform runtime icon assignment remained after
  native macOS bundle-icon packaging was added.
- Why the harness/checklists did not prevent it: Existing verification checked
  the bundle file and plist independently, but did not check for a conflicting
  runtime override.

## 4. Fix

- Files changed: `src/main.cpp` and related harness records.
- Short description: Skip the QRC SVG icon assignment on macOS so AppKit uses
  `TimeArc.icns`.
- Commit: pending commit

## 5. Prevention

One-off, no harness change needed. Verify the generated plist and bundled icon
when changing macOS application-icon wiring.
