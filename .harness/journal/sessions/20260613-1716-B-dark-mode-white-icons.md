# Session Log — dark-mode-white-icons

## Metadata

- Agent / Author: Codex
- Track: **B (Feature)**
- Date: 2026-06-13 17:16 → 17:30 (local)
- Branch: `codex/dark-mode-white-icons`
- Baseline commit: `c34657d`

## Goal

Switch desktop sidebar icons to white variants in night mode and change the memo icon to `note.svg`.

## Service side

No service behavior changes. The background tracker, disk contract, SQLite, JSONL, and
`usage_config.json` are untouched.

## UI side

`DesktopAppShell` keeps the existing navigation model and adds an optional `nightIcon`
per item. The delegate chooses `nightIcon` only when `nightMode` is true. The memo
action remains an overlay action, not a routed page.

## Plan

- Inspect existing nav icon references and resource registration.
- Add night icon paths for the desktop sidebar.
- Register new SVG resources.
- Verify harness/build checks.

## What actually happened

- Created `codex/dark-mode-white-icons` from `dev` after moving off the workflow-rule branch.
- Added `nightIcon` entries for home/calendar/stats/settings/memo.
- Changed memo icon from `chat.svg` to `note.svg`.
- Registered the new SVG files in `resources/CMakeLists.txt`.
- Fixed white SVG strokes to hard-coded white.
- Restored unrelated `bilibili.svg` / `user.svg` deletions because they are still referenced by resources/site catalog.

## Outcome

**done**

- Commits landed: pending
- Files touched: `qml/desktop/DesktopAppShell.qml`, `resources/CMakeLists.txt`,
  `resources/icons/*_white.svg`, `resources/icons/note.svg`, docs/harness logs
- Frozen files touched: no
- Follow-ups spun out to `../state/open-issues.md`: none

## Notes for the next agent

There is no `recap_white.svg`, so the bottom monthly recap icon still uses `recap.svg`.
