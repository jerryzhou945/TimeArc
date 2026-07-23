# Track B Session — Mobile Seasonal Report QML

## Goal

Migrate the approved seasonal monthly-report web prototype into production
mobile QML, connect it to real Android usage data, and support truthful dynamic
copy plus monthly, app, and period-ranking share posters.

## Service side

The sampling service, service-owned SQLite schema, and C ABI remain unchanged.
Mobile GUI services may extend usage aggregation, insight selection, Android
backfill windows, and UI-private share export.

## UI side

The existing mobile shell stays in place. Monthly report QML gains twelve
month profiles, local original scene assets, six story pages, seasonal motion,
real-data copy, reduced-motion fallbacks, and unified share poster models.

## Expected files

- `src/services/mobile/mobile_usage_service.*`
- `src/services/mobile/mobile_usage_repository.*`
- `src/services/mobile/mobile_usage_insight_engine.*`
- `src/android/**/UsageSyncWorker.java`
- `qml/mobile/components/MobileMonthlyStory.qml`
- `qml/mobile/components/MobileSeasonScene.qml`
- `qml/mobile/components/MobileShareOverlay.qml`
- `qml/mobile/pages/MobileHistoryPage.qml`
- mobile resource manifests and tests

## Explicit non-scope

- Service database schema, service sampler, and C ABI
- Desktop UI
- iOS collection
- Cloud AI or cloud sync
- Third-party visual assets

## Rules

- `rules/01-architecture.md` applies to service and repository boundaries.
- `rules/02-cpp-style.md` applies to new C++ insight code.
- `rules/04-ui-conventions.md` applies to QML layout and motion.
- No frozen source file change is expected.
- Build only through `.harness/tools/build.py`.

## Manual smoke path

Launch mobile preview and Android builds, open all twelve month profiles, move
through all six pages, verify real-data and incomplete-data variants, enable
reduced motion, export each share type, then scan the Qt/QML log.

## Result

Pending implementation after written specification approval.

## Verification

Pending implementation.
