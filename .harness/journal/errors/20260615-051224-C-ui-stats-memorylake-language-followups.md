# Error Report - ui-stats-memorylake-language-followups

## Metadata

- Level: **L2**
- Track: **C**
- Topic: ui-stats-memorylake-language-followups
- Recorded: 2026-06-15T05:12:24Z
- Session: `.harness/journal/sessions/20260615-1312-C-ui-stats-memorylake-language-followups.md`
- Platform: Windows / Qt6 desktop
- Tooling: harness build, db smoke, Qt log scan

## 1. What happened

Stats heatmap underfills its card, monthly top apps overflows, app identity/colors are mismatched, language setting does not affect English app names, recap copy repeats, and app icons can disappear after resize.

## 2. Evidence

User screenshots showed a tiny month heatmap, a fifth row sliver in monthly
ranking, `wallpaperui` with mismatched visuals, language selection not changing
software names, repeated period/keyword copy, and icon blanks after resize.

## 3. Root cause

- Immediate cause: fixed-size heatmap/ranking delegates, missing Wallpaper
  Engine identity metadata, no language-mode display helper, duplicate recap
  keyword selection, and icon fallback text hidden while Image was Loading.
- Underlying cause: app visual identity logic was split between C++ metadata and
  QML helpers, and resize-triggered icon reload states were not treated as
  displayable fallback states.
- Why the harness/checklists did not prevent it: existing checks catch QML
  warnings/build failures, not visual density/name/color regressions.

## 4. Fix

- Files changed: stats page, app visual helpers, Memory Lake/Home/Profile QML,
  app adapters, usage stats manager, daily card service, desktop shell.
- Short description: expanded/colorized heatmap, capped rankings, added
  Wallpaper Engine metadata, language-aware app names, nonblank icon fallbacks,
  and nonrepeating recap keywords.
- Commit: `9ce6f0b`, `e23ecbe`, `a5d519d`, `f26207f`, `10405f6`

## 5. Prevention

One-off UI regressions; no harness change needed beyond runtime Qt log scan.
