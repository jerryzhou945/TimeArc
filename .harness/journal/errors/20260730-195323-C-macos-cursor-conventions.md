# Error Report - macos-cursor-conventions

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-cursor-conventions
- Recorded: 2026-07-30T19:53:23Z
- Session: .harness/journal/sessions/20260731-0347-C-macos-cursor-conventions.md
- Platform: macos
- Tooling: qml / qt

## 1. What happened

Desktop QML sets pointer shapes with Windows/web conventions on every platform.
On macOS this reads as a ported app: 86 of 108 `cursorShape` assignments are
`Qt.PointingHandCursor`, which AppKit reserves for hyperlinks — native buttons,
switches, sliders, popup buttons, list rows and calendar cells keep the arrow.
Three further shapes are wrong in kind, not merely in taste.

## 2. Evidence

Inventory (`qml/`, desktop only; mobile has zero `cursorShape`):

```
108 cursorShape assignments
 86 Qt.PointingHandCursor  buttons, sidebar rows, calendar day cells, slider
                           track, switch, combo box + items, time steppers
  1 Qt.ForbiddenCursor     DesktopAppShell.qml:906 (disabled memo entry)
  3 Qt.SizeAllCursor       StickyNote.qml:98 TextLayer.qml:61 MemoOverlay.qml:962
  1 Qt.DragCopyCursor      MemoOverlay.qml:650 (note tool hover)
```

Cocoa mapping confirmed against the shipped Qt 6.11.1 plugin:

```
$ strings .../platforms/libqcocoa.dylib | grep -iE "Cursor|cursors/images"
:/qt-project.org/mac/cursors/images/sizeallcursor.png  <- SizeAll = Qt bitmap
operationNotAllowedCursor  dragCopyCursor  pointingHandCursor
openHandCursor  crosshairCursor  resizeUpDownCursor  resizeLeftRightCursor
_windowResizeNorthWestSouthEastCursor                  <- SizeF/BDiag are real
```

`Qt::SizeAllCursor` has no `NSCursor` equivalent, so Qt draws its own bundled
PNG: a Windows/X11 4-way arrow macOS never renders, and a fixed bitmap that
cannot follow the Accessibility pointer fill/outline colours.

## 3. Root cause

- Immediate cause: shape constants written inline at each call site with no
  platform branch, seeded by the Windows-first development of the desktop UI.
- Underlying cause: no cursor convention existed anywhere in the harness.
- Why the harness/checklists did not prevent it: `rules/04-ui-conventions.md`
  said nothing about cursors, so 20 files inherited the Windows idiom
  unchallenged.

## 4. Fix

- Files changed: new `qml/desktop/components/PlatformCursor.js`;
  `qml/CMakeLists.txt`; 19 QML files under `qml/desktop/`;
  `.harness/rules/04-ui-conventions.md` (new §9).
- Short description: one `.pragma library` maps four semantic tokens
  (`button` / `disabled` / `grab` / `place`) to per-platform shapes.
  Windows/Linux branches return the historical value verbatim; only the macOS
  branch changes. 90 call sites rewritten to the tokens.
  Untouched on purpose: `WindowChrome.qml:150` (frameless Windows/Linux chrome,
  gated off on macOS at `main.qml:212`) and every IBeam / Cross / SizeHor /
  SizeVer / SizeFDiag / SizeBDiag site — those already hit real NSCursors and
  match Keynote/Preview on resize handles.
- Commit: pending.

## 5. Prevention

`rules/04-ui-conventions.md` §9 now states the convention and forbids raw
`Qt.*Cursor` for the four remapped semantics under `qml/desktop/`, so the next
agent adding a button has a rule to follow instead of a blank slate.
