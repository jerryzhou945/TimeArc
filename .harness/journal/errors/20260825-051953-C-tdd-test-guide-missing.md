# Error Report - tdd-test-guide-missing

## Metadata

- Level: **L3**
- Track: **C**
- Topic: tdd-test-guide-missing
- Recorded: 2026-08-25T05:19:53Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: Superpowers 6.3.0 skill package

## 1. What happened

TDD skill referenced writing-good-tests.md beside SKILL.md, but the installed superpowers package does not contain that file

## 2. Evidence

```
Missing: skills/writing-good-tests.md
Found: skills/test-driven-development/writing-good-tests.md
```

## 3. Root cause

- Immediate cause: the TDD skill's relative reference omitted its subdirectory.
- Underlying cause: the installed package layout differs from the path described in the skill prose.
- Why the harness/checklists did not prevent it: this is external skill-package metadata, not repository content.

## 4. Fix

- Files changed: journal only
- Short description: located and read the reference from the test-driven-development subdirectory.
- Commit:

## 5. Prevention

One-off external skill packaging issue; no repository harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: the referenced file was a sibling of the TDD skill directory.
- Earlier signal available: recursive skill listing showed its actual location.
- Rule file to update: none; external skill package owns the reference.
