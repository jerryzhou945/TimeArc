# Goal

Refine the Memory Lake 1:1 port (`feat/memory-lake-1to1`, phases A–F) so it matches the
**v25 win11 override layer** of `MemoryLakeDesign/memory_lake_v25_win11_style.html`
(CSS lines ~1514–2089 — the authoritative `--ml-*` skin with `!important`), which the
audit found is the true target. Close the validated fidelity gaps, in priority order.

# Design

Service side: **no change.** Pure UI fidelity work on mock data; nothing crosses the
UI/service seam. No schema, no `data_bridge.h`, no `src/service/` edits. Phase-E
real-data wiring stays deferred (see `state/open-issues.md`).

UI side: edit only `qml/desktop/memorylake/*` and `DesktopMemoryLakePage.qml` to align
geometry/animation/lighting with the v25 skin. No new components expected; no new deps.
Honor the existing theme contract. Keep the honest gap doc accurate.

# Scope

Expected touches: `qml/desktop/memorylake/RecapOverlay.qml`, `RecapSlide.qml`,
`MemoryCard.qml`, `CardCarousel.qml`, `TimeRiver.qml`, `AmbientBackground.qml`,
`UsageRankList.qml`, `SilkyFlickable.qml`, `DetailPanel.qml`, page root, and possibly
`docs/memory-lake-fidelity-gaps.md`. Rules touched: `rules/04-ui-conventions.md` (no
claim change). No frozen files.

Avoid: fake desktop chrome, IPC, new third-party deps, AI over raw logs, unrelated
refactors, touching the palette tokens that already match v25 (#9FE7EE/#9B8BFF/#D88AAC).

# Validated gaps (against v25, source of truth)

HIGH (silky/lighting hard requirements):
- Recap open/close is flat: missing staggered bloom (shell translateY(28)+blur(10→0)
  .58s; glow-ring scale(.82→1) .72s; wave opacity(0→.74)+skew+translateX .78s; delays
  topbar .08 / stage .16 / side .22 / progressbar+hint .28s) — `RecapOverlay.qml`.
- Recap slides pop in flat: per-slide hero entrance (recapRise --d cascade, posterReveal,
  appCardHero, stripSlide, orbitPop) absent — `RecapSlide.qml`.
- Silky scroll: scrollbar fades on `active` (should persist); bounce direction/duration —
  `SilkyFlickable.qml`.
- usage-item hover translateX(2px)+bg/border missing — `UsageRankList.qml`.

MED (geometry/lighting):
- Selected card 330×455/flip380/translateY(-10)/scale1.0 vs v25 310×440/flip360/
  translateY(-6)/scale1.01; card-img 205 vs 196; face radius 26 vs 28; centerOffset drift —
  `MemoryCard.qml` + `CardCarousel.qml`.
- TimeRiver: axis x 46 vs 52; axis gradient 1-stop vs 3-stop rgba(133,237,255,.38);
  node/dot/ripple glows missing; node colors too white vs rgba(159,231,238,.84)→
  rgba(155,139,255,.66) — `TimeRiver.qml`.
- Ambient big-bg blur 64px vs 42px; opacity .32 vs .34 — `AmbientBackground.qml`.
- Overview ::after "查看月度总结" hint + hover lift(-1px) missing — page root.

LOW: detail analysis line-height 1.35 vs 1.6; node label 12 vs 11px; recap-launching
CTA pulse; assorted radii.

# Outcome

Aligned the port to the v25 `!important` override layer (the true target). Edited 10
`qml/desktop/memorylake/*` files only (no service/schema/frozen changes):
- RecapOverlay: staggered open bloom (shell translate/scale, glow-ring, wave, topbar .08/
  stage .16/side .22/progress .28s); recap bg blur 64→42px. (blur(10→0) approximated.)
- RecapSlide: `recapRise` content cascade + `playing` trigger (fixes first-slide replay).
- MemoryCard/CardCarousel: v25 geometry (310×440 / flip 360 / -6 lift / 1.01 / img 196 /
  radius 28) + centerOffset fix; stage radius 26.
- TimeRiver: axis 46→52, 3-stop axis gradient, 2px node lines (was 12px), v25 node colors,
  dot glow approximation, 11px labels, wrap radius 20.
- UsageRankList: hover translateX(2px) + border. AmbientBackground/Style: bg blur 42px,
  opacity .34, scale 1.18. DetailPanel: analysis line-height 1.6.
- **SilkyFlickable: replaced Controls ScrollBar with a hand-drawn Rectangle scrollbar** —
  the native Windows Controls style ignored the custom contentItem (the neon scrollbar
  wasn't rendering + flooded "style does not support customization" warnings). Now renders
  + draggable + warning class gone.

Deviations kept honest in `docs/memory-lake-fidelity-gaps.md` (per-item recap micro-cascade
not done — block recapRise only; node glows approximated; overview ::after hint intentionally
omitted — vestigial in v25).

Verify: 4× `build.py` clean. Memory Lake three-panel page (incl. thin glowing time-river)
screenshot-confirmed rendering. `scan_qt_log.py`: warnings are pre-existing (native-style
ScrollBar incl. DesktopCalenderPage, DesktopStatsPage:841 index ReferenceError) — **none from
this session's code**. Recap-open state + new scrollbar not screenshot-confirmed (Win32 input
automation unreliable here, as prior journal noted); pixel pass pending via `run.cmd`.

# Smoke path

Track-B preflight (done, clean) → `python .harness/tools/build.py` → `run.cmd` → click
"记忆湖". Compare each slice to the v25 design: card sizing/centering, time-river glow,
ranking hover + scroll feel, recap open bloom + per-slide entrance. `scan_qt_log.py`
after each run; `harness_check.py` before commit.
