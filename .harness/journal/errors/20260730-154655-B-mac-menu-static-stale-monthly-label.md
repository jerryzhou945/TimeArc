# Error Report - mac-menu-static-stale-monthly-label

## Metadata

- Level: **L3**
- Track: **B**
- Topic: mac-menu-static-stale-monthly-label
- Recorded: 2026-07-30T15:46:55Z
- Session: `20260730-2344-B-about-settings-page.md`
- Platform: n-a
- Tooling: Python 3.12 static test

## 1. What happened

macos_menu_bar_static_test.py expects a 月度记忆湖 translation that the current menu implementation no longer uses

## 2. Evidence

`AssertionError: missing 月度记忆湖 translated: "月度记忆湖": "`

## 3. Root cause

- Immediate cause: The test still requires the superseded 月度记忆湖 menu label.
- Underlying cause: Existing menu implementation and static expectations drifted.
- Why the harness/checklists did not prevent it: The stale test predates this session.

## 4. Fix

- Files changed: none
- Short description: Out of scope; this feature does not change the macOS menu.
- Commit: pending

## 5. Prevention

Update menu-label coverage alongside the menu change in its owning session.

## 6. Lessons for agents (L3)

- Wrong assumption: The unrelated macOS menu baseline was green.
- Earlier signal available: The current menu uses 记忆湖 rather than 月度记忆湖.
- Rule file to update: one-off, no rule change needed.
