# Change Proposal - mobile usage service CMake

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-06-29 06:58 (local)
- Session goal: Expose Android mobile usage repository data to QML through a
  small C++ service.
- Branch: `codex/mobile-usage-ui-sync`

## Frozen files touched

- `src/CMakeLists.txt` - add `mobile_usage_service.cpp/.h` to the shared
  database source set so the app and `timearc_db_smoke` both compile the new
  QML-facing mobile usage service.

## Motivation

The existing Android repository stores usage data but QML should not call SQL or
assemble range summaries itself. A dedicated QObject service formats totals,
top-app rows, and sync/permission state for the mobile UI.

## Impact

Desktop service sampling and shared service contracts are unchanged. The Qt app
gains one compiled C++ service under `src/services/mobile/`.

## Rollback

Revert the service source/header and remove them from `src/CMakeLists.txt`.
Existing Android SQLite tables can remain unused.

## Verification

- Expected red: `timearc_db_smoke` fails while the service header is missing.
- Green: harness build and `timearc_db_smoke` pass with dashboard aggregation
  checks.
