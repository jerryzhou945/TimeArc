# Error Report - english-copy-heatmap-gaps

## Metadata

- Level: **L2**
- Track: **C**
- Topic: english-copy-heatmap-gaps
- Recorded: 2026-06-18T06:35:37Z
- Session: (unknown)
- Platform: n-a
- Tooling: Qt 6/QML, PowerShell Select-String, harness build/log scan

## 1. What happened

English mode still shows Chinese in Home card backs/timeline, Settings privacy text, and monthly Stats insight/suggestions; monthly heatmap is too sparse and lacks hover day/hour details.

## 2. Evidence

```
User screenshots showed:
- Home today theme and conclusion still rendering "约 54m" and suggestion
  value "继续保持" in English mode.
- Home flipped card back and right-side time river still using Chinese copy.
- Settings privacy row title "隐藏敏感窗口标题" remained Chinese.
- Monthly Stats insight/suggestions retained Chinese in some generated text.
- Monthly heatmap occupied only a small centered cluster and had no hover detail.
```

## 3. Root cause

- Immediate cause: Generated text (`mood`, `analysis`, chip values, time-river
  labels, and stats fallback strings) was rendered directly or translated only
  by exact dictionary lookup.
- Underlying cause: Dynamic Chinese sentence templates need normalization, not
  only static dictionary keys.
- Why the harness/checklists did not prevent it: There is no English-mode visual
  residual scan or hover-state QA gate for these QML surfaces.

## 4. Fix

- Files changed: `qml/desktop/components/I18n.js`,
  `qml/desktop/memorylake/MemoryCard.qml`,
  `qml/desktop/memorylake/DetailPanel.qml`,
  `qml/desktop/memorylake/TimeRiver.qml`,
  `qml/desktop/memorylake/TodayConclusionCard.qml`,
  `qml/desktop/pages/DesktopMemoryLakePage.qml`,
  `qml/desktop/pages/DesktopStatsPage.qml`.
- Short description: Added `I18n.smartText()` for generated Chinese phrases,
  routed Home card backs/timeline/detail text through it, added missing settings
  translations, guarded Stats insight/recommendation rendering, and expanded the
  monthly heatmap with per-cell hover tooltip text.
- Commit: pending

## 5. Prevention

One-off fix. A future visual smoke script should capture English-mode Home,
Settings, and monthly Stats screenshots including hover states.
