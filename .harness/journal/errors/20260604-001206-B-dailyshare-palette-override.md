# Error Report - dailyshare-palette-override

## Metadata

- Level: **L2**
- Track: **B**
- Topic: dailyshare-palette-override
- Recorded: 2026-06-04T00:12:06Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

DailyUsageShare new 'palette' property collided with base QQuickItem.palette member (qt.qml.propertyCache.append override warning, seen via qml.exe). Renamed to 'sharePalette'. Lesson: avoid QML property names that shadow built-in Item members (palette, state, opacity, etc.).

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
