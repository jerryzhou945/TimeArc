# 20260605-2116-C-memo-toolbar-hover-stick

**Observed bug (user).** 备忘黑板工具栏 (MemoToolbar): hovering a tool button no
longer shows a clean hover animation, and after clicking a button its hover
effect (lift + aqua wash) "burns in" — stays stamped on the button and doesn't
retract. Each clicked button accumulates a stuck effect.

**Track.** C (debug). Pre-existing bug in `qml/desktop/memorylake/MemoToolbar.qml`;
unrelated to the frameless-window work. UI-only, no service/disk contract touched.

## Root cause (the real one — confirmed by diff-testing)

The **top sensing zone** `topZone` (`MemoOverlay.qml` `Item{z:4500; HoverHandler}`,
full-width 78px, used to reveal the dynamic-island on top-approach) sits **in front
of** the toolbar/pageFolder. An item that accepts hover (a HoverHandler sets
`acceptHoverEvents=true`) **blocks item-level hover delivery to everything behind
it** (item hover is "front-most accepter only"; `HoverHandler.blocking` defaults
false but only governs handlers, not item hover). So the buttons' `MouseArea`
never received hover → **no highlight**; clicking only showed it because a *press*
forces `containsMouse=true`, which then **stuck** (no hover-leave delivered). This
matches the user's original "悬停没动效、按下才显且印住". A secondary fragility:
the per-button lift `transform` moved the `MouseArea` under the pointer.
(Tried `HoverHandler` on the buttons first — *also* blocked by `topZone`, worse:
no highlight at all. Reverted.)

## Fix

- `MemoOverlay.qml`: raise `toolbar.z=4520` + `pageFolder.z=4520` **above**
  `topZone` (4500) so their hover works; lift the overlapping popups higher
  (`pomodoro` 4540, `pomodoroComplete`/`duePicker` 4560). `chromeShown` now also
  keys on `toolbar.barHovered` (when the cursor is over the bar, `topZone` no
  longer gets hover, so the bar must keep itself revealed).
- `MemoToolbar.qml`: hover/click stay on `MouseArea` (proven to show the
  highlight); add `barHovered` (a `HoverHandler` on the pill). Lift/scale
  `transform` moved onto an inner `tvisual` Item so the `MouseArea` sensor stays
  put (kills the lift-induced stick). No frozen files.

## Verify — DONE (real app, PrintWindow + injected cursor, GetCursorPos-confirmed)

- Hover a non-active button → aqua wash + lift appears; move cursor off the pill
  (bar still revealed) → it clears, **no stuck highlight**.
- Click eraser → tool switches; after moving away only the active gradient
  remains (no stuck lift). Diagnostic: sidebar nav hover worked while toolbar
  didn't → pinpointed the covering-zone hover-block, not input injection.
No QML errors/warnings in stderr.

## Also added this session — page rename (feature, Track-B-ish)

User asked to add rename to memo pages. `MemoPageFolder.qml`: a ✎ button per
page row → inline `TextInput` (auto-focus + select-all); commit on Enter / focus
loss / clicking the cover·row·add (centralized `commitEdit()` + `_editText`,
since a `MouseArea` doesn't steal key focus); Esc cancels.
`MemoOverlay.renamePage(i,name)` updates the page label (empty/unchanged ignored)
and `scheduleSave()`. Verified: ✎ shows, edit field focuses, typing replaces,
and a renamed label **persisted across a fresh app restart** (loaded from the
saved `memoryLakeMemoDoc`). README "memo blackboard" bullet updated.
