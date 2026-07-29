# Error Report - macos-app-menu-localization

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-app-menu-localization
- Recorded: 2026-07-29T10:01:27Z
- Session: `sessions/20260729-1801-C-macos-app-menu-localization.md`
- Platform: macOS
- Tooling: Qt 6.11.1 Cocoa platform plugin

## 1. What happened

The native macOS TimeArc application menu stays English even when TimeArc's
in-app language is Chinese or Japanese.

## 2. Evidence

- `MacMenuBar.qml` gives Settings and Quit native roles, so Qt replaces their
  QML text while merging them into the application menu.
- Qt's Cocoa plugin translates the standard rows through the
  `MAC_APPLICATION_MENU` catalog.
- `src/main.cpp` installs no `QTranslator`.
- The packaged bundle contains no `.qm` files, and `tools/build-macos.sh`
  explicitly passes `NO_TRANSLATIONS`.

## 3. Root cause

- Immediate cause: Qt falls back to its English source strings because no Qt
  Base translator is installed.
- Underlying cause: TimeArc's QML `I18n.js` language state is separate from
  Qt's translation system, and packaging intentionally omitted Qt catalogs.
- Why the harness/checklists did not prevent it: the static menu test checks
  TimeArc's custom menu tables but not Qt's merged native application-menu
  strings or packaged translation catalogs.

## 4. Fix

- Files changed: `src/services/macos/macos_menu_localizer.{h,cpp}`,
  `src/CMakeLists.txt`, `src/main.cpp`, `qml/desktop/MacMenuBar.qml`,
  `tools/build-macos.sh`, `tests/macos_menu_bar_static_test.py`,
  `docs/macos-menu-bar-design.md`
- Short description: install and switch a macOS-only Qt translator from the
  existing `language_mode`, and deploy only the required Qt Base catalogs.
- Commit: pending

## 5. Prevention

Extend the macOS menu/package static checks to require the translator bridge
and the two deployed Qt Base locales.

Verification: harness build succeeded; the focused menu/status/full-screen
static tests passed; a clean deployment probe produced `qt_zh_CN.qm` and
`qt_ja.qm`, both containing translated `MAC_APPLICATION_MENU` rows.
