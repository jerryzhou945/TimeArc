# Error Report - missing-adapter-registry-cpp

## Metadata

- Level: **L3**
- Track: **C**
- Topic: missing-adapter-registry-cpp
- Recorded: 2026-06-15T05:15:18Z
- Session: `.harness/journal/sessions/20260615-1312-C-ui-stats-memorylake-language-followups.md`
- Platform: Windows PowerShell
- Tooling: `Get-Content`

## 1. What happened

Looked for a non-existent adapter_registry.cpp; desktop app adapter registry is header-only. Continuing with desktop_app_adapter_registry.h.

## 2. Evidence

`Cannot find path ... adapter_registry.cpp because it does not exist`.

## 3. Root cause

- Immediate cause: looked for a `.cpp` registry that does not exist.
- Underlying cause: desktop app adapter registry is header-only.
- Why the harness/checklists did not prevent it: this was exploration.

## 4. Fix

- Files changed: none.
- Short description: continued with `desktop_app_adapter_registry.h`.
- Commit: n/a

## 5. Prevention

One-off exploration mistake; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: adapter registry would have a `.cpp` translation unit.
- Earlier signal available: directory listing of adapter files.
- Rule file to update: none.
