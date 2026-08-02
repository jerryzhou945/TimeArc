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

The minimum periodic interval is controlled by WorkManager. AndroidX Startup
is deliberately removed from the merged manifest: compatibility containers
may not expose every service WorkManager expects before Qt renders. TimeArc
initializes WorkManager lazily after Usage Access is confirmed and converts an
unavailable scheduler into a UI status instead of terminating the process.

Usage Access onboarding also runs after the QML launch overlay. The first run
navigates to the settings page, but only an explicit user action opens the
system Usage Access activity. This keeps startup usable on Android-compatible
environments that do not implement that settings intent.
