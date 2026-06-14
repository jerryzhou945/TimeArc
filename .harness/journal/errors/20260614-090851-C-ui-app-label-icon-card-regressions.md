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

- Immediate cause: under investigation; likely split across adapter display names, icon-source fallback, full-bleed nav icon selection, and fixed-height QML cards.
- Underlying cause: under investigation.
- Why the harness/checklists did not prevent it: no focused UI regression check currently covers these visual/layout states.

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.
