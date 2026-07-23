# Session: Foreground record emission review

- Date: 2026-07-23 16:36
- Track: B — Feature
- Status: done

## Scope

Review the current macOS tracking source to determine whether foreground
sessions can now produce records. No implementation files will be modified.

## Service-side behavior

Trace foreground session creation, active/idle transitions, refresh, shutdown,
and the bridge into the native database API.

## UI-side behavior

No UI behavior or source is changed. Confirm only that the service-side record
shape remains compatible with the existing journal contract.

## Verification

- Traced `FrontmostStateMachine` through activation, idle/reactivation,
  refresh, and shutdown.
- Traced every returned foreground record through `TrackingCoordinator` into
  `DataBridge.updateFrontmost`.
- Confirmed the relevant Swift files pass frontend syntax parsing.
- Confirmed zero-duration records remain suppressed in accordance with D2.
- The foreground state-machine path can now produce records after elapsed
  whole-second time. End-to-end service execution remains blocked by the
  separate, pre-existing macOS source-list/application-integration mismatch.
