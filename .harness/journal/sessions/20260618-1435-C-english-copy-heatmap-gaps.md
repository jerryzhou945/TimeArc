# C Debug: English copy and heatmap gaps

Goal: Remove remaining English-mode Chinese copy on Home/Settings/Stats and
make the monthly stats heatmap fill its card with hover day/hour details.

Related error report(s):
- `.harness/journal/errors/20260618-063537-C-english-copy-heatmap-gaps.md`

Expected touch points:
- `qml/desktop/components/I18n.js`
- `qml/desktop/memorylake/MemoryCard.qml`
- `qml/desktop/memorylake/TimeRiver.qml`
- `qml/desktop/pages/DesktopProfilePage.qml`
- `qml/desktop/pages/DesktopStatsPage.qml`

Avoided touch points:
- Frozen files, service data contracts, and CMake files.

Initial evidence:
- User screenshots show Chinese in Home theme suggestion chips, card backs /
  right-side timeline, Settings privacy row title, and monthly Stats insights.
- Monthly activity heatmap is visually sparse and lacks hover detail.

Hypothesis:
- Remaining copy is generated value text, chip values, and local model labels
  not normalized before passing through `I18n.t()`.
- Heatmap card uses a compact fixed cell size rather than filling available
  card space, and it lacks hover overlay text.

Verification plan:
- Search the target QML files for direct Chinese bindings in the reported areas.
- Build through `.harness/tools/build.py`, run a hidden app smoke launch, scan
  Qt logs, run `timearc_db_smoke`, and run `harness_check.py` before commit.

Root cause:
- Dynamic backend strings cannot be translated by exact-key dictionary lookup
  alone.
- Home card backs, the locked right-side time river, and stats insight cards
  still displayed generated strings directly.
- The monthly heatmap capped square size and centered the grid, leaving large
  unused card space.

Fix summary:
- Added `I18n.smartText()` for generated Home/Stats phrases and short values.
- Routed card-back, detail, time-river, conclusion chip, and stats
  insight/recommendation text through language helpers.
- Added date keys and hover tooltip text to monthly heatmap cells.
- Changed heatmap cells to fill available card width/height and show day numbers
  when cells are large enough.

Verification:
- First build failed because `TimeArc.exe` was locked by a running process.
- After stopping the process, `.harness/tools/build.py` passed.
- Hidden `build/TimeArc.exe` smoke launch ran, followed by `scan_qt_log.py`
  reporting no harness Qt log.
- `build/timearc_db_smoke.exe` exited with code 0.
