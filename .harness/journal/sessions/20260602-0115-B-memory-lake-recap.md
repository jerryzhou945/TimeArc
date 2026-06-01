# Goal

1:1 port the `MemoryLakeDesign/memory_lake_v25_win11_style.html` prototype (layout,
lighting, animation, interaction) into the Memory Lake page placeholder
`qml/desktop/pages/DesktopMemoryLakePage.qml`. Follow
`docs/memory-lake-implementation-plan.md` and record fidelity gaps in
`docs/memory-lake-fidelity-gaps.md`.

Locked decisions: inner three-panel only (drop the fake Win11 desktop/taskbar/titlebar);
demo data first, real data later; follow day/night theme.

# Design

Service side: no service behavior changes. The background sampler keeps emitting the
same disk journal / live snapshot contract. Phase 1–4 use mock data only, so nothing
crosses the UI/service seam yet. Real-data wiring (phase E) will only *read* existing
read-only `UsageStatManager` / `FrontmostSessionRepository` interfaces — no schema or
`data_bridge.h` change — and is deferred to a follow-up because it needs new C++
aggregation (per-day month series, last-month compare, cover-art strategy, local
keyword templates). Those are logged in `state/open-issues.md`.

UI side: rewrite the Memory Lake page into a three-panel "memory lake" (left ranking,
center flip-card carousel, right detail + time river) plus an 11-slide monthly recap
overlay, with glass/neon lighting via `QtQuick.Effects` MultiEffect, silky scrolling
(custom Flickable + neon scrollbar + edge bounce), and smooth flip/transition
animations. New page-private components live under `qml/desktop/memorylake/`. All
components honor the existing theme contract (`nightMode`, `themeText*`, etc.).

# Scope

Expected touches: `qml/desktop/pages/DesktopMemoryLakePage.qml`, new
`qml/desktop/memorylake/*`, `qml/CMakeLists.txt`, docs, this journal.

Rules touched: `rules/04-ui-conventions.md` (no claim change expected),
`rules/07-product-ai-cards.md` §6 (docs updated). No frozen files, no service code,
no schema, no `data_bridge.h`.

Avoid: fake desktop chrome, IPC, new third-party deps, AI over raw logs, unrelated
refactors.

# Outcome

(filled per phase)

- Phase A — skeleton + three-panel static layout + lighting base + theme.
  New `qml/desktop/memorylake/`: `MemoryLakeMock.js` (1:1 demo data), `MemoryLakeStyle.qml`
  (day/night palette), `GlassPanel.qml`, `GlowCircle.qml` (blurred radial glow via
  MultiEffect), `AmbientBackground.qml` (stage bg + blurred app image + corner glows),
  `UsageRankList.qml`. Rewrote `DesktopMemoryLakePage.qml` into three glass panels (left
  ranking fully populated, center cards-zone placeholder, right detail/time-river static),
  honoring the theme contract. Registered new QML files + 5 card PNGs in CMake.
  Smoke: `cmake --build build` links clean (qmlcachegen compiles all new files); app
  launches without QML errors. Center carousel + right time-river follow in phase B.

- Phase B — card carousel interaction + detail + time river.
  New components: `MemoryCard.qml` (Flipable Y-axis 3D flip .68s bezier, selected
  resize, hover preview), `CardCarousel.qml` (horizontal track, analytic center
  offset with .42s bezier, throttled wheel switch, flip-lock + lock badge + dynamic
  wheel-tip), `TimeRiver.qml` (axis/nodes/ripples/labels/ruler following current app),
  `DetailPanel.qml` (follows current app). Wired into the page: shared selectedIndex /
  flippedIndex / previewIndex state with selectCard()/toggleFlip(); ranking ↔ carousel
  selection + hover preview synced; flip locks ranking + wheel + other cards; ambient
  bg + detail + time-river all follow the current card.
  Verify: qmlcachegen compiles; `qmllint` clean (only ComponentBehavior info, no
  errors); loaded the page in the `qml` runtime — zero stderr / no load errors.
  (Win32 screenshot automation was unreliable in this environment; visual pass is to be
  confirmed via `run.cmd`.)

- Phase C — silky scroll. New `SilkyFlickable.qml`: eased mouse-wheel scrolling
  (NumberAnimation toward target, ~lerp feel), edge bounce (Translate on content via
  SequentialAnimation), and a thin neon `ScrollBar`. Converted the ranking list
  (`UsageRankList`) from `ListView` to `SilkyFlickable` + Column + Repeater — the real
  scroll surface. Left/right panels stay fit-to-height in the embedded layout (no
  overflow), avoiding redundant nested scrollbars; the recap inner scroll (phase D)
  will reuse SilkyFlickable. Verified: qmllint clean, build clean, page loads in qml
  runtime with no errors.

- Phase D — monthly recap overlay. New `RecapSlide.qml` (per-type layouts: cover /
  monthMap / poster / split / orbit / article / timeline / trend(Canvas line) /
  keywords / comparison / ticket; entrance transforms zoom/wipe/rise/rotate/ticket via
  ParallelAnimation; inner SilkyFlickable scroll) and `RecapOverlay.qml` (dark shell,
  blurred bg-app following slide, flowing wave + bottom glow ring, topbar with
  pause/close, mode note, stage + step directory that unlocks after the story is seen,
  progress bar, autoplay 3.2s/4.2s, click-to-advance, wheel/arrow/ESC nav). Wired the
  left CTA to `recap.open()`; overlay covers the three panels.
  Fixed a real bug qmllint caught: `property var data` shadowed Item's default `data`
  property → renamed to `slideData`. Verified: qmllint clean (only ComponentBehavior
  info), build clean, page (incl. all 11 instantiated slides) loads in the qml runtime
  with zero errors. Win32 screenshot capture remained unreliable in this environment;
  visual pass to be confirmed via `run.cmd`.

- Phase E — real-data wiring: **deferred** per the locked "demo data first" decision.
  It needs new read-only C++ aggregation (per-day month series, last-month compare,
  cover-art strategy, local mood/keyword templates) with no schema change; logged in
  `state/open-issues.md` as the phase-E follow-up.

- Phase F — finalize. Updated `docs/memory-lake-implementation-plan.md` progress,
  `docs/memory-lake-fidelity-gaps.md`, `README.md` (Memory Lake bullet now describes the
  new usage-memory view + recap), and `state/open-issues.md` (placeholder resolved +
  phase-E follow-up). `harness_check.py`: clean (7 passes).

# Smoke path

Build `cmake --build build` → launch `run.cmd` → click "记忆湖" in the left nav. Expect:
three-panel memory lake with the app ranking, center flip-card carousel, and right
detail + time river. Scroll the ranking (eased + neon bar + edge bounce). Wheel/click to
switch the center card; click the center card to flip (locks switching; lock badge +
note appear). Click "查看月度记忆回顾" → the recap overlay opens and auto-plays 11 slides;
click to advance, pause/resume, and after the last slide the right step directory unlocks
for wheel/arrow/click navigation; "返回湖面"/ESC closes. Headless verification this
session: qmlcachegen build + qmllint + `qml` runtime load all clean (no GUI driver to
click through in this environment).
