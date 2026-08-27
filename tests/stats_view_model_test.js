const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
// '.pragma library' is not valid JavaScript, so this file cannot be require()d.
// Loaded the same way AppVisual.js is below: strip the pragma, evaluate in a
// fresh context, and read the top-level declarations off that context.
const Stats = {};
vm.runInNewContext(
  fs.readFileSync(
    require.resolve('../qml/desktop/pages/StatsViewModel.js'), 'utf8'
  ).replace(/^\.pragma library\s*/m, ''),
  Stats
);

const appVisualContext = {};
const appVisualSource = fs.readFileSync(
  require.resolve('../qml/desktop/components/AppVisual.js'), 'utf8'
).replace(/^\.pragma library\s*/m, '');
vm.runInNewContext(appVisualSource, appVisualContext);
assert.strictEqual(
  appVisualContext.modelDisplayNameForLanguage({
    customDisplayName: '谷歌浏览器',
    adapterDisplayName: 'Chrome',
    groupKey: 'app:google-chrome'
  }, 'en'),
  '谷歌浏览器'
);

const dayStart = 1_800_000_000;
const periodApps = [
  { groupKey: 'app:codex', appId: 'codex.exe', appName: 'Codex', category: '开发', seconds: 120, path: 'C:/Codex.exe' },
  { groupKey: 'app:chrome', appId: 'chrome.exe', appName: 'Chrome', category: '浏览', seconds: 60, path: 'C:/Chrome.exe' }
];
const lifetimeApps = [
  { groupKey: 'app:steam', appId: 'steam.exe', appName: 'Steam', category: '游戏', seconds: 7200, path: 'C:/Steam.exe' },
  { groupKey: 'app:codex', appId: 'codex.exe', appName: 'Codex', category: '开发', seconds: 3600, path: 'C:/Codex.exe' },
  { groupKey: 'app:chrome', appId: 'chrome.exe', appName: 'Chrome', category: '浏览', seconds: 1800, path: 'C:/Chrome.exe' }
];

const library = Stats.buildAppLibrary(periodApps, lifetimeApps, {
  query: '', sort: 'period', showInactive: true
});
assert.deepStrictEqual(library.map((row) => row.groupKey), ['app:codex', 'app:chrome', 'app:steam']);
assert.strictEqual(library[0].periodSeconds, 120);
assert.strictEqual(library[0].lifetimeSeconds, 3600);
assert.strictEqual(library[0].percent, 67);
assert.strictEqual(library[2].periodSeconds, 0);
assert.strictEqual(library[2].lifetimeSeconds, 7200);

const renamedLibrary = Stats.buildAppLibrary([
  { groupKey: 'app:codex', customDisplayName: '开发助手', adapterDisplayName: 'Codex', seconds: 60 }
], [], { query: '', sort: 'period', showInactive: true });
assert.strictEqual(renamedLibrary[0].name, '开发助手');

const lifetimeSorted = Stats.buildAppLibrary(periodApps, lifetimeApps, {
  query: '', sort: 'lifetime', showInactive: true
});
assert.deepStrictEqual(lifetimeSorted.map((row) => row.groupKey), ['app:steam', 'app:codex', 'app:chrome']);

const activeOnly = Stats.buildAppLibrary(periodApps, lifetimeApps, {
  query: '', sort: 'period', showInactive: false
});
assert.deepStrictEqual(activeOnly.map((row) => row.groupKey), ['app:codex', 'app:chrome']);

const queried = Stats.buildAppLibrary(periodApps, lifetimeApps, {
  query: '游戏', sort: 'name', showInactive: true
});
assert.deepStrictEqual(queried.map((row) => row.groupKey), ['app:steam']);

// ---- Category ring (Stats > Day) ------------------------------------------
// Geometry is denoised; the page's reported totals are not. See
// docs/stats-day-category-ring-redesign.md.

const round2 = (n) => Math.round(n * 100) / 100;
const group = (key, name, category, spans) => ({
  groupKey: key, appId: key, appName: name, path: `C:/${name}.exe`,
  adapterCategory: category,
  segments: spans.map(([from, to]) => ({
    startUnixSec: dayStart + from, endUnixSec: dayStart + to, seconds: to - from
  }))
});

// 1. Overlap resolution. The 60s gap-merge lets Codex stretch over a one-minute
// excursion to Chrome, so both claim 10:05-10:06; the shorter segment is the
// real foreground and must win the contested instant.
const overlap = Stats.buildCategoryRing(
  [group('app:codex', 'Codex', 'dev', [[36000, 36600]]),
   group('app:chrome', 'Chrome', 'web', [[36300, 36360]])],
  [], dayStart, 'am', { minSeconds: 0, minArcDeg: 0 }
);
assert.deepStrictEqual(
  overlap.arcs.map((arc) => [arc.category, arc.seconds]),
  [['dev', 300], ['web', 60], ['dev', 240]]
);
assert.strictEqual(overlap.stats.mergedFrom, 2);

// 2. Same-category coalescing: two apps back to back become one run. Category
// falls back to `category` when `adapterCategory` is absent, matching
// AppVisual.modelCategory().
const coalesced = Stats.buildCategoryRing([
  { groupKey: 'app:vscode', appName: 'VS Code', category: 'dev',
    segments: [{ startUnixSec: dayStart + 3600, endUnixSec: dayStart + 5400 }] },
  { groupKey: 'app:iterm', appName: 'iTerm', category: 'dev',
    segments: [{ startUnixSec: dayStart + 5400, endUnixSec: dayStart + 6600 }] }
], [], dayStart, 'am');
assert.strictEqual(coalesced.arcs.length, 1);
assert.strictEqual(coalesced.arcs[0].category, 'dev');
assert.strictEqual(coalesced.arcs[0].seconds, 3000);
assert.strictEqual(coalesced.arcs[0].mergedFrom, 2);
assert.deepStrictEqual(
  coalesced.arcs[0].apps.map((app) => [app.displayName, app.seconds]),
  [['VS Code', 1800], ['iTerm', 1200]]
);

// 3. A 15s run between two Development runs disappears and the neighbours
// become one arc — the peek is folded in, not left as a hole.
const absorbed = Stats.buildCategoryRing(
  [group('app:vscode', 'VS Code', 'dev', [[0, 1800], [1815, 3600]]),
   group('app:slack', 'Slack', 'social', [[1800, 1815]])],
  [], dayStart, 'am'
);
assert.strictEqual(absorbed.arcs.length, 1);
assert.strictEqual(absorbed.arcs[0].category, 'dev');
assert.strictEqual(absorbed.arcs[0].seconds, 3600);
assert.strictEqual(absorbed.arcs[0].absorbedCount, 1);
assert.strictEqual(absorbed.stats.absorbedCount, 1);
assert.strictEqual(absorbed.stats.absorbedSeconds, 15);
assert.strictEqual(absorbed.stats.droppedCount, 0);

// 4. Between neighbours of different categories the span goes to the longer one.
const leaning = Stats.buildCategoryRing(
  [group('app:chrome', 'Chrome', 'web', [[0, 600]]),
   group('app:slack', 'Slack', 'social', [[600, 630]]),
   group('app:vscode', 'VS Code', 'dev', [[630, 1800]])],
  [], dayStart, 'am'
);
assert.deepStrictEqual(
  leaning.arcs.map((arc) => [arc.category, arc.seconds]),
  [['web', 600], ['dev', 1200]]
);
assert.strictEqual(leaning.stats.absorbedCount, 1);

// 5. A short run with gaps on both sides has no neighbour to absorb it. This is
// the one case where measured time leaves the ring, so it is counted apart.
const isolated = Stats.buildCategoryRing(
  [group('app:vscode', 'VS Code', 'dev', [[0, 1800]]),
   group('app:finder', 'Finder', 'system', [[3600, 3630]]),
   group('app:chrome', 'Chrome', 'web', [[7200, 9000]])],
  [], dayStart, 'am'
);
assert.strictEqual(isolated.arcs.length, 2);
assert.strictEqual(isolated.stats.droppedCount, 1);
assert.strictEqual(isolated.stats.droppedSeconds, 30);
assert.strictEqual(isolated.stats.absorbedCount, 0);

// 6. A real idle gap is never bridged: bridging only spans sub-threshold holes.
const gapped = Stats.buildCategoryRing(
  [group('app:vscode', 'VS Code', 'dev', [[0, 1800], [3000, 4800]])],
  [], dayStart, 'am'
);
assert.deepStrictEqual(
  gapped.arcs.map((arc) => [arc.category, arc.seconds]),
  [['dev', 1800], ['dev', 1800]]
);

// 7. Clip last. This 630s block straddles noon; its AM remnant is only 30s, so
// clipping before the threshold would have dropped it. It survives, padded to a
// visible sweep, and still reports its true 30 seconds.
const straddle = [group('app:vscode', 'VS Code', 'dev', [[43170, 43800]])];
const straddleAm = Stats.buildCategoryRing(straddle, [], dayStart, 'am');
assert.strictEqual(straddleAm.arcs.length, 1);
assert.strictEqual(straddleAm.arcs[0].seconds, 30);
assert.strictEqual(straddleAm.arcs[0].sweepPadded, true);
assert.deepStrictEqual(
  [round2(straddleAm.arcs[0].startAngle), round2(straddleAm.arcs[0].endAngle)],
  [359.2, 360]
);
const straddlePm = Stats.buildCategoryRing(straddle, [], dayStart, 'pm');
assert.strictEqual(straddlePm.arcs[0].seconds, 600);
assert.deepStrictEqual(
  [round2(straddlePm.arcs[0].startAngle), round2(straddlePm.arcs[0].endAngle)],
  [0, 5]
);

// 8. Deterministic: input order must not change the ring.
const shuffled = Stats.buildCategoryRing(
  [group('app:chrome', 'Chrome', 'web', [[36300, 36360]]),
   group('app:codex', 'Codex', 'dev', [[36000, 36600]])],
  [], dayStart, 'am', { minSeconds: 0, minArcDeg: 0 }
);
assert.deepStrictEqual(shuffled.arcs, overlap.arcs);

// 9. A 61s run clears the noise floor but not the legibility floor. It is
// isolated, so the legibility pass keeps it rather than deleting real time, and
// it sits at the very start of the half where the sweep cannot grow leftwards,
// so the clamped remainder is given back on the other side.
const hairline = Stats.buildCategoryRing(
  [group('app:vscode', 'VS Code', 'dev', [[0, 61]])], [], dayStart, 'am'
);
assert.strictEqual(hairline.arcs[0].seconds, 61);
assert.strictEqual(hairline.arcs[0].sweepPadded, true);
assert.deepStrictEqual(
  [round2(hairline.arcs[0].startAngle), round2(hairline.arcs[0].endAngle)],
  [0, 0.8]
);

// 9b. Legibility floor. Rapid alternation clears the 60s noise floor — these
// stretches are 150s each — yet every arc would render as a ~1.2 degree
// hairline. Measured on a real day, leaving these alone gives 47 arcs of which
// 35 are under 2 degrees; the second pass merges them into what they interrupt.
const alternatingGroups = [
  group('app:vscode', 'VS Code', 'dev', [[0, 900], [1050, 1200], [1350, 1500], [1650, 3000]]),
  group('app:wechat', 'WeChat', 'social', [[900, 1050], [1200, 1350], [1500, 1650]])
];
const striped = Stats.buildCategoryRing(alternatingGroups, [], dayStart, 'am', { minArcDeg: 0 });
assert.strictEqual(striped.arcs.length, 7);
const smoothed = Stats.buildCategoryRing(alternatingGroups, [], dayStart, 'am');
assert.deepStrictEqual(
  smoothed.arcs.map((arc) => [arc.category, arc.seconds]), [['dev', 3000]]
);
assert.strictEqual(smoothed.arcs[0].apps.length, 2);

// An isolated run under the legibility floor is real time, not noise, so the
// second pass keeps it — only the sub-minute pass may delete a run outright.
const lonely = Stats.buildCategoryRing(
  [group('app:vscode', 'VS Code', 'dev', [[0, 1800]]),
   group('app:mail', 'Mail', 'productivity', [[5400, 5580]])],
  [], dayStart, 'am'
);
assert.deepStrictEqual(
  lonely.arcs.map((arc) => [arc.category, arc.seconds]),
  [['dev', 1800], ['productivity', 180]]
);
assert.strictEqual(lonely.stats.droppedCount, 0);

// 10. An unset category folds to "other" once, rather than leaving an empty id
// to pick up the fallback colour and a blank legend row.
const uncategorised = Stats.buildCategoryRing([
  { groupKey: 'app:unknown', appName: 'Unknown',
    segments: [{ startUnixSec: dayStart, endUnixSec: dayStart + 1800 }] }
], [], dayStart, 'am');
assert.strictEqual(uncategorised.arcs[0].category, 'other');
assert.strictEqual(uncategorised.arcs[0].arcId, `other:${dayStart}:${dayStart + 1800}`);

// An empty day yields an empty ring, not a throw.
const empty = Stats.buildCategoryRing([], [], dayStart, 'am');
assert.deepStrictEqual(empty.arcs, []);
assert.strictEqual(empty.stats.coveredSeconds, 0);

assert.strictEqual(Stats.formatCompactDuration(0), '0m');
assert.strictEqual(Stats.formatCompactDuration(59), '<1m');
assert.strictEqual(Stats.formatCompactDuration(3660), '1h 1m');

const categories = Stats.buildCategoryDistribution([
  { groupKey: 'app:codex', appName: 'Codex', category: 'Development', seconds: 120 },
  { groupKey: 'app:vscode', appName: 'Visual Studio Code', category: 'Development', seconds: 60 },
  { groupKey: 'app:chrome', appName: 'Chrome', category: 'Browsing', seconds: 60 }
], 6);
// apps is handed over unjoined: the separator is language-dependent ("、" for
// CJK, ", " for English) and this module deliberately knows nothing about I18n.
assert.deepStrictEqual(categories, [
  { name: 'Development', seconds: 180, time: '3m', percent: 75, apps: ['Codex', 'Visual Studio Code'] },
  { name: 'Browsing', seconds: 60, time: '1m', percent: 25, apps: ['Chrome'] }
]);

const monthTrend = Stats.normalizeTrendRows('month', [
  { seconds: 3600 },
  { seconds: 7200 },
  { seconds: 0 }
]);
// A generated label travels as a key plus its index; only a row that arrived
// with its own label keeps one, so that nothing here has to pick a language.
assert.deepStrictEqual(monthTrend, [
  { label: '', labelKey: 'weekOfMonth', labelIndex: 0, seconds: 3600, ratio: 0.5, valueText: '1h' },
  { label: '', labelKey: 'weekOfMonth', labelIndex: 1, seconds: 7200, ratio: 1, valueText: '2h' },
  { label: '', labelKey: 'weekOfMonth', labelIndex: 2, seconds: 0, ratio: 0, valueText: '0m' }
]);

const yearTrend = Stats.normalizeTrendRows('year', [{ seconds: 7200 }]);
assert.strictEqual(yearTrend[0].labelKey, 'monthOfYear');
assert.strictEqual(yearTrend[0].labelIndex, 0);

const weekTrend = Stats.normalizeTrendRows('week', [
  { seconds: 120 },
  { seconds: 300 }
]);
assert.deepStrictEqual(weekTrend.map((row) => row.labelKey),
  ['weekdayNarrow', 'weekdayNarrow']);

// A supplied label is preserved verbatim rather than replaced by a key.
const labelled = Stats.normalizeTrendRows('week', [{ label: 'Mon', seconds: 120 }]);
assert.strictEqual(labelled[0].label, 'Mon');
assert.strictEqual(labelled[0].labelKey, '');

// buildAggregateFact returns the template name and its fields, never a
// sentence: the clause order differs by language.
assert.deepStrictEqual(Stats.buildAggregateFact('week', categories, weekTrend), {
  key: 'aggregateFact',
  params: {
    category: 'Development',
    range: 'This Week',
    peakLabel: '',
    peakLabelKey: 'weekdayNarrow',
    peakLabelIndex: 1
  }
});
assert.strictEqual(
  Stats.buildAggregateFact('month', categories, monthTrend).params.peakLabelIndex, 1);
assert.strictEqual(
  Stats.buildAggregateFact('year', categories, yearTrend).params.range, 'This Year');
assert.strictEqual(Stats.buildAggregateFact('week', [], weekTrend), null);

// --- Category ring: pinned end-to-end behaviour -----------------------------
// The ring pipeline (flatten -> resolve overlap -> denoise) was rewritten for
// speed: the overlap sweep now uses a heap instead of rescanning every row per
// tick, and the smoothing loop coalesces in place instead of deep-copying every
// run on every iteration. Both are meant to be output-identical, so this pins
// the observable result rather than the implementation.
//
// It deliberately covers the paths carrying the subtle rules:
//   * overlap where the SHORTER row wins the contested instant (Chat inside IDE)
//   * a 59s hole bridged because both sides share a category (bridge = 60)
//   * a short block absorbed into a neighbour (absorbedCount)
//   * two isolated short blocks with gaps on both sides, which are dropped
// Expected values were captured from the PRE-rewrite implementation and verified
// identical against the rewrite, so this is a regression test, not a snapshot of
// whatever the current code happens to do.
const ringDay = 1800000000;
const ringGroups = [
  { groupKey: 'app:ide', appId: 'ide', appName: 'IDE', path: '/ide', segments: [
    { startUnixSec: ringDay + 0, endUnixSec: ringDay + 1200 },
    { startUnixSec: ringDay + 1259, endUnixSec: ringDay + 2000 },
    { startUnixSec: ringDay + 5000, endUnixSec: ringDay + 5030 }
  ] },
  { groupKey: 'app:chat', appId: 'chat', appName: 'Chat', path: '/chat', segments: [
    { startUnixSec: ringDay + 600, endUnixSec: ringDay + 640 },
    { startUnixSec: ringDay + 2400, endUnixSec: ringDay + 3000 }
  ] },
  { groupKey: 'app:web', appId: 'web', appName: 'Web', path: '/web', segments: [
    { startUnixSec: ringDay + 3061, endUnixSec: ringDay + 4000 },
    { startUnixSec: ringDay + 9000, endUnixSec: ringDay + 9010 }
  ] }
];
const ringApps = [
  { groupKey: 'app:ide', appId: 'ide', appName: 'IDE', displayName: 'IDE', category: 'dev', seconds: 1971 },
  { groupKey: 'app:chat', appId: 'chat', appName: 'Chat', displayName: 'Chat', category: 'social', seconds: 640 },
  { groupKey: 'app:web', appId: 'web', appName: 'Web', displayName: 'Web', category: 'dev', seconds: 949 }
];

const ringBuilt = Stats.buildCategoryRingRuns(ringGroups, ringApps);
assert.deepStrictEqual(ringBuilt.runs, [
  {
    "category": "dev",
    "start": 1800000000,
    "end": 1800002000,
    "seconds": 2000,
    "apps": [
      {
        "groupKey": "app:ide",
        "displayName": "IDE",
        "seconds": 1901
      },
      {
        "groupKey": "app:chat",
        "displayName": "Chat",
        "seconds": 40
      }
    ],
    "absorbedCount": 1,
    "mergedFrom": 3,
    "pinned": false
  },
  {
    "category": "social",
    "start": 1800002400,
    "end": 1800003000,
    "seconds": 600,
    "apps": [
      {
        "groupKey": "app:chat",
        "displayName": "Chat",
        "seconds": 600
      }
    ],
    "absorbedCount": 0,
    "mergedFrom": 1,
    "pinned": false
  },
  {
    "category": "dev",
    "start": 1800003061,
    "end": 1800004000,
    "seconds": 939,
    "apps": [
      {
        "groupKey": "app:web",
        "displayName": "Web",
        "seconds": 939
      }
    ],
    "absorbedCount": 0,
    "mergedFrom": 1,
    "pinned": false
  }
]);
assert.deepStrictEqual(ringBuilt.stats, {
  "droppedCount": 2,
  "droppedSeconds": 40,
  "absorbedCount": 1,
  "absorbedSeconds": 40,
  "mergedFrom": 7,
  "coveredSeconds": 3539,
  "runCount": 3
});
assert.deepStrictEqual(Stats.ringCategories(ringBuilt.runs), ["dev", "social"]);

const ringArcs = Stats.projectCategoryRing(ringBuilt.runs, ringDay, 'am');
assert.strictEqual(ringArcs.length, 3);
assert.strictEqual(ringArcs[0].arcId, 'dev:1800000000:1800002000');
assert.strictEqual(ringArcs[0].startAngle, 0);
// Projection clips to the requested half; this fixture has nothing in the pm half.
assert.deepStrictEqual(Stats.projectCategoryRing(ringBuilt.runs, ringDay, 'pm'), []);
// An empty ring stays empty rather than throwing.
assert.deepStrictEqual(Stats.buildCategoryRingRuns([], []).runs, []);

console.log('stats_view_model_test: pass');
