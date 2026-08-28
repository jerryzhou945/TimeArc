# Error Report - categorization-seed-slice-overreach

## Metadata

- Level: **L1**
- Track: **B**
- Topic: categorization-seed-slice-overreach
- Recorded: 2026-08-25T12:30:29Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

A scripted source edit replaced the byte range between two anchors and silently swallowed setLanguage(), setAutoClassify() and reload(), which sat between them. Caught by the linker (undefined vtable symbols), not by the compiler. Restored verbatim; the lesson is to anchor scripted replacements on both ends of the *target* function, never on the next unrelated symbol.

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
