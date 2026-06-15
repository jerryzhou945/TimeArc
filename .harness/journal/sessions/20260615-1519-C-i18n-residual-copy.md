# C Debug: residual English-mode copy

Goal: Remove Chinese residual text and duplicated hints still visible in
English mode across home, calendar, stats, settings, and memo overlay.

Related error report(s):
- `.harness/journal/errors/20260615-072004-C-i18n-residual-chinese-copy.md`
- `.harness/journal/errors/20260615-072042-C-powershell-angle-filter.md`

Expected touch points:
- `qml/desktop/components/I18n.js`
- `qml/desktop/pages/DesktopHomePage.qml`
- `qml/desktop/pages/DesktopCalenderPage.qml`
- `qml/desktop/pages/DesktopStatsPage.qml`
- `qml/desktop/pages/DesktopProfilePage.qml`
- `qml/desktop/memorylake/*.qml`

Avoided touch points:
- Frozen data-contract files, C++ service files, top-level CMake files.

Initial evidence:
- User screenshots show Chinese residual copy in English mode on home summary,
  calendar selected date/tabs, stats week labels and insight text, settings
  subsections, and memo notes/sidebar/hints.
- Home and memo each show duplicated instructional hint text.

Hypothesis:
- Some visible strings still bypass `I18n.t/sentence`, especially dynamic date
  formatting, generated summaries, settings helper copy, hotkey rows, and memo
  sticky-note chrome. Duplicate hints come from old and new hint delegates both
  staying visible after the previous i18n pass.

Verification plan:
- Add a narrow static regression scan for common Chinese strings in the touched
  QML surfaces when `languageMode` is wired.
- Build through `.harness/tools/build.py`, run the app briefly, scan Qt logs,
  and run `harness_check.py` before commits.

Root cause:
- Residual English-mode Chinese text lived in dynamic QML helpers and local
  component chrome rather than the shared dictionary.
- The home carousel allowed the wheel hint and hover hint to overlap.
- A memo combo popup warning was exposed during runtime log scanning because a
  delegate referenced the popup id outside its QML scope.

Fix summary:
- Added missing English dictionary entries and sentence templates for home,
  calendar, stats, settings, import/export, memo, Pomodoro, and hotkey surfaces.
- Wired `languageMode` through today conclusion, calendar sync, TagChip, sticky
  notes, memo page folder, memo date picker, and text layer creation paths.
- Translated calendar/stat date labels and generated insight strings.
- Made carousel hint visibility mutually exclusive.
- Fixed `GlassComboBox` popup closing through a root method.

Verification:
- `python .harness/tools/build.py` passed twice after the QML changes.
- Hidden `build/TimeArc.exe` smoke launch exited with code 0.
- `python .harness/tools/scan_qt_log.py` reported no harness Qt log after the
  second smoke run.
- `build/timearc_db_smoke.exe` exited with code 0.
