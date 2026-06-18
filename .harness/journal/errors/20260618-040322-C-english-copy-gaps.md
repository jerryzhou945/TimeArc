# Error Report - english-copy-gaps

## Metadata

- Level: **L2**
- Track: **C**
- Topic: english-copy-gaps
- Recorded: 2026-06-18T04:03:22Z
- Session: (unknown)
- Platform: n-a
- Tooling: Qt 6/QML, PowerShell Select-String, harness build/log scan

## 1. What happened

English language mode still shows Chinese copy in home theme/suggestions, calendar tabs/photo/anniversary labels, stats period icons, settings language/about/license labels.

## 2. Evidence

```
User reported English mode still showing Chinese in:
- Home today's theme such as "社交为主" and main theme suggestion text.
- Calendar right-side photo action and tabs "待办 / 记录 / 纪念".
- Stats left period icon glyphs "周 / 月 / 年".
- Settings Language & Time icon plus About/License text.
```

## 3. Root cause

- Immediate cause: Remaining dynamic labels and compact glyphs bypassed
  `I18n.t()` or only translated exact dictionary keys, so composed text like
  "社交为主" did not resolve in English.
- Underlying cause: Previous i18n pass covered larger copy blocks but missed
  local model labels, generated theme phrases, and license card details.
- Why the harness/checklists did not prevent it: There is no visual or static
  English-mode residual-Chinese gate for QML yet.

## 4. Fix

- Files changed: `qml/desktop/components/I18n.js`,
  `qml/desktop/pages/DesktopHomePage.qml`,
  `qml/desktop/pages/DesktopMemoryLakePage.qml`,
  `qml/desktop/pages/DesktopCalenderPage.qml`,
  `qml/desktop/pages/DesktopStatsPage.qml`,
  `qml/desktop/pages/DesktopProfilePage.qml`,
  `qml/desktop/memorylake/TodayConclusionCard.qml`,
  `qml/desktop/memorylake/RecapSlide.qml`.
- Short description: Added missing English strings and routed theme phrases,
  calendar tabs/photo actions, stats glyphs, home category labels, and
  about/license copy through language helpers.
- Commit: pending

## 5. Prevention

Future harness improvement: add a targeted English-mode QML residual scan for
known user-facing text bindings. One-off for this patch.
