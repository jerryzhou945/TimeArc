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

const i18nContext = {};
const i18nSource = fs.readFileSync(
  require.resolve('../qml/desktop/components/I18n.js'), 'utf8'
).replace(/^\.pragma library\s*/m, '');
vm.runInNewContext(i18nSource, i18nContext);
assert.strictEqual(i18nContext.t('en', '应用时钟'), 'Application Clock');
assert.strictEqual(
  i18nContext.t('en', '按 10 分钟聚合分类，真实时长保持不变'),
  '10-minute category blocks reveal the day\'s rhythm; exact totals stay unchanged'
);
assert.strictEqual(
  i18nContext.sentence('en', 'clockSummary', { categories: 4, apps: 15 }, ''),
  '4 categories · 15 apps'
);
assert.strictEqual(
  i18nContext.sentence('en', 'clockCategoryApps', { count: 3, apps: 'Codex, Chrome, Figma' }, ''),
  '3 apps · Codex, Chrome, Figma'
);

const dayStart = 1_800_000_000;
assert.deepStrictEqual(
  [0, 1, 2].map((lane) => Stats.clockLaneRadiusScale(lane)),
  [0.54, 0.63, 0.72]
);
assert.deepStrictEqual(Stats.categoryClockSectorBand(0, false), { inner: 0.51, outer: 0.80 });
assert.deepStrictEqual(Stats.categoryClockSectorBand(1, false), { inner: 0.64, outer: 0.82 });
assert.deepStrictEqual(Stats.categoryClockSectorBand(0, true), { inner: 0.49, outer: 0.86 });
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

// Break caught: the daily clock must not regress to one scattered arc per app.
// Same-category intervals form chronological category arcs, while concurrent
// categories remain independently selectable and retain exact category totals.
const categoryClockGroups = [
  {
    groupKey: 'app:codex', appName: 'Codex',
    segments: [
      { startUnixSec: dayStart + 8 * 3600, endUnixSec: dayStart + 8 * 3600 + 20 * 60 },
      { startUnixSec: dayStart + 8 * 3600 + 50 * 60, endUnixSec: dayStart + 9 * 3600 }
    ]
  },
  {
    groupKey: 'app:vscode', appName: 'Visual Studio Code',
    segments: [{ startUnixSec: dayStart + 8 * 3600 + 18 * 60, endUnixSec: dayStart + 9 * 3600 }]
  },
  {
    groupKey: 'app:chrome', appName: 'Chrome',
    segments: [
      { startUnixSec: dayStart + 8 * 3600 + 10 * 60, endUnixSec: dayStart + 8 * 3600 + 30 * 60 },
      { startUnixSec: dayStart + 10 * 3600, endUnixSec: dayStart + 10 * 3600 + 10 * 60 }
    ]
  }
];
const categoryClockApps = [
  { groupKey: 'app:codex', appName: 'Codex', category: '开发' },
  { groupKey: 'app:vscode', appName: 'Visual Studio Code', category: '开发' },
  { groupKey: 'app:chrome', appName: 'Chrome', category: '浏览' }
];
const categoryClock = Stats.buildCategoryClockSegments(
  categoryClockGroups, categoryClockApps, dayStart, 'am'
);
assert.deepStrictEqual(
  categoryClock.map((row) => [
    row.categoryKey, row.startAngle, row.endAngle, row.lane,
    row.categoryTotalSeconds, row.appCount, row.appsText
  ]),
  [
    ['开发', 240, 270, 0, 3600, 2, 'Visual Studio Code、Codex'],
    ['浏览', 245, 255, 1, 1800, 1, 'Chrome'],
    ['浏览', 300, 305, 0, 1800, 1, 'Chrome']
  ]
);
assert.strictEqual(categoryClock[0].categoryArcCount, 1);
assert.strictEqual(categoryClock[1].categoryArcCount, 2);
assert.strictEqual(categoryClock[0].segmentId, '开发:240:270');
assert.deepStrictEqual(
  categoryClock[0].apps.map((app) => [app.appName, app.seconds]),
  [['Visual Studio Code', 2520], ['Codex', 1800]]
);

const smoothedClock = Stats.buildSmoothedCategoryClockSegments([
  {
    groupKey: 'app:codex', appName: 'Codex',
    segments: [
      { startUnixSec: dayStart + 8 * 3600, endUnixSec: dayStart + 8 * 3600 + 10 * 60 },
      { startUnixSec: dayStart + 8 * 3600 + 20 * 60, endUnixSec: dayStart + 8 * 3600 + 30 * 60 }
    ]
  },
  {
    groupKey: 'app:discord', appName: 'Discord',
    segments: [{ startUnixSec: dayStart + 8 * 3600 + 10 * 60, endUnixSec: dayStart + 8 * 3600 + 20 * 60 }]
  },
  {
    groupKey: 'app:bilibili', appName: '哔哩哔哩',
    segments: [{ startUnixSec: dayStart + 8 * 3600 + 40 * 60, endUnixSec: dayStart + 8 * 3600 + 42 * 60 }]
  }
], [
  { groupKey: 'app:codex', appName: 'Codex', category: '开发' },
  { groupKey: 'app:discord', appName: 'Discord', category: '社交' },
  { groupKey: 'app:bilibili', appName: '哔哩哔哩', category: '视频' }
], dayStart, 'am');
assert.deepStrictEqual(
  smoothedClock.map((row) => [
    row.categoryKey, row.startAngle, row.endAngle,
    row.categoryTotalSeconds, row.appCount
  ]),
  [
    ['开发', 240, 255, 1200, 1],
    ['视频', 260, 265, 120, 1]
  ]
);

assert.strictEqual(Stats.formatCompactDuration(0), '0m');
assert.strictEqual(Stats.formatCompactDuration(59), '<1m');
assert.strictEqual(Stats.formatCompactDuration(3660), '1h 1m');

const categories = Stats.buildCategoryDistribution([
  { groupKey: 'app:codex', appName: 'Codex', category: '开发', seconds: 120 },
  { groupKey: 'app:vscode', appName: 'Visual Studio Code', category: '开发', seconds: 60 },
  { groupKey: 'app:chrome', appName: 'Chrome', category: '浏览', seconds: 60 }
], 6);
assert.deepStrictEqual(categories, [
  { name: '开发', seconds: 180, time: '3m', percent: 75, appsText: 'Codex、Visual Studio Code' },
  { name: '浏览', seconds: 60, time: '1m', percent: 25, appsText: 'Chrome' }
]);

const monthTrend = Stats.normalizeTrendRows('month', [
  { seconds: 3600 },
  { seconds: 7200 },
  { seconds: 0 }
]);
assert.deepStrictEqual(monthTrend, [
  { label: '第1周', seconds: 3600, ratio: 0.5, valueText: '1h' },
  { label: '第2周', seconds: 7200, ratio: 1, valueText: '2h' },
  { label: '第3周', seconds: 0, ratio: 0, valueText: '0m' }
]);

const weekTrend = Stats.normalizeTrendRows('week', [
  { label: '一', seconds: 120 },
  { label: '三', seconds: 300 }
]);
assert.deepStrictEqual(weekTrend.map((row) => row.label), ['一', '三']);
assert.strictEqual(Stats.buildAggregateFact('week', categories, weekTrend),
  '开发是本周记录时长最长的分类，三的记录最集中。');
assert.strictEqual(Stats.buildAggregateFact('month', categories, monthTrend),
  '开发是本月记录时长最长的分类，第2周的记录最集中。');
assert.strictEqual(Stats.buildAggregateFact('year', categories, [
  { label: '8月', seconds: 7200, ratio: 1, valueText: '2h' }
]), '开发是本年记录时长最长的分类，8月的记录最集中。');
assert.strictEqual(Stats.buildAggregateFact('week', [], weekTrend), '');

console.log('stats_view_model_test: pass');
