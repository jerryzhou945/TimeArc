# 20260828-1530 · Track C · Guard the macOS winId() casts

**Related error report:** `errors/20260828-071233-C-offscreen-teardown-segfault.md`
(§1–§6 filled: the slug says "teardown", but §1 records the correction — the
crash is at startup, inside `main()`, before the event loop).

## Root cause, in one line

`QWindow::winId()` is an opaque `WId` owned by the active QPA plugin; two macOS
call sites `reinterpret_cast` it to `NSView*` without checking the plugin is
`cocoa`, so off cocoa they message a small integer and `objc_msgSend` faults
reading an isa word from address `0x1`.

## Change

`createNativeViews()` and `nativeWindowFor()` now return early unless
`QGuiApplication::platformName() == "cocoa"`. Guarded at the casts, not at
`attach()`, so both call paths into `createNativeViews` are covered by one
check. `rules/02-platform-boundaries.md` governs `src/service/` (the background
service) and does not constrain these UI-side helpers.

## Verification

- Original repro (`QT_QPA_PLATFORM=offscreen ...`) no longer crashes: the
  process reaches the event loop, loads a page, and exits 143 on SIGTERM
  instead of 139 on SIGSEGV. The `MacTrafficLightsController` frame is gone
  from every backtrace.
- No cocoa regression: a temporary probe (added, measured, removed) showed
  `platformName="cocoa" guardPassed=true` plus "reached AppKit button wiring"
  on cocoa, and `guardPassed=false` on offscreen. Title-bar buttons are wired
  exactly as before on the only platform that has them.
- `tools/build.py` clean; static suite and the 77 JS checks still pass.

## Found while verifying — NOT fixed here

`errors/20260828-073721-C-quick-canvas-double-free.md`: an intermittent double
free in `QQuickContext2D::flush()` (Memory Lake page). Reproduces at HEAD with
every source change stashed, on both plugins — 2/2 cocoa runs died at ~2s, 1/3
offscreen. It became easier to notice here only because fixing the segfault let
the app get far enough to render. It is a separate defect on a page this
session never touched, so it wants its own track C session.

## Harness note

`journal/INDEX.md` had grown to 106 lines (budget 100). `record_error.py`
cannot find the markdown table — the historical rows sit inside a single
literal-`\n` line — so each append lands as a 3-line block: marker comment,
row, blank. Compacted by deleting only those repeated marker comments and the
stray blanks: 35 lines reclaimed, **zero table rows removed** (verified by
diff). The underlying tool/format drift is untouched and will recur.
