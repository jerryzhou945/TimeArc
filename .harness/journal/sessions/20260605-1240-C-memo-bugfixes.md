# 20260605-1240 · Track C · memo blackboard bug-fixes

Branch `feat/memory-lake-memo` (PR #14). Post-implementation QA fixes on the
memo overlay. dev confirmed at `0e637ad`. No service/disk-contract changes; all
edits are UI-private QML under `qml/desktop/memorylake/`.

## Items (one commit each)

1. **Object scale blow-up on fullscreen toggle.** Root cause: object delegate
   `Loader` had `anchors.fill: parent`; a sized Loader force-resizes its loaded
   item, so notes ballooned on window resize and text was overlay-sized on
   create. Fix: wrap each object in an overlay-filling shell `Item`; the Loader
   stretches the shell, the note/text keeps its own geometry. Connections/回写
   route through `Loader.obj` (= shell.inner).
2. **Sticky content: drop "JusTin D"; add date/time + done checkbox.** New model
   roles `ots` (epoch ms, set at create) + `odone`. Date/time line replaces the
   byline; checkbox top-left toggles done (title strikethrough + dim). Stored for
   later calendar/todo wiring. Still UI-private (no AI, no service).
3. **Text layer: same scale fix (via #1) + make resizable.** Added right/bottom/
   corner resize handles; height auto until first manual resize, then fixed and
   persisted (`oh>0`). Default create size 240×48.
4. **Pomodoro: allow 0 minutes + restyle the white inputs.** Min minute 0 (start
   still refuses total 0; start button dims at 0:00). The inputs were white
   because the app uses the native Windows Controls style, which silently
   ignores `SpinBox` background/contentItem/indicator customization. Rather than
   force a non-native style app-wide, replaced the two SpinBoxes with a custom
   `NumberField` (Rectangle + TextInput + +/- steppers) matching v88
   `.pomodoro-number` (bg rgba(255,255,255,.055), border rgba(142,223,255,.12),
   light text, r11/h36). NOTE: qml.exe probe also renders the native style.
5. **Ctrl+Z undo (+ Ctrl+Shift+Z redo).** Per-page snapshot history (objects +
   ink dataURL), guarded restore, capped at 40. Records after each committed
   mutation (create/delete/move/resize/edit/stroke); resets on open + page op.
   Field-focused Ctrl+Z still goes to the TextArea's own undo.

## Recorded errors
- [`errors/20260605-045113-C-memo-loader-autosize.md`](../errors/20260605-045113-C-memo-loader-autosize.md)
  — item 1 root cause (sized-Loader force-resize).

## Verify
`build.py` green per item; visual items (2,4) checked via qml.exe probe.
Manual in-app QA (draw/drag/resize/page/pomodoro) remains the user's pass.
