# C Debug: remaining English keywords and heatmap polish

Goal: remove the remaining Chinese generated copy in English mode and soften the monthly heatmap layout.

Related error report(s):
- `errors/20260618-071059-C-remaining-english-keywords-heatmap.md`
- `errors/20260618-071559-C-remaining-english-heatmap-build-failure.md`
- `errors/20260618-071924-C-qt-warning-60b8e32bf0.md`
- `errors/20260618-071943-C-harness-check-session-link.md`
- `errors/20260618-072007-C-get-process-no-timearc-after-scan.md`

Expected touch points:
- `qml/desktop/components/I18n.js`
- `qml/desktop/pages/DesktopStatsPage.qml`
- this session/error journal

Do not touch:
- service/data-contract files
- frozen CMake/schema/header files

Evidence:
- English mode still rendered generated phrases such as `午间使用`, `主要在社交`, and keyword chips such as `年后` / `下午使用`.
- A Node harness against `I18n.smartText("en", ...)` reproduced the leak before code changes.

Hypothesis:
- Generated recap strings use additional templates not covered by the previous `smartText()` regexes, while monthly keyword chips call only `tr()`.
- The heatmap is readable but too saturated and mechanically packed; color and spacing can be softened without changing data.

Fix:
- Added `I18n.smartText()` coverage for mood labels, keyword chips, and
  card-back generated templates with app name translation.
- Reworked monthly stats heatmap into softer, centered, near-square cells with
  lower-saturation category colors and hover scaling.

Verification:
- Node helper regression for the reported generated strings passed.
- `python .harness/tools/build.py` passed after stopping PID 24696.
- Hidden GUI smoke ran; `scan_qt_log.py` captured an unrelated clipboard retry
  warning for the local hidden launch.
