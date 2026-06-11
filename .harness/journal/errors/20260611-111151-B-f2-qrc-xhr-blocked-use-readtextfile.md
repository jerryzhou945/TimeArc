# Error Report - f2-qrc-xhr-blocked-use-readtextfile

## Metadata

- Level: **L3**
- Track: **B**
- Topic: f2-qrc-xhr-blocked-use-readtextfile
- Recorded: 2026-06-11T11:11:51Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

F2 loader: kickoff's recommended pure-QML XMLHttpRequest GET on qrc: is blocked by Qt default (QML_XHR_ALLOW_FILE_READ off). Switched to normalizing qrc:/ to :/ and calling settingsRepository.readTextFile() (QFile reads the :/ resource prefix). Verified non-empty for all 5 texts.

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
