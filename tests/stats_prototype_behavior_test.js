const assert = require('node:assert/strict');
const {
  buildClockSegments,
  buildCategorySummary,
  buildFocusState,
  describeDonutSector,
  renderClockSvg
} = require('../docs/prototypes/timearc-stats-rework-v1.js');

const records = [
  { id: 'codex', app: 'Codex', category: '开发', start: '08:00', end: '09:30', color: '#52c7b8' },
  { id: 'wechat', app: '微信', category: '社交', start: '09:30', end: '10:00', color: '#71d67b' },
  { id: 'chrome', app: 'Chrome', category: '浏览', start: '10:00', end: '10:45', color: '#70a8f7' },
  { id: 'bilibili', app: '哔哩哔哩', category: '视频', start: '20:00', end: '21:00', color: '#ef78a8' }
];

// Regression caught: aggregating by category would erase the individual app
// identity that the clock must expose and focus on hover.
const morning = buildClockSegments(records, 'am');
assert.equal(morning.length, 3);
assert.deepEqual(morning.map((segment) => segment.id), ['codex', 'wechat', 'chrome']);
assert.equal(morning[0].minutes, 90);
assert.equal(morning[0].startAngle, 150);
assert.equal(morning[0].endAngle, 195);

// Regression caught: category totals must derive from measured durations, not
// equal-sized visual sectors or session counts.
const categories = buildCategorySummary(records);
assert.deepEqual(categories.map((item) => [item.category, item.minutes]), [
  ['开发', 90],
  ['视频', 60],
  ['浏览', 45],
  ['社交', 30]
]);

// Regression caught: hovering one app must enlarge only that sector while the
// center copy switches to the concrete app and the rest remain available.
const focus = buildFocusState(morning, 'wechat');
assert.equal(focus.center.app, '微信');
assert.equal(focus.center.timeRange, '09:30 至 10:00');
assert.equal(focus.center.duration, '30 分钟');
assert.equal(focus.segments.find((item) => item.id === 'wechat').scale, 1.12);
assert.equal(focus.segments.find((item) => item.id === 'codex').opacity, 0.24);

// Regression caught: malformed SVG geometry used to blank the whole clock.
const path = describeDonutSector(0, 30, 108, 184);
assert.match(path, /^M /);
assert.equal(path.includes('NaN'), false);

// Regression caught: the visible dial must expose each concrete application
// as an accessible interactive target, including measured time evidence.
const svg = renderClockSvg(morning, 'wechat');
assert.match(svg, /data-app-id="codex"/);
assert.match(svg, /data-app-id="wechat"[^>]*class="dial-app is-focused"/);
assert.match(svg, /aria-label="Codex，08:00 至 09:30，1 小时 30 分钟"/);
assert.match(svg, /<image class="dial-app-icon"/);

console.log('stats_prototype_behavior_test: pass');
