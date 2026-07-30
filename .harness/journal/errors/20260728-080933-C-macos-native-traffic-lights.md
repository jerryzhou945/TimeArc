# Error Report - macos-native-traffic-lights

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-native-traffic-lights
- Recorded: 2026-07-28T08:09:33Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The macOS frameless window displays AppKit-colored circles but draws its own
hover symbols and routes its own close/minimize/fullscreen actions, producing
behavior and artwork that do not match the current system controls.

## 2. Evidence

```
Repro:
1. Launch the current macOS build.
2. Move the pointer over the traffic-light group in the sidebar.
3. Compare the supplied 16:00:41 TimeArc capture with the supplied 16:01:44
   native-window capture.

Observed: TimeArc's green hover symbol uses the older opposing-triangle design;
the native control uses the current diagonal expand symbol. Source inspection
also shows TimeArcTrafficLightGlyphView drawing every hover glyph and
TimeArcTrafficLightTarget manually dispatching every action.
```

## 3. Root cause

- Immediate cause: factory-created `NSWindow` buttons are only native
  renderers, not the actual controls managed by the app's `NSWindow`; the
  handwritten glyph overlay and Qt action target therefore replace AppKit's
  standard group hover and window behavior.
- Underlying cause: `qml/main.qml` requested a borderless macOS `QWindow`, so
  it had no native titled-window button hierarchy to reuse. The implementation
  compensated by simulating the missing behavior.
- Why the harness/checklists did not prevent it: the earlier visual check
  accepted native-colored controls without requiring the buttons to be owned
  and managed by the actual window.

## 4. Fix

- Files changed: `qml/main.qml`,
  `src/services/macos/macos_traffic_lights.h`,
  `src/services/macos/macos_traffic_lights.mm`.
- Short description: keep a titled/resizable AppKit window internally, enable
  full-size content, suppress Qt Quick Controls' automatic macOS top safe-area
  padding, and use that window's own close/minimize/zoom buttons without
  reparenting, custom drawing, or custom action targets.
- Commit: pending.

## 5. Prevention

One-off, no harness change needed. Review criterion: a control is not
"native" unless the owning `NSWindow` supplies and manages it.
