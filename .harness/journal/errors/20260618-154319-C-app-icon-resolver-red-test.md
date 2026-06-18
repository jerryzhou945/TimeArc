# Error Report - app-icon-resolver-red-test

## Metadata

- Level: **L2**
- Track: **C**
- Topic: app-icon-resolver-red-test
- Recorded: 2026-06-18T15:43:19Z
- Session: `.harness/journal/sessions/20260618-2338-C-english-tags-icons-mac-doc.md`
- Platform: Windows
- Tooling: PowerShell structural red check

## 1. What happened

Expected red check confirmed `AppIconImageProvider` had no resolver before
falling back to initials.

## 2. Evidence

```text
AppIconImageProvider does not resolve app ids/basenames through Windows App Paths
```

## 3. Root cause

- Immediate cause: provider accepted only concrete existing paths.
- Underlying cause: Stats can provide stable identities without concrete paths.
- Why the harness/checklists did not prevent it: no provider resolver check.

## 4. Fix

- Files changed: `src/services/app_icon_image_provider.cpp`
- Short description: add known app id, App Paths, PATH, and explorer resolution.
- Commit: pending

## 5. Prevention

Reuse the provider structural check when editing icon identity flows.
