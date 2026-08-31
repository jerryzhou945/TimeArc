# Error Report - stats-clock-color-mismatch

## Metadata

- Level: **L2**
- Track: **C**
- Topic: stats-clock-color-mismatch
- Recorded: 2026-08-29T20:37:37Z
- Session: .harness/journal/sessions/20260829-1538-C-stats-clock-colors.md
- Platform: windows
- Tooling: (fill in)

## 1. What happened

The category clock uses app-derived category colors while the adjacent category-share labels use a ranked theme palette, so identical categories render with different colors.

## 2. Evidence

```
Screenshot: C:/Users/cangc/AppData/Local/Temp/codex-clipboard-36e222ea-300c-4f2c-8d1b-16a735fa8d59.png
Left clock: DesktopStatsPage.qml uses categoryHeatBase(category), derived from app/category colors.
Right labels: DailyUsageShare.qml assigns aqua/violet/gold/pink by share rank.
The same browsing/video/social categories therefore display different colors side by side.
TDD: `node tests/stats_view_model_test.js` failed before implementation and passes after both color-map and transient-fallback fixes.
Runtime: the final Qt scan no longer reports `DailyUsageShare.qml` undefined QColor warnings.
```

## 3. Root cause

- Immediate cause: adjacent visualizations calculate category colors independently.
- Underlying cause: `DailyUsageShare` keeps its ranked palette mapping private, so the clock cannot reuse the colors users actually see in the right-hand legend.
- Why the harness/checklists did not prevent it: existing tests cover ring geometry and layout presence, not cross-component category-color consistency.

## 4. Fix

- Files changed: `qml/desktop/components/AppVisual.js`, `qml/desktop/memorylake/DailyUsageShare.qml`, `qml/desktop/pages/DesktopStatsPage.qml`, `tests/stats_view_model_test.js`
- Short description: expose one ranked category-color map from the share panel, consume it in the clock, and provide a deterministic same-palette fallback during QML binding updates.
- Commit: pending commit

## 5. Prevention

Add behavioral coverage for ranked category-color mapping and retain targeted runtime visual verification; no harness change needed.
