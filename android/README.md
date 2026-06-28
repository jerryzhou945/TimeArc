# TimeArc Android Usage Backend

This directory holds the Android framework side of TimeArc mobile usage
collection. It is intentionally separate from `src/service/`, which remains the
desktop native background collector.

## Responsibilities

- Java reads Android `UsageStatsManager` and `UsageEvents`.
- Java normalizes package names to TimeArc app identifiers:
  `android:<package_name>`.
- Java hands DTO arrays to the Qt native library through
  `AndroidUsageNativeBridge`.
- C++ repositories under `src/services/mobile/` persist data into the shared
  TimeArc SQLite database.
- QML/UI should read the C++ repository output or higher-level stats services,
  not call Android framework APIs directly.

## AndroidX WorkManager

P5 periodic sync uses AndroidX WorkManager. When the Qt Android package source
directory is wired into the Android build, add the current stable WorkManager
runtime dependency to the generated Gradle project, for example:

```kotlin
dependencies {
    implementation("androidx.work:work-runtime:2.9.1")
}
```

The minimum periodic interval is controlled by WorkManager. TimeArc also calls
`UsageSyncScheduler.enqueueImmediateSync()` when the app opens so usage data is
refreshed without waiting for the periodic worker.
