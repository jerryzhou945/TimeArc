# Error Report - qtactivity-oncreate-visibility

## Metadata

- Level: **L3**
- Track: **C**
- Topic: qtactivity-oncreate-visibility
- Recorded: 2026-08-02T05:02:30Z
- Session: 20260802-1232-C-android-mobile-regressions
- Platform: Android
- Tooling: javac / QtActivity

## 1. What happened

The lifecycle regression assumed protected onCreate, but QtActivity declares it public; update the test and override visibility

## 2. Evidence

`javac`: `onCreate(Bundle) cannot override QtActivity.onCreate(Bundle); attempting to assign weaker access privileges; was public`.

## 3. Root cause

- Immediate cause: the new override was declared protected.
- Underlying cause: the test assumed the platform Activity signature instead of inspecting QtActivity's public method.
- Why the harness/checklists did not prevent it: the native target does not compile packaged Java sources.

## 4. Fix

- Files changed: `TimeArcActivity.java`, `android_launch_experience_static_test.py`.
- Short description: declare and assert a public override.
- Commit: pending verification commit.

## 5. Prevention

The APK target remains the required Java inheritance check.

## 6. Lessons for agents (L3)

- Wrong assumption: QtActivity uses the same protected `onCreate` visibility as the base Android Activity.
- Earlier signal available: the Qt Android jar/class signature could have been inspected before writing the regression.
- Rule file to update: one-off; the implementation plan now treats APK javac as the authoritative check.
