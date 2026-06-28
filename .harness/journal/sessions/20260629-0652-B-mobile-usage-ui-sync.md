# B Feature - mobile usage UI sync

Goal: finish the next Android mobile usage path by exposing mobile usage
backend state to QML, wiring app-open sync hooks, and showing stored Android
usage data in the existing mobile UI.

## Service side

The desktop `time-arc-service` remains unchanged. Android collection is an
in-app mobile producer: Java reads UsageStats/UsageEvents after Usage Access
authorization and passes DTOs through JNI to the C++ repository. No desktop
`src/service/windows|macos|linux` sampling code or shared service schema changes
are expected.

## UI side

The Qt app consumes the SQLite mobile tables through a new QObject-facing mobile
usage service. Mobile QML shows permission/sync/read status and a ranked Android
usage list. The UI reads repository results and triggers sync through a small
Android bridge method; it does not run SQL or Android Framework calls directly.

## Expected files touched

- `src/services/mobile/*`
- `src/main.cpp`
- `qml/mobile/*`
- `android/src/main/java/com/timearc/mobile/usage/*`
- `docs/mobile/*`

## Expected files not touched

- `src/service/windows|macos|linux/*`
- `src/service/shared/*`
- top-level `CMakeLists.txt`

## Rule files reviewed

- `rules/01-architecture.md`
- `rules/02-platform-boundaries.md`
- `rules/04-ui-conventions.md`

## Verification plan

- Java compile against Android SDK where possible.
- Harness build through `.harness/tools/build.py`.
- `ctest --test-dir build --output-on-failure -R timearc_db_smoke`.
- Mobile QML static/load checks where available.
- Android emulator check for Usage Access settings and usagestats source.
