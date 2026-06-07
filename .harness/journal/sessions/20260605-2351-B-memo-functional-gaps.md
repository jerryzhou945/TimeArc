# 20260605-2351-B-memo-functional-gaps

**Goal.** Implement the 7 remaining memo blackboard functional gaps (functional doc
§A #2/#3/#4/#6/#8/#9/#10). One commit per feature into the PR #18 branch
`feat/frameless-window-memo-ui`; update PR #18 body at the end.

**Track.** B (feature). UI-only, all in `qml/desktop/memorylake/`; persists via the
existing UI-private `memoryLakeMemoDoc` / a sibling key — no service/disk contract,
no new C++, no frozen files. Ultracode session: research fanned out via workflow.

## Per-feature plan (order: isolated → hardest)

- **#9 sticky author** — StickyNote has *no* author (v88's "JusTin D" never ported).
  Add an editable, persisted signature; round-trip via objectModel `osign` +
  `_snapshotObjects`/`_applyRecords` (`MemoOverlay`). Default empty.
- **#10 pomodoro persist** — `PomodoroWidget` state (`total`/`remain`/`title`) is
  in-memory. Add `store` + save/load a small JSON (sibling key, pomodoro is global
  not per-page); restore paused (no wall-clock anchor across restart).
- **#4 clear canvas** — `MemoInkCanvas.clearAll()` exists; add a UI entry (more-popover
  or tool sub-panel) + confirm → `MemoOverlay.clearCurrentCanvas()` (clear + `_histRecord` + save).
- **#3 pen/eraser width** — widths come from `style.memoPenWidth`/`memoEraserWidth`
  (4/28). Expose `penWidth` override on `MemoInkCanvas`; width selector UI (presets).
- **#2 pen color** — ink color = `style.memoInk` (#FFEC96). Expose `penColor` override;
  color palette UI (presets). #2/#3 likely share a pen sub-popover; persist choice.
- **#8 page thumbnails** — each page owns a canvas PNG dataURL (in `pagesData[i].canvas`).
  Pass per-page canvas to `MemoPageFolder`; render a small `Image` preview per row.
- **#6 page reorder** — drag a tray row to reorder. `movePage(from,to)` in `MemoOverlay`
  (reorder `pagesData`, fix `currentPage`, save) + drag UI in `MemoPageFolder`; must
  coexist with row click / rename / delete.

## Design inputs

Research workflow `memo-gaps-research` maps exact code surface + v88 design intent
(palette colors, width presets, thumbnail/reorder style, MemoryLakeStyle tokens).
Colors/easings from `MemoryLakeStyle` (no inline hex for new UI, rule 04 §8).

## Status — DONE (all 7 committed to PR #18 + verified on the running app)

#9 sig field renders + osign round-trips; #10 minutes 25→28 survive restart;
#4 trash → confirm dialog; #3 width popover (med selected); #2 6-color palette;
#8 row thumbnail of a drawn stroke; #6 drag grip → order [done,Page2]→[Page2,done].
Verify gotcha: synthetic keybd-Enter AND DragHandler-drag don't fire via injected
input — so the page-reorder grip uses MouseArea (not DragHandler), and persistence
features are verified by restart-reload. Docs §A #1–#10 marked done; #11–#14 remain.

## Verify

Per feature: kill exe → `build.py` → stderr clean (no QML err) → best-effort render /
persistence check (restart-reload for #9/#10; PrintWindow render for UI adds). Synthetic
input is flaky for deep interaction (documented) — lean on persistence + render proof.
`harness_check.py` before the batch is done. Update functional doc §A (mark resolved)
+ open-issues + README + memory at the end.
