# Error Report - macos-icon-cmake-premise

## Metadata

- Level: **L3**
- Track: **C**
- Topic: macos-icon-cmake-premise
- Recorded: 2026-07-26T06:12:31Z
- Session: `20260726-1411-C-macos-runtime-icon.md`
- Platform: macOS
- Tooling: Qt 6, CMake/Ninja, `plutil`, `sips`, `iconutil`

## 1. What happened

Initially assumed the top-level CMake icon wiring was missing before inspecting the current committed bundle metadata; CMake and Info.plist were already correct

## 2. Evidence

Current `CMakeLists.txt` already sets
`MACOSX_PACKAGE_LOCATION "Resources"` and
`MACOSX_BUNDLE_ICON_FILE "TimeArc.icns"`. The generated `Info.plist` contains
that value, the file exists in `Contents/Resources`, and `iconutil` extracts
the full standard representation set.

## 3. Root cause

- Immediate cause: I carried forward a stale assumption before inspecting the
  current committed CMake and generated bundle.
- Underlying cause: The diagnosis began from the symptom ("bundled but not
  default") instead of first separating bundle metadata from runtime icon
  assignment.
- Why the harness/checklists did not prevent it: This was caught during the
  required pre-change inspection; no incorrect CMake edit was made.

## 4. Fix

- Files changed: This error report and the session record only.
- Short description: Verified the existing bundle wiring before editing and
  narrowed the actual fix to the runtime source.
- Commit: pending commit

## 5. Prevention

One-off, no harness change needed. Always inspect the generated bundle metadata
and current HEAD before proposing a frozen CMake edit.

## 6. Lessons for agents (L3)

- Wrong assumption: The `.icns` was merely copied and not connected to the
  bundle's icon metadata.
- Earlier signal available: The current `CMakeLists.txt`, generated
  `Info.plist`, and existing `Contents/Resources/TimeArc.icns`.
- Rule file to update: None; the existing frozen-file gate caused the necessary
  inspection before any edit.
