# Error Report - sfx-size-assertion

## Metadata

- Level: **L2**
- Track: **B**
- Topic: sfx-size-assertion
- Recorded: 2026-08-25T04:06:50Z
- Session: .harness/journal/sessions/20260825-1143-B-release-readme-package-sync.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The valid SFX output was smaller than the source ZIP because its embedded 7z archive recompressed the payload; the size assertion was incorrect

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
