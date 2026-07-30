# Error Report - macos-status-bar-path-assumption

## Metadata

- Level: **L3**
- Track: **C**
- Topic: macos-status-bar-path-assumption
- Recorded: 2026-07-28T15:06:12Z
- Session: `../sessions/20260728-2305-C-macos-fullscreen-close-black-screen.md`
- Platform: macOS
- Tooling: source inspection

## 1. What happened

Looked for macOS status-bar implementation under an incorrect filename/path during diagnosis

## 2. Evidence

Attempted to read `src/services/macos/macos_status_bar_icon.mm`; the actual
implementation is `src/services/macos/macos_status_bar_icon.cpp`.

## 3. Root cause

- Immediate cause: assumed the AppKit-adjacent implementation used Objective-C++.
- Underlying cause: did not list the directory before opening the file.
- Why the harness/checklists did not prevent it: this was a one-off inspection
  mistake rather than a product or harness gap.

## 4. Fix

- Files changed: none.
- Short description: listed `src/services/macos/` and opened the actual `.cpp`.
- Commit: not applicable

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: macOS status-item code must be Objective-C++.
- Earlier signal available: `rg --files src/services/macos`.
- Rule file to update: none; use file discovery before opening inferred paths.
