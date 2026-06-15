# C Debug: UI stats, Memory Lake, and language follow-ups

Goal: Fix the reported UI regressions in stats heatmap/ranking, Memory Lake
icon/name rendering, app-color backgrounds, English app naming, and duplicate
recap copy without changing the disk data contract.

Related error report(s):
- `.harness/journal/errors/20260615-051224-C-ui-stats-memorylake-language-followups.md`
- `.harness/journal/errors/20260615-051152-C-rg-access-denied.md`

Expected touch points:
- `qml/desktop/pages/DesktopStatsPage.qml`
- `qml/desktop/memorylake/*.qml`
- `qml/desktop/components/AppVisual.js`
- `src/services/usage_stat_manager.cpp`
- `src/services/adapters/apps/*.h`

Avoided touch points:
- Frozen data-contract files, top-level CMake files, service shared ABI files.

Initial evidence:
- User screenshots show an underfilled active heatmap, fifth ranking row sliver,
  mismatched Wallpaper Engine identity/color, duplicate recap hint copy, and
  app icons disappearing after layout resize.

Hypothesis:
- The stats card is using fixed small heatmap cells and an uncapped model height;
  app identity helpers are missing Wallpaper Engine aliases and English display
  mapping; icon delegates hide fallback text during transient loading caused by
  resize-triggered source-size reloads.

Root cause:
- Heatmap cells were capped at 15px and ranking data exposed six rows to a card
  sized for four rows.
- Wallpaper Engine lacked adapter/group metadata, so old rows fell through to
  `wallpaperui` and hashed colors.
- Language mode was persisted but not injected into pages that render app names.
- Recap keywords reused period words already shown as the "main period" stat.
- Icon fallback labels were hidden during `Image.Loading`.

Fix:
- `9ce6f0b` expanded month heatmap layout, capped stats ranking to four rows,
  and added category-colored heat cells.
- `e23ecbe` added Wallpaper Engine metadata and nonblank icon fallbacks.
- `a5d519d` made app display names language-aware for English mode.
- `f26207f` removed repeated recap keyword/period wording.
- `10405f6` fixed a runtime `Window.active` QML warning found during verification.

Verification:
- `python .harness/tools/build.py` failed once because `build/TimeArc.exe` was
  still running; after stopping it, reruns succeeded.
- `python .harness/tools/build.py` -> success (`20260615-133455-build.log`).
- `build/timearc_db_smoke.exe` -> exit 0.
- Launched `build/TimeArc.exe` for 8 seconds and closed it -> exit 0.
- `python .harness/tools/scan_qt_log.py` -> no log.
