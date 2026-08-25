const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const Stats = require('../qml/desktop/pages/StatsViewModel.js');

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
assert.deepStrictEqual(
  [0, 1, 2].map((lane) => Stats.clockLaneRadiusScale(lane)),
  [0.54, 0.63, 0.72]
);
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

const segmentGroups = [
  {
    groupKey: 'app:codex', appId: 'codex.exe', appName: 'Codex', path: 'C:/Codex.exe',
    segments: [{ startUnixSec: dayStart + 8 * 3600, endUnixSec: dayStart + 10 * 3600, seconds: 7200 }]
  },
  {
    groupKey: 'app:chrome', appId: 'chrome.exe', appName: 'Chrome', path: 'C:/Chrome.exe',
    segments: [{ startUnixSec: dayStart + 11.5 * 3600, endUnixSec: dayStart + 12.5 * 3600, seconds: 3600 }]
  }
];

const am = Stats.buildClockSegments(segmentGroups, periodApps, dayStart, 'am');
assert.strictEqual(am.length, 2);
assert.deepStrictEqual(
  am.map((row) => [row.groupKey, row.startAngle, row.endAngle, row.seconds]),
  [['app:codex', 240, 300, 7200], ['app:chrome', 345, 360, 1800]]
);
assert.strictEqual(am[0].category, '开发');
assert.strictEqual(am[0].appName, 'Codex');
assert.strictEqual(am[0].lane, 0);
assert.strictEqual(am[0].showIcon, true);

const pm = Stats.buildClockSegments(segmentGroups, periodApps, dayStart, 'pm');
assert.strictEqual(pm.length, 1);
assert.deepStrictEqual(
  [pm[0].groupKey, pm[0].startAngle, pm[0].endAngle, pm[0].seconds],
  ['app:chrome', 0, 15, 1800]
);

const crowdedGroups = [
  { groupKey: 'app:a', appName: 'A', segments: [{ startUnixSec: dayStart, endUnixSec: dayStart + 25 * 60 }] },
  { groupKey: 'app:b', appName: 'B', segments: [{ startUnixSec: dayStart + 10 * 60, endUnixSec: dayStart + 30 * 60 }] },
  { groupKey: 'app:c', appName: 'C', segments: [{ startUnixSec: dayStart + 31 * 60, endUnixSec: dayStart + 36 * 60 }] }
];
const crowded = Stats.buildClockSegments(crowdedGroups, [], dayStart, 'am');
assert.deepStrictEqual(crowded.map((row) => row.lane), [0, 1, 0]);
assert.strictEqual(crowded[0].showIcon, true);
assert.strictEqual(crowded[1].showIcon, false);
assert.strictEqual(crowded[2].showIcon, false);

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

console.log('stats_view_model_test: pass');
