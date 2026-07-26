# Error Report - macos-main-missing-runner

## Metadata

- Level: **L1**
- Track: **C**
- Topic: macos-main-missing-runner
- Recorded: 2026-07-23T19:39:50Z
- Session: `20260724-0339-C-macos-tracking-main.md`
- Platform: macOS
- Tooling: Apple Swift 6.2.4

## 1. What happened

macOS service type-check fails because TimeArcService references removed LiveServiceApplication instead of the Tracking coordinator.

## 2. Evidence

```
src/service/macos/TimeArcService.swift:10:23: error:
cannot find 'LiveServiceApplication' in scope
```

## 3. Root cause

- Immediate cause: `TimeArcService.main` calls a type removed from the source tree.
- Underlying cause: the Tracking refactor did not replace the legacy application entry point.
- Why the harness/checklists did not prevent it: the macOS target had remained blocked earlier by its stale frozen CMake source list.

## 4. Fix

- Files changed: `src/service/macos/TimeArcService.swift`
- Short description: run `TrackingCoordinator` directly on a monotonic one-second polling schedule and flush it on termination signals.
- Commit: pending

## 5. Prevention

One-off; the scoped Swift type-check now covers the exact macOS service source list.
