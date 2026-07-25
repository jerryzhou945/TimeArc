# Error Report - stale-resource-branding-license-paths

## Metadata

- Level: **L2**
- Track: **C**
- Topic: stale-resource-branding-license-paths
- Recorded: 2026-07-25T12:57:56Z
- Session: `20260725-2057-C-resource-path-followup.md`
- Platform: macOS
- Tooling: `rg`, CMake/Ninja, Qt qrc

## 1. What happened

Runtime and documentation references still target removed resources/app/branding/app_icon.svg and resources/legal after assets moved to resources/app/TimeArc.svg and resources/licenses

## 2. Evidence

`resources/CMakeLists.txt` correctly lists `resources/app/TimeArc.svg` and
`resources/licenses/*.txt`, but `rg` found runtime references in `src/main.cpp`,
QML, adapters, and the license UI still pointing at the removed paths.

## 3. Root cause

- Immediate cause: Consumers were not updated after the follow-up asset moves.
- Underlying cause: The qrc manifest and its consumers encode resource paths independently.
- Why the harness/checklists did not prevent it: No static check validates literal qrc paths against the resource manifest.

## 4. Fix

- Files changed: resource consumers in `src/` and `qml/`; packaging script;
  README, active docs, and harness rules/state.
- Short description: Repointed branding to `resources/app/TimeArc.svg` and
  licenses to `resources/licenses/`; confirmed the existing CMake manifest.
- Commit: pending

## 5. Prevention

Add a static harness pass that checks literal `qrc:/.../resources/` paths
against files registered by `resources/CMakeLists.txt`.
