# Error Report - android-splash-theme-attribute

## Metadata

- Level: **L3**
- Track: **B**
- Topic: android-splash-theme-attribute
- Recorded: 2026-08-02T01:49:37Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The design incorrectly used framework-prefixed postSplashScreenTheme without the AndroidX SplashScreen dependency; API 31 launch theme will directly inherit TimeArcAppTheme instead.

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
