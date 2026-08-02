# Android launcher identity and launch experience

Goal: add a mobile-quality TimeArc Android launcher icon, native splash, bounded
in-app reveal, and an installable APK without changing usage data semantics.

Service side: no service sampling, storage, schema, or disk-contract behavior
changes. Android framework packaging supplies only application identity and
startup presentation resources.

UI side: the Android launcher receives adaptive/round/legacy icon resources;
the native splash hands off to a mobile-only QML overlay that reads the existing
theme and reduced-motion preference, then reveals the existing shell.

Expected files: Android manifest/resources, one mobile QML component,
`MobileAppShell.qml`, `qml/CMakeLists.txt`, static tests, user-facing report,
backlog/open-issues entries, and this session's design/plan documents. Frozen
top-level CMake, schema, bridge, service sources, and Charter files are out of
scope. Applicable rules: 04 UI conventions, 05 build system, 08 git workflow.

Completed: Generated the approved GPT Image icon master; added adaptive,
themed, round, and legacy launcher resources; added dependency-free native
splash themes; implemented an explicit post-preference QML launch transition;
and produced an arm64-v8a debug APK.

Incomplete: Physical Android/HarmonyOS device installation and first-frame
recording are unavailable because the local ADB probe did not return. PR delivery
is the remaining repository step.

Verification: Android launch/usage/mobile UI/desktop UX/resource static tests
pass; desktop Harness builds pass; CTest passes 4/4; Android Harness `apk` target
passes; AAPT confirms package `com.timearc.app`, minSdk 28, targetSdk 36,
arm64-v8a, and the v33 adaptive icon; SHA-256 is
`EBEBF8BD46B050885A87230BE070F4E575654AC783975C7A6F60D6CDA284213B`.

Next: Run final diff/Harness gates, then commit, push, PR, merge, and clean the
feature branch.

Risks: Android/HarmonyOS vendor ROM launch rendering and Usage Access behavior
remain unverified on physical hardware; the delivered APK uses debug signing.
