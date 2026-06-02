# Goal

1:1 port the `MemoryLakeDesign/memory_lake_v25_win11_style.html` prototype (layout,
lighting, animation, interaction) into the Memory Lake page placeholder
`qml/desktop/pages/DesktopMemoryLakePage.qml`. Follow
`docs/memory-lake-implementation-plan.md`; record fidelity gaps in
`docs/memory-lake-fidelity-gaps.md`.

Locked decisions: inner three-panel only (drop the fake Win11 desktop/taskbar/titlebar);
demo data first, real data later; follow day/night theme.

# Design

Service side: no service behavior changes. Same disk journal / live snapshot contract.
Phases 1–4 use mock data, so nothing crosses the UI/service seam yet. Real-data wiring
(phase E) will only *read* existing read-only `UsageStatManager` /
`FrontmostSessionRepository` — no schema or `data_bridge.h` change — deferred to a
follow-up needing new C++ aggregation (per-day month series, last-month compare,
cover-art strategy, local keyword templates). Logged in `state/open-issues.md`.

UI side: rewrite the page into a three-panel "memory lake" (left ranking, center
flip-card carousel, right detail + time river) plus an 11-slide monthly recap overlay,
with glass/neon lighting via `QtQuick.Effects` MultiEffect, silky scrolling (custom
Flickable + neon scrollbar + edge bounce), and smooth flip/transition animations. New
page-private components live under `qml/desktop/memorylake/`. All honor the existing
theme contract (`nightMode`, `themeText*`, etc.).

# Scope

Expected touches: `qml/desktop/pages/DesktopMemoryLakePage.qml`, new
`qml/desktop/memorylake/*`, `qml/CMakeLists.txt`, docs, this journal. Rules touched:
`rules/04-ui-conventions.md` (no claim change), `rules/07-product-ai-cards.md` §6 (docs).
No frozen files, no service code, no schema, no `data_bridge.h`. Avoid: fake desktop
chrome, IPC, new third-party deps, AI over raw logs, unrelated refactors.

# Outcome

- Phase A — skeleton + three-panel static layout + lighting base + theme. New
  `qml/desktop/memorylake/`: `MemoryLakeMock.js` (1:1 demo data), `MemoryLakeStyle.qml`
  (day/night palette), `GlassPanel.qml`, `GlowCircle.qml` (blurred radial glow),
  `AmbientBackground.qml` (stage bg + blurred app image + corner glows), `UsageRankList.qml`.
  Rewrote the page into three glass panels honoring the theme contract. Registered new
  QML + 5 card PNGs in CMake. Smoke: build links clean (qmlcachegen), app loads no QML errors.

- Phase B — card carousel + detail + time river. New `MemoryCard.qml` (Flipable Y-axis
  3D flip .68s bezier, selected resize, hover preview), `CardCarousel.qml` (horizontal
  track, analytic center offset .42s bezier, throttled wheel switch, flip-lock + badge +
  dynamic wheel-tip), `TimeRiver.qml`, `DetailPanel.qml`. Wired shared selectedIndex /
  flippedIndex / previewIndex with selectCard()/toggleFlip(); ranking ↔ carousel synced;
  flip locks ranking + wheel + other cards; ambient bg + detail + river follow the card.
  Verify: qmlcachegen + qmllint clean (only ComponentBehavior info); page loads in `qml`
  runtime with zero stderr. (Win32 screenshot automation unreliable; visual pass via `run.cmd`.)

- Phase C — silky scroll. New `SilkyFlickable.qml`: eased wheel scroll (NumberAnimation
  toward target), edge bounce (Translate via SequentialAnimation), thin neon `ScrollBar`.
  Converted the ranking list to SilkyFlickable + Column + Repeater. Left/right panels stay
  fit-to-height (no nested scrollbars); recap inner scroll reuses SilkyFlickable. Verified:
  qmllint + build clean, page loads no errors.

- Phase D — monthly recap overlay. New `RecapSlide.qml` (per-type layouts cover/monthMap/
  poster/split/orbit/article/timeline/trend(Canvas)/keywords/comparison/ticket; entrance
  transforms zoom/wipe/rise/rotate/ticket via ParallelAnimation; inner SilkyFlickable) and
  `RecapOverlay.qml` (dark shell, blurred bg-app per slide, flowing wave + glow ring, topbar
  pause/close, stage + step directory unlocking after the story is seen, progress bar,
  autoplay 3.2s/4.2s, click-to-advance, wheel/arrow/ESC nav). Left CTA → `recap.open()`.
  Fixed a qmllint bug: `property var data` shadowed Item's default `data` → renamed
  `slideData`. Verified: qmllint clean, build clean, all 11 slides load with zero errors.

- Phase E — real-data wiring: **deferred** per "demo data first". Needs read-only C++
  aggregation (per-day month series, last-month compare, cover-art, local mood/keyword
  templates), no schema change; logged in `state/open-issues.md`.

- Phase F — finalize. Updated `docs/memory-lake-implementation-plan.md`,
  `docs/memory-lake-fidelity-gaps.md`, `README.md`, `state/open-issues.md`.
  `harness_check.py`: clean (7 passes).

# Smoke path

Build → `run.cmd` → click "记忆湖". Expect three-panel memory lake (ranking, center
flip-card carousel, right detail + time river). Scroll the ranking (eased + neon bar +
bounce). Wheel/click to switch the center card; click to flip (locks switching; badge +
note appear). Click "查看月度记忆回顾" → recap overlay opens, auto-plays 11 slides; click
to advance, pause/resume; after the last slide the step directory unlocks for
wheel/arrow/click nav; "返回湖面"/ESC closes. Headless verification this session:
qmlcachegen build + qmllint + `qml` runtime load all clean (no GUI driver to click through).
