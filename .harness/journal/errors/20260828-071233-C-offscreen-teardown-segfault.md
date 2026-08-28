# Error Report - offscreen-teardown-segfault

## Metadata

- Level: **L2**
- Track: **C**
- Topic: offscreen-teardown-segfault
- Recorded: 2026-08-28T07:12:33Z
- Session: (unknown)
- Platform: macos
- Tooling: (fill in)

## 1. What happened

TimeArc segfaults immediately at startup under `QT_QPA_PLATFORM=offscreen`
(exit 139, EXC_BAD_ACCESS at address 0x1). Not a teardown crash as first
recorded: QML loading simply finishes before `main()` reaches the crashing
call, which is why the last log lines are page loads.

Present at HEAD, unrelated to the stats work (reproduces with those changes
stashed). Does NOT affect users: on the real `cocoa` platform plugin the same
binary runs normally. It does block any headless/CI smoke run on macOS.

## 2. Evidence

```
(failed to read build/TimeArc.app: [Errno 21] Is a directory: 'build/TimeArc.app')
```

## 3. Root cause

- Immediate cause: `macos_traffic_lights.mm:87-89` does
  `NSView* qtView = reinterpret_cast<NSView*>(window_->winId());` then
  `NSWindow* nativeWindow = qtView.window;`. `QWindow::winId()` returns an
  opaque `WId` whose meaning belongs to the active QPA plugin: under `cocoa`
  it really is an `NSView*`, but under `offscreen` it is a fabricated counter
  (here `1`). Sending `-window` to `0x1` makes `objc_msgSend` load the isa
  pointer from address 1 and fault. The existing `if (!nativeWindow) return;`
  guard sits one line too late -- the fault is in *computing* `nativeWindow`,
  not in using it.
- Underlying cause: a platform-specific handle is cast to a native type
  without first checking that the platform actually is the one that produces
  that type.
- Why the harness/checklists did not prevent it: nothing runs the app
  headless, so no gate ever exercised a non-cocoa QPA plugin. The crash is
  invisible in normal use.

## 4. Fix

- Files changed: `src/services/macos/macos_traffic_lights.mm`,
  `src/services/macos/macos_app_lifecycle.mm`
- Short description: added `windowsAreNativeCocoa()`
  (`QGuiApplication::platformName() == "cocoa"`) and gated
  `MacTrafficLightsController::createNativeViews()` on it -- guarding there
  rather than in `attach()` covers both call paths (the direct one and the
  `visibleChanged` lambda) with one check, at the cast itself.
  `macos_app_lifecycle.mm::nativeWindowFor()` had the identical unchecked cast
  behind a `window->handle()` test that does not discriminate plugins; it would
  have faulted next, so it got the same guard. Every other member of the
  controller was already null-safe, so it simply stays inert off cocoa.
  `main.cpp:154` casts `winId()` to `HWND` in the same shape, but DWM validates
  the handle rather than dereferencing it, so it degrades to a failed API call
  instead of a crash. Left alone; noted here.
- Commit: pending commit

## 5. Prevention

Concrete harness upgrade: a headless launch is now possible, so
`QT_QPA_PLATFORM=offscreen` + "load a page, exit 0" can become a smoke gate --
`scan_qt_log.py` already consumes what such a run logs. That gate is blocked
today by a *separate* pre-existing defect found while verifying this one
(`20260828-073721-C-quick-canvas-double-free`), which must be fixed before an
offscreen run is stable enough to gate on.

## 6. Verification

- Repro before: immediate `EXC_BAD_ACCESS (code=1, address=0x1)` in
  `MacTrafficLightsController::createNativeViews()`, frame #1 of the crash.
- Repro after: the app reaches the event loop and renders; the controller frame
  is absent from every backtrace, and the process survives to a clean SIGTERM
  (exit 143, was 139).
- No cocoa regression, proven with a temporary probe built into
  `createNativeViews()` and then removed:
  - cocoa:     `platformName="cocoa"     guardPassed=true`  + "reached AppKit button wiring"
  - offscreen: `platformName="offscreen" guardPassed=false`
  So the native title-bar buttons are still wired exactly as before on the only
  platform that has them.
