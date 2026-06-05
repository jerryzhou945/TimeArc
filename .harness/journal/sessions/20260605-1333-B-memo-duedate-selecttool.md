# 20260605-1333 · Track B · memo due-date picker + select tool

Branch `feat/memory-lake-memo` (PR #14). Two requested features on the memo
overlay. UI-private QML only under `qml/desktop/memorylake/`; no service /
disk-contract / IPC. dev at `0e637ad`.

## Feature 2 — sticky due date/time (done)
Sticky's bottom date line becomes an **editable due date + 24h time** for
deadline todos (later consumed by the calendar rebuild + home 今日事项).

- New `MemoDatePicker.qml`: self-drawn mini calendar (month nav, Mon-first
  weekday row, 6x7 day grid) + 24h hour:minute steppers + 清除/确定. No
  `Qt.labs` module (avoids availability risk; fully themeable). Centered popup
  with scrim; click-outside dismisses. Order-independent init (open/initialMs).
- Sticky: `due` property + `dueEditRequested()`; date line shows
  "截止 yyyy-MM-dd HH:mm" or "＋ 设置截止时间", click opens picker.
- New model role `odue` (epoch ms, 0=unset) round-trips through save/load and
  undo snapshots. MemoOverlay mounts one picker singleton, writes odue + live
  obj on 确定/清除, schedules save + records undo.
- Registered MemoDatePicker in qml/CMakeLists.txt; rules/04 §8 updated.

## Feature 1 — transform / select tool (done)
New "选择" toolbar tool. Marquee on empty canvas selects ink region + stickies +
text (geometry intersect). Selection box with 复制/删除 + drag-to-move +
corner-scale. No whole-board zoom (chosen scope).

- Ink ops (MemoInkCanvas): clearRegion (delete); copyRegionTo / stampRegion via
  full-canvas toDataURL snapshot + drawImage(source-rect) — NOT getImageData
  (reads blank on the FBO canvas). drawImage source-rect composites source-over
  and scales, so copy + move + scale all reuse it.
- Move/scale: on gesture start, snapshot + clear the source region (ink "lifts"
  into a floating Image with sourceClipRect); objects + float follow live;
  on release, restamp ink at the final rect and write back object geometry.
- Keys: Ctrl+C copy, Del delete, Esc clears selection (then closes). Records one
  undo frame per op; switching tool clears the selection.
- Verified via probes: ink 1:1 + scaled copy, ink move (lift→clear→restamp),
  object multi-select + copy (sticky+text), object scale (×1.35).

## Feature 3 — top chrome as Dynamic Island (done)
Toolbar + page folder were always-on and blocked the top strip (sticky drag was
clamped to y>=84). Now:
- Top opened for dragging: sticky `drag.minimumY` + createSticky clamp 84 -> 8.
- Chrome auto-hides to a ~10px peek; a passive top `HoverHandler` zone
  (acceptedButtons-free, doesn't block draw/drag) reveals them on mouse-approach
  (`chromeShown`), staying open while the folder is expanded; hidden while a
  pen/select gesture is active so drawing at the top doesn't pop it.

## Select-tool fix (post-feedback)
Ink could vanish on drag (clear-before-float-load + cache:false eviction) and
copy dragged the original (overlapping +28 offset). Fixed: preload snapshot +
clear only when float Ready + synchronous restamp; copy placed fully beside
(non-overlapping). Objects were already identity-moved.

## Copy rework (post-feedback 2)
Three more copy bugs: (1) copies near the bottom/right edge went off-canvas and
were lost; (2) cross-page copy impossible (Ctrl+C did copy+paste atomically);
(3) menubar/animations froze after an ink copy.
- Clipboard: `_clip` holds objects (relative) + full-canvas ink snapshot + src
  rect, outliving page switches. **Ctrl+C = copy only**, **Ctrl+V = paste**
  (cross-page), **复制 button = copy+paste**. Selection cleared + focus kept on
  page switch.
- Paste origin tries right→down→left→up for an on-canvas, non-overlapping spot,
  clamps as last resort → bottom-right copies now land left/up, never lost.
- Freeze root cause: `toDataURL` on the **FBO** canvas is a slow GPU readback
  that stalls the GUI thread. Switched MemoInkCanvas to **Image render target**
  (CPU toDataURL, fast/reliable). getImageData/putImageData still unusable
  (Canvas commands flush only on next paint), so region copy stays on the
  full-snapshot + drawImage(source-rect) path.

## Post-feedback 3 (edge / page / focus / hover / window-ratio)
- Edge artifacts + "drag-to-edge then re-select corrupts": clamp selection rect
  to canvas in select/move/scale → no out-of-bounds drawImage.
- Ink vanishes after page switch, reappears on next copy: `loadFromDataURL` now
  draws synchronously when the URL is already cached (onImageLoaded won't refire).
- Menubar/animation freeze on refocus + after ink copy: ink Canvas
  renderStrategy Immediate -> **Threaded** (paint off GUI thread).
- Toolbar hover highlight stuck (Dynamic-Island moves button off cursor): gate
  toolbar hoverEnabled on `revealed` (= chromeShown).
- **Window-ratio breaks copy/ink**: ink canvas + object layer + dots are now a
  **fixed logical board (1920x1080) at top-left**; window resize just shows
  more/less of it (background/glows/chrome stay window-relative). Content coords
  no longer depend on window size, so the canvas never reallocates/stretches.

## Verify
`build.py` green; probes: date picker (right day/time), ink copy/move
(1:1 + scaled + lift-clear-restamp), object multi-select/copy/scale, copy
non-overlap, chrome auto-hidden peek. Hover-reveal + real mouse drag/marquee =
manual in-app QA.
