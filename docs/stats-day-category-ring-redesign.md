# Stats › Day — Category Ring Redesign

Replace the three-lane `StatsApplicationClock` with a **single denoised
category ring**: drop records that are too short, fold app-level switching into
category runs, and paint one arc per run on one ring.

Track **B** (feature). No frozen file is touched — `CHARTER.md` §3 covers only
`data_bridge.h` / `database_path.*` / `app_info.h` / `app_env.h` / `util.h` /
the three `CMakeLists.txt` / the harness docs.

---

## 1. What exists today

`StatsApplicationClock` — `DesktopStatsPage.qml:1282`, fed by
`StatsViewModel.buildClockSegments()` — `StatsViewModel.js:211`.

```
usageStatManager.foregroundSegmentsForWindow(dayStart, dayEnd)
  → [{ groupKey, appName, path, sessionCount, longestSec,
       adapterCategory, segments: [{ startUnixSec, endUnixSec, seconds }] }]
buildClockSegments(groups, apps, dayStart, half)
  → flatten → clip to AM/PM half → assign lane 0..2 → mark ≤8 icons
Canvas → 3 concentric tracks at radius × 0.54 / 0.63 / 0.72, width × 0.078
```

- 12-hour dial, AM/PM toggle, 60 tick marks, hour numbers 1–12.
- One arc per **app session segment**, stroked with
  `categoryHeatBase(modelCategory(segment))` — so colour is *already* per
  category while identity (icons, hub name) is per app. Mixed message.
- Hover previews, click pins; centre hub shows total or the focused segment.

### Why there are three lanes

Not a design choice — a workaround. `foregroundSegmentsImpl`
(`usage_stat_manager.cpp:705`) merges a group's records across gaps ≤ 60 s:

```
A 10:00–10:05 │ B 10:05–10:06 │ A 10:06–10:10
  → A merges to 10:00–10:10, which now overlaps B's 10:05–10:06
```

Two groups genuinely claim the same instant, so lanes keep them from
overpainting. **Collapsing to one ring means this overlap must be resolved,
not hidden.** That is the central new piece of logic (§3.1).

### Why it needs the redesign

1. Every measured stretch gets an arc regardless of length. A 20-second
   alt-tab is 0.17° — invisible as an arc, yet it still consumes a lane and a
   hit-test slot. Busy days read as static.
2. Lanes cost radial space and make "how much of my day" unreadable: an arc's
   radius carries no meaning, only collision avoidance.
3. The icon heuristic (≤ 8 icons, ≥ 8° span, ≥ 20° apart) is a second layer of
   crowding management on top of lanes.

### Constraint: the donut next door

`DailyUsageShare` ("What made up today") sits in the same Day grid at
`DesktopStatsPage.qml:1090` and is **already a category ring** — proportional,
no time axis, fed by `dailyCardService.memoryLakeDay().usageShare`.

> The redesigned clock must stay a **time-of-day** ring. A proportional
> category donut would duplicate the component beside it.

---

## 2. Decisions (settled)

| # | Decision | Choice |
|---|----------|--------|
| D1 | Dial scope | **Keep 12 h + AM/PM toggle.** 1° = 2 min. Preserves hour numbers, ticks, `clockHalf` state. |
| D2 | "Too short" threshold | **60 s**, matching the backend's own `kMergeGapSec`. Necessary but **not sufficient** — see the legibility floor in §3.3a. |
| D3 | Dropped time | **Absorbed by neighbours.** Ring stays gapless where activity was continuous. |
| D4 | Ring identity | **Category only.** No app icons on the ring; app detail moves to the hover readout and the App Library. |

### The honesty split (follows from D3)

Absorbing a 15 s Slack peek into a 3 h Development block asserts Development
for 15 seconds that were Slack. That is smoothing, and it must not leak into
the numbers. So:

- **Ring geometry** is denoised — a readable shape.
- **Reported numbers** (centre total, legend seconds) come from the
  **unfiltered** `vmApps` / `vmTotalSec`, unchanged, so the ring can never
  contradict the donut beside it.
- The card discloses the smoothing in one footer line (§3.5).

This is the same rule the page already follows for C6 / G10 — no fabricated
values, and derived text travels as a template key plus fields.

---

## 3. The algorithm

New entry point in `StatsViewModel.js`, replacing `buildClockSegments`:

```js
buildCategoryRing(segmentGroups, periodApps, dayStartUnix, half, options)
  → { arcs, stats }
```

`options` = `{ minSeconds: 60, minArcDeg: 2.0, bridgeSeconds: 60, minSweepDeg: 0.8 }`.

Module stays pure JS: `.pragma library`, no `Qt.*`, no I18n — it is loaded by
the Node test through `vm.runInNewContext` after the pragma is stripped
(`tests/stats_view_model_test.js:4`).

> **Order matters: denoise across the whole day, clip to the half last.**
> Clipping first would truncate a block straddling noon and let the threshold
> drop a 20-minute sliver of what was really a 60-minute block.

### 3.1 Resolve overlap into a single timeline

One ring is a single-valued function of time — one category per instant.
Sweep-line over all segment boundaries:

1. Flatten every group's segments into rows (carrying `groupKey`, category,
   display name, start, end). Do **not** clip to the half.
2. Collect and sort unique boundary times. Walk consecutive pairs
   `[tᵢ, tᵢ₊₁)`, collecting the segments covering each elementary interval.
3. Zero covering segments → gap. One → that segment. More than one → resolve.

**Overlap winner: the shortest covering segment.** Overlaps exist because the
60 s gap-merge stretched a long segment across a brief excursion; the
*interrupting* segment is the real foreground, the long one is the artifact.
Deterministic tiebreak: shorter duration → later start → `groupKey`
lexicographic, so the ring is stable across rebuilds.

Output: an ordered, **non-overlapping** list of atomic slices.

### 3.2 Collapse to category runs

Map each slice to `modelCategory(row) || "other"` — the fallback is explicit,
because `modelCategory` returns `""` when neither `adapterCategory` nor
`category` is set (`AppVisual.js:210`), and an empty id yields both the
fallback colour and an empty legend label.

Coalesce adjacent slices sharing a category. This alone is a large win:
a morning spent switching VS Code ↔ iTerm ↔ VS Code becomes **one**
Development arc instead of eleven.

**Gap bridging.** Join across a hole only when the hole is `< bridgeSeconds`
**and** both sides share a category. A real 20-minute idle gap stays a gap —
the ring shows when you were active. Bridging never invents a category; it
only extends one across a sub-threshold hole.

### 3.3 Pass 1 — the noise floor: drop the too-short, absorb the time

Walk the run list **shortest-first** (tiebreak: earlier start). Left-to-right
would let an early absorption change a later outcome by scan order; shortest-
first is stable and matches the intent — remove the noisiest thing first.

For each run under `minSeconds`:

- **Same-category neighbours on both sides, contiguous** → delete the run and
  merge the neighbours into one.
- **Different neighbours** → give the span to the **longer** contiguous
  neighbour, extending its boundary.
- **Contiguous with one neighbour only** → that one takes it.
- **Isolated** (gaps on both sides — a standalone 30 s blip) → no neighbour
  can absorb it. Discard; it rejoins the surrounding gap. Counted separately
  in `stats.droppedCount`, because this is the only case where measured time
  leaves the ring entirely.

Absorption only ever grows runs, so it cannot create a new short run — but
merging around a deleted run can make two same-category runs adjacent, so
coalescing and absorbing **alternate to a fixpoint**. Each iteration removes or
pins exactly one run, so the loop terminates.

### 3.3a Pass 2 — the legibility floor

*Added after measuring the first build against real data.* Pass 1 alone is not
enough. It removes sub-minute records, but says nothing about rapid alternation
where every stretch clears 60 s and still renders as a hairline. Measured on one
real day — 712 raw records, 191 merged segments, median 24 s:

| floor | arcs | median arc | arcs under 2° |
|-------|------|-----------|---------------|
| 60 s only | **47** | 134 s ≈ 1.1° | **35** |
| + 1.0° | 18 | 355 s | 4 |
| **+ 2.0° (shipped)** | **13** | 469 s | **0** |
| + 3.0° | 7 | 1058 s | 0 |

So the ring needs two floors, answering two different questions:

- **Noise** (`minSeconds`, 60 s) — *was this a real stretch of use?* An isolated
  one is **dropped**; that is the only time that leaves the ring.
- **Legibility** (`minArcDeg`, 2° = 4 min on the 12-hour dial) — *can this be
  seen and clicked?* It only **merges** into the block it interrupts. An
  isolated thin run is real time that happens to be brief, so it is **kept** and
  padded to a visible sweep by §3.4.

That `dropIsolated` difference is the whole distinction between the passes, and
it is what keeps `droppedCount` at 33 in both columns above: pass 2 never
deletes time, it only reassigns it.

### 3.4 Clip, project, pad

- Clip each run to `[halfStart, halfEnd]`; drop runs entirely outside.
- `startAngle = (start − halfStart) × 360 / 43200`, likewise for end.
- **Minimum sweep**: if the sweep is under `minSweepDeg` (≈ 0.8°), expand
  symmetrically about the midpoint so the arc is visible and clickable. Flag
  the row `sweepPadded: true` — the readout must still report true seconds.
  Padding can make neighbours abut or overlap by a hair; since arcs tile and
  share a radius this is visually harmless, and the hit test resolves by
  nearest midpoint (§4.2).

Each arc carries:

```js
{ arcId,            // category + ":" + startUnixSec + ":" + endUnixSec
  category,         // resolved id, "other" when unset
  startUnixSec, endUnixSec, seconds,   // true seconds, never the padded sweep
  startAngle, endAngle, sweepPadded,
  apps: [{ groupKey, displayName, seconds }],  // desc, capped at 4
  absorbedCount, mergedFrom }
```

`apps[]` is what compensates for dropping icons (D4): the ring stays clean,
and hovering still answers "what was I actually in?".

### 3.5 Shipped category-clock projection

The Day page restores the earlier `9432032` display contract on top of the
single-timeline overlap resolver:

1. Split the selected AM/PM half into 72 fixed ten-minute buckets.
2. Give each bucket to the category with the greatest measured overlap, provided
   that category has at least 60 seconds in the bucket.
3. Absorb a single A-B-A bucket into A.
4. Coalesce consecutive equal buckets into one solid block.

This projection changes geometry only. Total time, category percentages, and
legend durations still come from the exact unfiltered summaries. The clock also
uses `DailyUsageShare.categoryColorMap`, so each solid block keeps the same
color as its label in the adjacent category panel.

### 3.6 Accounting

`stats` travels as numbers only — the sentence is assembled in QML through
`I18n.sentence()` with a template key, per rule 04 §3 and the precedent set by
`buildAggregateFact`:

```js
{ droppedCount, droppedSeconds,     // isolated blips removed entirely
  absorbedCount, absorbedSeconds,   // short runs folded into a neighbour
  mergedFrom,                       // raw segments that became arcs
  coveredSeconds }                  // ring coverage after denoising
```

---

## 4. Rendering

`StatsApplicationClock` in `DesktopStatsPage.qml`. Keep the `FrostCard` shell,
the AM/PM toggle, the 60 ticks, the 12 hour numbers, and the hub.

### 4.1 Canvas

- One background track instead of three. Ring centre `base × 0.64`, stroke
  width `base × 0.17` → spans 0.555–0.725, inside today's 0.50–0.76 envelope,
  clear of the hub (outer radius `base × 0.39`).
- **Drop `lineCap = "round"` for arcs.** Round caps suited isolated app
  segments; on a tiled category ring they bulge and overlap. Use `"butt"`,
  with a hairline (~0.3°) separation between differing-category arcs.
- Remove the icon `Repeater`, the lane loop, and every
  `StatsViewModel.clockLaneRadiusScale` call.
- Colours stay `root.categoryHeatBase(arc.category)` so the ring, the heatmap,
  and the rest of the page share `categoryColorMap`
  (`DesktopStatsPage.qml:180`).

### 4.2 Hit test

`segmentAt(x, y)` simplifies: one radial band
`|r − ringRadius| ≤ trackWidth/2 + slop`, then an angular lookup. Arcs are
sorted and non-overlapping, so a linear scan is fine; where padded arcs abut,
pick the nearest midpoint. Preserve `hoveredId` / `lockedId` / `activeId` and
the click-to-pin toggle verbatim — the static test pins them.

### 4.3 Hub and legend

- **Unfocused hub**: `vmTotalSec` and the app count — unchanged, so it stays
  consistent with the donut beside it.
- **Focused hub**: category label via `root.categoryLabel(id)` (the rule table
  is the only source of category names), the arc's true duration, its clock
  range ("09:12 – 11:40"), and its top apps.
- **New legend row** beneath the dial: swatch + label + duration for each
  category present, ordered by seconds. With icons gone the ring needs a key.
- **New footer line**, replacing "Hover to preview…": the disclosure sentence
  from `stats`, e.g. *"12 records under 1 min folded in."* Suppressed when
  nothing was folded.

---

## 5. Work plan

| # | File | Change |
|---|------|--------|
| 1 | `qml/desktop/pages/StatsViewModel.js` | Add `buildCategoryRing()` + sweep/coalesce/absorb helpers. Retire `buildClockSegments`, `clockLaneRadiusScale`. |
| 2 | `qml/desktop/pages/DesktopStatsPage.qml` | `rebuildClockSegments()` → `rebuildCategoryRing()`; `vmClockSegments` → `vmRingArcs` + `vmRingStats`; single-ring paint, hit test, hub, legend, footer. |
| 3 | `qml/shared/I18n.js` | New English sources + zh/ja entries; `sentencesEn/Zh/Ja` template for the disclosure line. |
| 4 | `tests/stats_view_model_test.js` | Replace lane/icon assertions with ring assertions (§6). |
| 5 | `tests/stats_period_layout_static_test.py` | Update the `dial` section: `modelData.lane` and `modelData.showIcon` go; ring markers come in. |
| 6 | `docs/stats-functional-replication.md` | Update the clock spec to the ring contract. |

Order: **1 → 4** (algorithm green under Node before any QML moves) **→ 2 → 5
→ 3 → 6**.

### Harness

- Preflight already run and clean for track B; session log goes to
  `.harness/journal/sessions/20260826-1127-B-<slug>.md`.
- Build only through `python .harness/tools/build.py`.
- `python .harness/tools/scan_qt_log.py` after any Qt/QML run.
- `python .harness/tools/harness_check.py` before commit.
- Any build/runtime/QML failure or wrong premise → `record_error.py`.

---

## 6. Tests

**`tests/stats_view_model_test.js`** — `node tests/stats_view_model_test.js`:

1. **Overlap resolution** — the A/B/A case from §1: three raw segments, two
   overlapping, must yield a non-overlapping timeline where B owns 10:05–10:06.
2. **Same-category coalescing** — VS Code → iTerm → VS Code, all Development,
   contiguous → exactly one arc.
3. **Threshold + absorb** — a 15 s run between two Development runs disappears
   and the neighbours become one arc; `absorbedCount === 1`.
4. **Different-category absorb** — the span goes to the longer neighbour.
5. **Isolated blip** — a 30 s run with gaps both sides is discarded, counted in
   `droppedCount`, not `absorbedCount`.
6. **Real gaps survive** — a 20-minute hole is never bridged.
7. **Clip last** — a block spanning 11:30–12:30 appears in both halves,
   correctly clipped, and is not dropped by the threshold in either.
8. **Determinism** — shuffling the input group order yields identical arcs.
9. **Min sweep** — a 61 s survivor gets `sweepPadded: true` and `seconds`
   still reports 61.
10. **Empty category** — a row with no category resolves to `"other"`.

**`tests/stats_period_layout_static_test.py`** — the existing `dial`
assertions pin the old design and are expected to change: drop
`modelData.lane` / `modelData.showIcon`, keep `lockedId` / `activeId` /
`acceptedButtons: Qt.LeftButton` / the 60-tick and `model: 12` loops, add the
legend and single-ring markers.

**`tests/i18n_source_coverage_static_test.py`** must stay green — every new
`tr()` source needs a `zh` entry, and no CJK literal may appear in QML.

Manual: Day view with a dense day, AM ↔ PM, past periods via `periodOffset`,
day and night mode, and stacked layout below 900 px.

---

## 7. Risks

- **R1 — the ring is foreground-only.** `foregroundSegmentsImpl` skips
  `record.source == "audio"` (`usage_stat_manager.cpp:675`), while `vmTotalSec`
  comes from `activeSoftwareForWindow`, a foreground **+ audio** union. Ring
  coverage is already below the hub total today; a tiled ring makes the gap
  visible. *Resolution:* say "foreground records" in the card subtitle and
  leave the hub total alone. Do not quietly switch the hub to a foreground-only
  number — that would desync it from the donut.
- **R2 — empty category ids.** Handled explicitly in §3.2; without the fold to
  `"other"` these arcs get the fallback colour and a blank legend row.
- **R3 — `periodOffset` asymmetry (pre-existing, out of scope).**
  `rebuildClockSegments` honours `periodOffset`, but `DailyUsageShare` is fed
  by `memoryLakeDay`, which hardcodes `QDate::currentDate()`
  (`daily_card_service.cpp:956`). On a past day the ring moves and the donut
  does not. Worth a separate ticket.
- **R4 — recompute on half toggle.** `onClockHalfChanged` re-runs the whole
  rebuild. With clip-last the denoise pass would repeat per toggle.
  *Resolution:* cache the denoised full-day run list and re-clip only on half
  change — cheap, and it keeps `docs/stats-backend-performance.md`'s
  memoisation posture.
- **R5 — losing app icons is the visible cost of D4.** Mitigated by `apps[]` in
  the hover readout, the legend, and the App Library below. If it reads as too
  much loss in practice, the smallest reversal is a category glyph per arc —
  not a return to lanes.

---

## 8. Follow-ups (not this phase)

- Promote `minSeconds` / `minArcDeg` to Settings read-layer filters, alongside
  the existing per-item show/hide (`docs/settings-functional-replication.md`).
- Click an arc → filter the App Library to that block's apps.
- Reuse the ring for Week/Month as a "typical day" composite.
