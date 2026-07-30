# Error Report - process-list-sandbox

## Metadata

- Level: **L3**
- Track: **C**
- Topic: process-list-sandbox
- Recorded: 2026-07-28T09:46:58Z
- Session: (unknown)
- Platform: macOS
- Tooling: `pgrep`

## 1. What happened

Visual-verification process-list check could not access macOS sysmond from the sandbox

## 2. Evidence

```
sysmon request failed with error: sysmond service not found
pgrep: Cannot get process list
```

## 3. Root cause

- Immediate cause: sandboxed `pgrep` could not access the macOS process list.
- Underlying cause: process-list visibility is restricted by the execution
  environment.
- Why the harness/checklists did not prevent it: this was an optional visual
  verification diagnostic, not a build gate.

## 4. Fix

- Files changed: none
- Short description: Continued with build, tests, and static geometry checks.
- Commit: not applicable

## 5. Prevention

One-off sandbox limitation; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: sandboxed process inspection would be available.
- Earlier signal available: macOS process inspection commonly requires broader
  permissions.
- Rule file to update: none.
