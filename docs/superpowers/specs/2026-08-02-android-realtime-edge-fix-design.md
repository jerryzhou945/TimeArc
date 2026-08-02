# Android realtime usage and edge-to-edge repair

## Goal

Repair the three Pura 90 Pro regressions while keeping the HarmonyOS-compatible Qt default Activity theme: app icons use the same rounded-square silhouette as launcher icons, the dark app background extends behind both system bars, and every foreground entry refreshes correctly partitioned current-day usage.

## Chosen approach

Use a thin `TimeArcActivity` that inherits Qt's Activity and owns lifecycle-only hooks. It will not declare an `android:theme`; `onCreate` and `onResume` reapply edge-to-edge, and `onResume` queues an immediate usage sync. This is more deterministic than asking an arbitrary Context to behave like an Activity and lighter than a foreground collection service.

## UI and system bars

`MobileAppIcon` will render its loaded icon through `MobileRoundedFrame`/`MultiEffect`, because QML `clip` does not follow a rectangle's radius. The mask ratio remains 22% so every real system icon and fallback has one consistent mobile silhouette.

The Activity-owned window setup combines `WindowCompat.setDecorFitsSystemWindows(false)` with transparent colors and legacy layout flags used by compatibility containers. Dark mode keeps light status/navigation glyphs. QML continues to inset interactive content with `SafeArea`, while the wallpaper/canvas itself fills the whole window. Light-mode tuning is explicitly deferred.

## Usage data flow

The current worker asks Android for one aggregate from the previous month through now, while JNI stores it under the aggregate's start date. The repair queries one local-calendar day at a time. Before inserting that day's aggregate rows, native storage removes only matching Android aggregate summaries for that date/device/source; sessions and other sources are untouched. This also repairs stale rows created by the prior multi-day write.

Every Activity resume queues unique immediate work. The worker reports completion through the native bridge; when the UI service exists, the completion callback emits `dataChanged` on the Qt thread. Home, statistics, history, and settings therefore reload after persistence finishes instead of reloading when work is merely queued. Periodic WorkManager sync remains as the background fallback.

## Failure handling

Missing Usage Access remains a successful no-op with an explicit status. A failed daily replacement or session sync returns retry. A completion callback is ignored safely when the Qt UI is not alive. Repeated resume events replace the same unique immediate work rather than running parallel imports.

## Verification

- Static Android tests assert the manifest has no Activity theme, the lifecycle Activity owns edge-to-edge/resume sync, and aggregates are partitioned by local day.
- QML regression asserts a real rounded mask, not `Rectangle.clip`.
- Database smoke verifies per-day aggregate replacement deletes stale Android aggregate rows while preserving sessions and unrelated sources.
- Windows harness build and CTest protect cross-platform code.
- Android UI/APK targets, v2 signature, package, ABI, permission, and merged-manifest checks protect the HarmonyOS package.
- Final Pura 90 Pro check covers top/bottom background coverage, rounded ChatGPT icon, and today's refreshed duration.

## Scope exclusions

No light-mode redesign, no foreground service, no service-database schema change, no custom launch theme, and no deletion of raw Android usage sessions.
