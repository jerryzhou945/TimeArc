# Error Report - backlog-patch-context

## Metadata

- Level: **L3**
- Track: **C**
- Topic: backlog-patch-context
- Recorded: 2026-08-02T05:08:51Z
- Session: (unknown)
- Platform: n-a
- Tooling: apply_patch

## 1. What happened

Combined apply_patch used stale M4 context; inspected exact section and reapplied narrowly

## 2. Evidence

```
apply_patch verification failed: Failed to find expected M4 context
```

## 3. Root cause

- Immediate cause: the combined patch expected an outdated M4 description.
- Underlying cause: the backlog section was not read immediately before composing the multi-file patch.
- Why the harness/checklists did not prevent it: apply_patch safely rejected the mismatch before changing any file.

## 4. Fix

- Files changed: docs/implementation-backlog.md.
- Short description: inspected the exact section and applied a narrow context-aware patch, placing M5 beside M1-M4.
- Commit: pending verification commit.

## 5. Prevention

One-off patch-context mismatch; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: that the M4 wording in memory matched the current file.
- Earlier signal available: M4 was visible through a direct section read.
- Rule file to update: none; continue reading exact local context before patching.
