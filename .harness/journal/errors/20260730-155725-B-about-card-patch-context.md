# Error Report - about-card-patch-context

## Metadata

- Level: **L3**
- Track: **B**
- Topic: about-card-patch-context
- Recorded: 2026-07-30T15:57:25Z
- Session: `20260730-2356-B-about-settings-card-layout.md`
- Platform: n-a
- Tooling: apply_patch

## 1. What happened

Initial About card restructuring patch did not apply because the broad QML context did not match exactly

## 2. Evidence

`apply_patch verification failed: Failed to find expected lines`

## 3. Root cause

- Immediate cause: A large replacement hunk contained mismatched indentation.
- Underlying cause: The patch tried to replace the model and layout together.
- Why the harness/checklists did not prevent it: Patch context is checked only at application time.

## 4. Fix

- Files changed: `qml/desktop/pages/DesktopProfilePage.qml`
- Short description: Reapplied the model and layout as two smaller exact-context patches.
- Commit: pending

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: The copied block matched the file byte-for-byte.
- Earlier signal available: A targeted `sed` read would have shown the exact block first.
- Rule file to update: one-off, no rule change needed.
