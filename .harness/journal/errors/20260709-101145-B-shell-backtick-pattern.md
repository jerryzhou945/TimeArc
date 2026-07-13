# Error Report - shell-backtick-pattern

## Metadata

- Level: **L3**
- Track: **B**
- Topic: shell-backtick-pattern
- Recorded: 2026-07-09T10:11:45Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Ran rg with unescaped Markdown backticks in the shell pattern while checking usage_record.md, causing shell command substitution noise before re-running safely.

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
