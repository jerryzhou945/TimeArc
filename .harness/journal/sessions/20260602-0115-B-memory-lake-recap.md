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
