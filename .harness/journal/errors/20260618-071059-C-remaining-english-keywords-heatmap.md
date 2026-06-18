# Error Report - remaining-english-keywords-heatmap

## Metadata

- Level: **L2**
- Track: **C**
- Topic: remaining-english-keywords-heatmap
- Recorded: 2026-06-18T07:10:59Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

English mode still shows Chinese generated keywords/card-back text and monthly heatmap is visually too harsh/sparse

## 2. Evidence

```
午间使用 => 午间使用
微信 今天使用 about 31m，主要在中午，单次最长 5m，共打开 16次。 => 微信 今天使用 about 31m，主要在中午，单次最长 5m，共打开 16次。
年后 => 年后
下午使用 => 下午使用
沟通 => 沟通
日常 => 日常
```

## 3. Root cause

- Immediate cause: `I18n.smartText()` did not cover the generated short mood
  labels, card-back "single longest/opened N times" template, or keyword chips.
- Underlying cause: generated strings are assembled by local recap services with
  Chinese fallback templates, then rendered in several QML surfaces.
- Why the harness/checklists did not prevent it: no helper-level regression
  check existed for generated English-mode text.

## 4. Fix

- Files changed: `qml/desktop/components/I18n.js`,
  `qml/desktop/pages/DesktopStatsPage.qml`.
- Short description: added missing English mappings and generated-sentence
  regexes, routed keyword chips through `smartText`, and softened/rebalanced
  monthly heatmap color/layout.
- Commit: pending.

## 5. Prevention

Add a small helper-level i18n regression script for known generated recap
sentences.
