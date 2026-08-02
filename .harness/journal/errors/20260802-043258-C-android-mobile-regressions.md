# Error Report - android-mobile-regressions

## Metadata

- Level: **L2**
- Track: **C**
- Topic: android-mobile-regressions
- Recorded: 2026-08-02T04:32:58Z
- Session: 20260802-1232-C-android-mobile-regressions
- Platform: Android / HarmonyOS Zhuoyitong
- Tooling: Qt 6.11, AndroidX Core, WorkManager, QML

## 1. What happened

Pura 90 Pro shows square app icons, non-edge-to-edge system bar bands, and missing current-day usage after re-entering TimeArc

## 2. Evidence

- Pura 90 Pro screenshot: ChatGPT icon remains square inside a TimeArc card.
- The status bar is black and the gesture-navigation area is white instead of showing the app background.
- The dashboard reports a first record date of 2026-07-01 and 21h 40m on one recorded day, while current-day usage is absent.
- `MobileAppIcon.qml` uses `Rectangle.clip`, which clips to bounds rather than the rounded outline.
- JNI assigns an aggregate covering the previous month through now to `QDateTime::fromMSecsSinceEpoch(beginMs).date()`.

## 3. Root cause

- Immediate cause: rounded corners are visual-only, edge-to-edge is not tied to a guaranteed Activity lifecycle, and a multi-day UsageStats aggregate is stored as one start-date row.
- Underlying cause: the first implementation relied on rectangular QML clipping, a best-effort Context-to-Activity cast, and treated one aggregate window as one daily summary.
- Why the harness/checklists did not prevent it: static checks verified the presence of APIs and properties, but not rounded-mask behavior, Activity lifecycle ownership, or the date partition of persisted usage.

## 4. Fix

- Files changed: pending implementation.
- Short description: use a real rounded mask, lifecycle-owned edge-to-edge/sync, per-day replacement, and completion-driven UI refresh.
- Commit: pending commit.

## 5. Prevention

Add regression checks for a real QML mask, a no-theme lifecycle Activity, per-day aggregate windows, and sync-completion notification.
