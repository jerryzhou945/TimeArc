# 20260828-1541 · Track C · Canvas toDataURL() called inside the paint cycle

**Related error report:** `errors/20260828-073721-C-quick-canvas-double-free.md`
(§1–§7, including the falsified hypotheses).

## Root cause, in one line

`GridTexture.qml` and `MemoDotTexture.qml` snapshot their hidden tile `Canvas`
with `toDataURL()` from inside `onPainted`; `toDataURL()` flushes and deletes the
`QQuickContext2DCommandBuffer`, and the polish pass that emitted `painted` then
flushes the same buffer again — double free, ~40% of startups.

## Change

The snapshot moves to `Qt.callLater(tile.exportTile)`, out of the paint cycle.
The `exporting` re-entrancy guard stays in `onPainted` and must: evaluated inside
`exportTile()` it would have reset before the deferred call ran, reviving the
infinite recursion the guard was originally written for.

## How it was found

Correlation was misleading here and cost most of the session. Crashes were
preceded by bursts of `GlowCircle` Canvas destruction, so the first hypotheses
all targeted Canvas *lifetime* — every one of them measured at or near the base
rate (see report §7). What settled it was a side AddressSanitizer build
(`/tmp/build-asan`, C++ only, so the Swift service still links), whose
double-free report named the QML call site directly — `GridTexture_qml.cpp:1009`
inside `QQuickCanvasItem::toDataURL`. Statistical A/B on a ~40% intermittent
crash was not a substitute for that: 1/8 vs 3/6 looked meaningful and was not.

## Verification

- Before: 3/6, 5/12, 4/10 release startups crashed (~40%).
- After: **0/20** release, **0/8** ASan-clean. P(0/20) at the old rate ≈ 4e-5.
- Not a silent visual regression: temporary instrumentation confirmed both tiles
  still export non-empty data URLs (`GRID len=278..446`, `DOTS len=214`); probe
  removed afterwards.
- `tools/build.py` clean throughout; static suite and the 77 JS checks pass.

## Harness notes

- The ASan build is a diagnostic side build configured directly with `cmake` into
  `/tmp/build-asan`. No frozen file was edited and no *product* build bypassed
  `build.py`. ASan is applied to C++ only (`CMAKE_C_FLAGS` left empty) because
  `swiftc` cannot link the ASan runtime for `time-arc-service`.
- One L1 (`20260828-074841-C-build-failure`) is mine: temporary instrumentation
  added a second `Component.onCompleted` to canvases that already had one.
- `scan_qt_log.py` filed two cosmetic `qt-warning-*` L2s from verification runs
  (the "Sans Serif" font-alias warning and `QMutex: destroying locked mutex`).
  The mutex warning was a *symptom* of this crash and should stop appearing.
