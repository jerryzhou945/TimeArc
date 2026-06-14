# Error Report - ui-app-label-icon-card-regressions

## Metadata

- Level: **L2**
- Track: **C**
- Topic: ui-app-label-icon-card-regressions
- Recorded: 2026-06-14T09:08:51Z
- Session: (unknown)
- Platform: Windows desktop / Qt Quick
- Tooling: `.local-python\Python312\python.exe .harness/tools/build.py`, `timearc_db_smoke`, QML inspection

## 1. What happened

User-reported UI regressions: non-friendly app names, home overlay blocking cards, light sidebar icons white, missing app icons in Memory Lake/statistics, heatmap/monthly stats layout overflow

## 2. Evidence

```
Repro from user report:
1. Some common apps still show process-style names, e.g. WeChat/JianyingPro.
2. Memory Lake card carousel keeps the "wheel/rank/hover preview" tip visible over cards.
3. Desktop sidebar uses white icons in day mode on full-bleed pages.
4. Memory Lake and statistics sometimes show missing icons instead of fallback initials.
5. Statistics month view heatmap is not GitHub-style, ranking row 4/5 is clipped, and insight/recommendation text can overflow the card.

Baseline build before edits:
`.local-python\Python312\python.exe .harness/tools/build.py` -> success,
log `.harness/journal/build-logs/20260614-170956-build.log`.
```

## 3. Root cause

- Immediate cause: adapter names were incomplete; CardCarousel kept the wheel tip always visible; DesktopAppShell tied white nav icons to full-bleed pages instead of night mode; AppIconImageProvider returned transparent pixmaps on misses; stats month cards used fixed heights and a date-number heatmap.
- Underlying cause: visual fallback states were spread across C++ metadata, image provider behavior, and QML layout code without one regression checklist.
- Why the harness/checklists did not prevent it: no focused UI regression check currently covers these visual/layout states.

## 4. Fix

- Files changed: `src/services/adapters/*`, `src/services/usage_stat_manager.cpp`, `src/services/app_icon_image_provider.*`, `qml/desktop/*`, `tests/db_smoke.cpp`, `docs/ui-app-polish-regressions-report.md`.
- Short description: added friendly app mappings, auto-hid the Memory Lake card tip, fixed day-mode sidebar icons, restored icon fallback behavior, rebuilt the monthly stats heatmap/layout, and fixed runtime warnings found during verification.
- Commit: `5c8e939`, `bbae8d1`, `d8b4b81`, `f023587`, `f369f1f`, plus final cleanup/docs commit `Fix runtime UI verification warnings`.

## 5. Prevention

One-off UI regression batch; prevention is the added `timearc_db_smoke` coverage for friendly app names plus the Chinese report documenting the manual visual states to check.
