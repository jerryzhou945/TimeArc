# Error Report - gpp-smoke-journal-source

## Metadata

- Level: **L3**
- Track: **B**
- Topic: gpp-smoke-journal-source
- Recorded: 2026-06-13T20:57:23Z
- Session: .harness/journal/sessions/20260614-0440-B-alpha-polish-g1-g4.md
- Platform: windows
- Tooling: PowerShell, harness_check.py

## 1. What happened

Temporary g++ smoke source was written under .harness/journal/build-logs, causing harness_check pass 7 to see a new source file.

## 2. Evidence

```
harness_check.py pass 7:
DRIFT: track B adds source files without rules/ or README update:
['.harness/journal/build-logs/gpp-smoke.cpp']
```

## 3. Root cause

- Immediate cause: a temporary compiler smoke-test `.cpp` file was created under `.harness/journal/build-logs`.
- Underlying cause: the diagnostic file extension made harness pass 7 treat it like a source addition.
- Why the harness/checklists did not prevent it: the file was generated during ad hoc build-tool debugging.

## 4. Fix

- Files changed: removed temporary `gpp-smoke.cpp`, `gpp-smoke.exe`, and related diagnostic text files.
- Short description: kept harness journal clean by deleting generated smoke artifacts.
- Commit: pending commit.

## 5. Prevention

One-off diagnostic artifact cleanup; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: build-log directory was a harmless place for temporary `.cpp` diagnostics.
- Earlier signal available: pass 7 scans added source files by extension.
- Rule file to update: none.
