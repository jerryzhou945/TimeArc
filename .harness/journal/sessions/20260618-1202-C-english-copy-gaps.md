# C Debug: English copy gaps

Goal: Remove remaining Chinese text shown while the desktop UI is in English
language mode.

Related error report(s):
- `.harness/journal/errors/20260618-040322-C-english-copy-gaps.md`
- `.harness/journal/errors/20260618-040303-C-stale-skill-cache-path.md`
- `.harness/journal/errors/20260618-040414-C-rg-access-denied.md`
- `.harness/journal/errors/20260618-040554-C-powershell-quote-pattern.md`
- `.harness/journal/errors/20260618-041156-C-qt-warning-f8277923d2.md`
- `.harness/journal/errors/20260618-041158-C-qt-warning-d5e39ad0f2.md`

Expected touch points:
- `qml/desktop/components/I18n.js`
- `qml/desktop/pages/DesktopMemoryLakePage.qml`
- `qml/desktop/pages/DesktopCalenderPage.qml`
- `qml/desktop/pages/DesktopStatsPage.qml`
- `qml/desktop/pages/DesktopProfilePage.qml`
- `qml/desktop/memorylake/*.qml`

Avoided touch points:
- Frozen data-contract files, service code, and CMake files.

Initial evidence:
- User reports English mode still shows Chinese in Home theme and suggestion
  cards, Calendar right-side tab/photo/anniversary labels, Stats period icons,
  and Settings language/about/license areas.

Hypothesis:
- Remaining strings are local model labels, dynamic generated values, or compact
  icon labels that were not routed through `I18n.t()` in the previous pass.

Verification plan:
- Scan touched QML for the reported Chinese terms and route user-facing values
  through existing language helpers.
- Build through `.harness/tools/build.py`, run a brief app smoke test, scan Qt
  logs, and run `harness_check.py` before committing.

Root cause:
- Dynamic phrases such as "社交为主" were not dictionary keys.
- Calendar, stats, home chart labels, and settings license details still had
  local model labels rendered directly.
- A smoke run exposed the existing combo delegate scope issue again: delegate
  code could not safely reference outer ids.

Fix summary:
- Added English translations for photo actions and license/about details.
- Routed home category labels, theme phrases, calendar segment labels, stats
  period glyphs, and recap orbit labels through language helpers.
- Changed `GlassComboBox` delegates to call a `ListView.view` activation
  method instead of referencing outer ids.

Verification:
- `python .harness/tools/build.py` passed after the i18n patch and after the
  combo warning fix.
- Hidden `build/TimeArc.exe` smoke launch exited with code 0.
- Final `python .harness/tools/scan_qt_log.py` reported no harness Qt log.
- `build/timearc_db_smoke.exe` exited with code 0.
