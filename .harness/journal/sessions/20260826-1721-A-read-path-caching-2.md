# Session Log — read-path-caching-2

## Metadata

- Agent / Author: Claude Code (Opus 5)
- Track: **A (Stabilize)**
- Date: 2026-08-26 17:21 → 17:38 (local)
- Branch: feature/ui-statistics
- Baseline commit: b7abaab (+ the two earlier sessions today)

## Goal

Cache the remaining items in `docs/desktop-read-path-caching-backlog.md` §2–§3.
Observable behavior unchanged.

## Plan — three sub-areas (track A entry rule)

1. `DesktopCalenderPage.qml` — memoize the four whole-blob `JSON.parse`s on the
   raw string; index chat images by date once. (§2.1, §2.2)
2. `ProjectManager` — per-day cache for `timeEntriesForDate`, invalidated by its
   own `projectsChanged`; drop the banned copy-out/copy-back accumulation. (§2.3)
3. `AppVisual.js` + `GridTexture`/`MemoDotTexture` — memoize the pure visual
   functions; draw one tile and let `Image.Tile` repeat it. (§3.1, §3.2)

Predicted diff ~300 lines (actual ~350 incl. the new test).

## What actually happened

- 17:26 — tiling textures built, but the app logged
  `RangeError: Maximum call stack size exceeded` from `GridTexture`:
  `toDataURL()` inside `onPainted` synchronously forces another paint, which
  re-emits `painted`. Fixed with an `exporting` re-entry guard on both textures.
- 17:28 — could not screenshot the window to check the textures: System Events
  automation is not authorized for this terminal (a permission only the user can
  grant), so `osascript` fronting silently failed. Verified a better way instead —
  rendered old and new implementations side by side under
  `QT_QPA_PLATFORM=offscreen qml` and compared the grabbed PNGs:
  **byte-identical hashes**, and a pixel decode proves they are not blank
  (grid 5104 drawn px = 7.25%, dots 468 px = 0.66%, same in both).
- 17:31 — **found while auditing the calendar cache**: two call sites *mutate* the
  parsed result in place — `saveTodosForSelectedDate` does `map[key] = arr`, and
  `addAnniversaryFromPopup` does `list.push(...)`. Harmless when every call
  re-parsed; with a cache they would corrupt it. Added `todosMapForEdit()` (shallow
  copy) and `.slice()` at those two sites.
- 17:33 — `timeEntriesForDate` had **zero** test coverage and this machine has no
  manual sessions, so the runtime probe could not exercise it. Added a focused case
  to `tests/db_smoke.cpp` (same-day merge + a write after a read). Proved the test
  can fail by disabling the invalidation: it reported
  "timeEntriesForDate served a stale cached day." Restored, 3/3 green.
- 17:36 — `AppVisual` equivalence: dumped color/name/icon/label/ambient/cover for
  every recorded app, before and after the memo. **Identical**, 5428 bytes both.
- 17:37 — probes removed, rebuild clean (0 warnings), ctest 3/3, 30s run → 0 Qt
  warnings.

## Outcome

**done**

- Commits landed: pending commit
- Files touched: `qml/desktop/pages/DesktopCalenderPage.qml`,
  `qml/desktop/components/AppVisual.js`,
  `qml/desktop/memorylake/{GridTexture,MemoDotTexture}.qml`,
  `src/services/project_manager.{h,cpp}`, `tests/db_smoke.cpp`
- Frozen files touched: n
- Follow-ups: backlog doc now has no open items; see its §3 for the two
  invariants this round added.

## No-behavior-delta statement (for the commit body)

Observable behavior unchanged; texture rendering is byte-identical (offscreen
PNG grab, old vs new), AppVisual output is byte-identical across every recorded
app, and the new db_smoke case pins timeEntriesForDate's merge + invalidation.

## Notes for the next agent

Two traps this round, both worth remembering before adding any cache:
(1) a cache turns "callers may mutate what we return" from harmless into a
corruption bug — audit every caller for in-place writes first;
(2) `Canvas.toDataURL()` inside `onPainted` recurses.
