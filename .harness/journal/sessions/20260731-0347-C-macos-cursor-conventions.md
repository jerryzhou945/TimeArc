# Session — 20260731-0347-C-macos-cursor-conventions

- Track: **C (Debug)**
- Platform: macos
- Related error report(s):
  `journal/errors/20260730-195323-C-macos-cursor-conventions.md`

## Goal

Make macOS pointer shapes follow AppKit conventions. Windows and Linux behavior
must be byte-for-byte unchanged.

## Plan

One `.pragma library` in the existing helper idiom (`I18n.js`, `TagPalette.js`)
mapping four semantic tokens to per-platform shapes, then rewrite every call
site to the tokens. No C++ change — the repo has no `QCursor` code at all.

| token      | Windows / Linux (unchanged) | macOS       | why macOS differs |
|------------|-----------------------------|-------------|-------------------|
| `button`   | `PointingHandCursor`        | `Arrow`     | hand = hyperlink only |
| `disabled` | `ForbiddenCursor`           | `Arrow`     | `operationNotAllowed` = bad drop target |
| `grab`     | `SizeAllCursor`             | `OpenHand`  | SizeAll is a Qt PNG, not an NSCursor |
| `place`    | `DragCopyCursor`            | `Cross`     | the `+` badge belongs to a live drag |

## Changed

- **new** `qml/desktop/components/PlatformCursor.js` — the mapping + rationale.
- `qml/CMakeLists.txt` — register it (not a frozen file; top-level
  `CMakeLists.txt` untouched).
- 19 QML files under `qml/desktop/` — 90 shapes rewritten to tokens, one import
  line each.
- `.harness/rules/04-ui-conventions.md` §4 — new anti-pattern bullet. The file
  was already at the 100-line budget, so the bullet was paid for by tightening
  two lines **inside the same section**; no unrelated prose touched.

## Deliberately not changed

- `components/WindowChrome.qml` — frameless Windows/Linux chrome, gated off on
  macOS by `main.qml:212` (`visible: appWindow.frameless`); invisible items get
  no hover, so its cursors never run there.
- All `IBeam` / `Cross` / `SizeHor` / `SizeVer` / `SizeFDiag` / `SizeBDiag`
  sites — verified to map to real NSCursors, and object resize handles match
  Keynote/Preview.
- `TextLayer.qml:60` `acceptedModifiers: Qt.AltModifier`. On macOS ⌥-drag is
  the system *duplicate* gesture, so this reads wrong — but it is an input
  gesture, not a cursor, and plain drag is already owned by `TextArea` editing.
  Needs its own session and a product decision. Filed as follow-up below.

## Verification

1. `preflight.py --track C` — clean.
2. `build.py` — success (`journal/build-logs/20260731-035003-build.log`).
3. Resolved mapping on macOS via `qml -platform offscreen` against the real
   `PlatformCursor.js`: `button=Arrow disabled=Arrow grab=OpenHand place=Cross`.
4. All 19 import paths resolved to the real file; `PlatformCursor_js.cpp`
   present in `build/.rcc/qmlcache/…`, i.e. bundled exactly like `I18n_js`.
5. App launched (`build/TimeArc.app`): no QML warnings or errors. Only log line
   is the pre-existing unsigned-dev-build LaunchAgent codesigning warning.
6. `scan_qt_log.py` — note: it consumed a **stale backlog** (Jul 29–30 runs that
   had never been scanned) and filed 8 L2 reports for pre-existing LaunchAgent /
   menu-localizer warnings. None are from this change; the log contains zero QML
   messages from this session's run. This is a **recurrence** of
   `errors/20260728-070222-B-qt-log-scan-sandbox-repeat.md`; the tool still has
   no "only scan lines newer than the last run" guard. Not re-filed.
7. `harness_check.py` — clean. Two line-budget drifts surfaced en route and were
   fixed: `rules/04` (paid for inside §4, see above) and `journal/INDEX.md`
   (pushed to 101 by the 8 stale reports; oldest row dropped per the file's own
   "older rows may be omitted" policy — the row survives in `errors.jsonl`).

## Follow-ups (not this session)

- **Track B** — closed-hand on press for `grab` sites that have a `pressed`
  state (`StickyNote` header, `MemoOverlay` move box). Open→closed hand is the
  full macOS grab idiom; open-hand alone already fixes the non-native bitmap.
- **Track B** — decide what ⌥-drag should mean on macOS in `TextLayer`.
- macOS auto-hides the pointer while typing in a text field; Qt Quick does not.
  Cosmetic, needs a native hook. Not filed.
