# Error Report - quick-canvas-double-free

## Metadata

- Level: **L2**
- Track: **C**
- Topic: quick-canvas-double-free
- Recorded: 2026-08-28T07:37:21Z
- Session: (unknown)
- Platform: macos
- Tooling: (fill in)

## 1. What happened

Intermittent SIGABRT from a double free in QQuickContext2D::flush() via QQuickCanvasItem::updatePolish() while rendering the Memory Lake page. Present at HEAD with all source changes stashed, on both the cocoa and offscreen plugins, so it is not caused by the stats or traffic-lights work. Non-deterministic: 2/2 cocoa runs died at ~2s, 1/3 offscreen runs. Diagnosed only; NOT fixed here.

## 2. Evidence

AddressSanitizer (side build, C++ only, `/tmp/build-asan`) names both frees.

Second free — the crash:

```
ERROR: AddressSanitizer: attempting double-free on 0x61200038ca40 in thread T0:
  #1 QQuickContext2D::flush()   <- deletes it a second time
  #2 QQuickCanvasItem::updatePolish() / #3 QQuickWindowPrivate::polishItems()
  #4 QSGThreadedRenderLoop::polishAndSync(...)
  #38 -[NSAlert runModal]
  #39 -[NSPersistentUIRestorer promptToIgnorePersistentStateWithCrashHistory:]
```

First free — the real culprit, with the QML call site:

```
freed by thread T0 here:
  #1 QQuickContext2D::flush()   <- deletes the buffer
  #2 QQuickContext2D::toImage() / #3 QQuickCanvasItem::toImage()
  #4 QQuickCanvasItem::toDataURL(QString const&) const
  #11 ..._GridTexture_qml::$_3::__invoke   GridTexture_qml.cpp:1009
```

## 3. Root cause

- Immediate cause: `GridTexture.qml` and `MemoDotTexture.qml` render one tile
  into a hidden `Canvas` and snapshot it with `toDataURL()` **from inside their
  own `onPainted` handler**. `toDataURL()` -> `toImage()` -> `flush()` deletes
  the `QQuickContext2DCommandBuffer`. But `onPainted` fires inside the polish
  pass, and that same pass's `QQuickCanvasItem::updatePolish()` then calls
  `flush()` again on the already-deleted buffer.
- Underlying cause: `toDataURL()` is not re-entrant with the paint cycle it is
  called from. The existing `exporting` guard was written for a different
  symptom (infinite recursion, since `toDataURL()` synchronously forces a
  paint); it correctly prevents recursive `onPainted`, but nothing stopped the
  *outer* polish pass from flushing a buffer the inner call had already freed.
- Why the harness/checklists did not prevent it: intermittent (~40% at startup)
  and it presents as a bare SIGABRT with no Qt warning, so `scan_qt_log.py` sees
  nothing. It is invisible to every static test. The macOS "reopen windows after
  a crash" alert runs a nested modal loop that widens the window between the two
  flushes, so once the app has crashed once it tends to keep crashing — which
  reads as flakiness rather than a defect.

## 4. Fix

- Files changed: `qml/desktop/memorylake/GridTexture.qml`,
  `qml/desktop/memorylake/MemoDotTexture.qml`
- Short description: the snapshot is deferred out of the paint cycle with
  `Qt.callLater(tile.exportTile)`, so `toDataURL()`'s flush no longer overlaps
  the polish pass's flush. The re-entrancy guard stays in `onPainted`, where it
  must be evaluated synchronously — moving the check into `exportTile()` would
  reset the flag before the deferred call ran and restore the original infinite
  recursion.
- Commit: pending commit

## 5. Prevention

Rule upgrade for `rules/04-ui-conventions.md`: never call `Canvas.toDataURL()`
or `toImage()` from `onPaint`/`onPainted` — defer with `Qt.callLater`. A grep for
`toDataURL` inside a paint handler is a cheap static check to add. `MemoInkCanvas`
calls it from user gestures (outside the cycle) and is safe; these two tiles were
the only in-cycle callers.

## 6. Verification

- Before: release build 3/6, 5/12, 4/10 crashed at startup (~40%).
- After: **0/20** release runs crashed, and **0/8** ASan runs reported any error
  (P(0/20) under the old rate is ~4e-5).
- Textures still render: temporary instrumentation confirmed both tiles export
  non-empty data URLs after the change (`GRID len=278..446`, `DOTS len=214`),
  then was removed.

## 7. Hypotheses falsified along the way

None of these moved the crash rate off ~40%; recorded so nobody re-tests them.
`MemoInkCanvas` Threaded->Cooperative; `GlowCircle` Canvas.Immediate; dropping
`createRadialGradient`; rewriting `GlowCircle` on `QtQuick.Shapes` (5/12 — the
earlier 1/8 with a plain Rectangle was chance, ~10% at the base rate);
`QSG_RENDER_LOOP=basic` (4/10). Crashes following bursts of `GlowCircle`
destruction was a red herring — those bursts happen on every run, survivors too.
