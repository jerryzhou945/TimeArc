# Error Report - categorization-short-needle-lint

## Metadata

- Level: **L1**
- Track: **B**
- Topic: categorization-short-needle-lint
- Recorded: 2026-08-25T08:36:34Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

New rule-set lint failed the shipped default table on first run: needles spelled qq.exe / uu.exe / et.exe normalize to two-character Latin substrings (normalize() strips a trailing .exe from needles and observed text alike), which would have matched QQMusic, QQBrowser and similar. Replaced with exact '=' needles in tools/gen_default_rules.py and regenerated; the lint rule that caught it is now documented at the top of the rules section.

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
