# Error Report - appkit-content-border-exception

## Metadata

- Level: **L2**
- Track: **C**
- Topic: appkit-content-border-exception
- Recorded: 2026-07-28T09:04:41Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

macOS rejected `setAutorecalculatesContentBorderThickness:forEdge:` for the top
edge on the non-textured Qt window and aborted the app.

## 2. Evidence

```
NSInvalidArgumentException: setAutorecalculatesContentBorderThickness:forEdge:
may not be called with NSMaxYEdge in a non-textured window
```

## 3. Root cause

- Immediate cause: a diagnostic workaround called an AppKit API that is invalid
  for this window style.
- Underlying cause: the visible strip was misidentified as a native content
  border before the QML safe-area padding was inspected.
- Why the harness/checklists did not prevent it: the API precondition was not
  verified before the runtime experiment.

## 4. Fix

- Files changed: `src/services/macos/macos_traffic_lights.mm`.
- Short description: removed both content-border calls; the final fix is the
  QML safe-area override and requires no content-border mutation.
- Commit: pending.

## 5. Prevention

One-off, no harness change needed; use only APIs valid for the active style mask.
