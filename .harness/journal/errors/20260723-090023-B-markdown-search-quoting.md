# Error Report - markdown-search-quoting

## Metadata

- Level: **L3**
- Track: **B**
- Topic: markdown-search-quoting
- Recorded: 2026-07-23T09:00:23Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

A documentation grep used Markdown backticks inside a double-quoted shell argument, causing unintended command substitution; no files were changed by the failed substitution.

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
