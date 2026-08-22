const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  appIconDataUri,
  buildAppLibrary,
  buildClockSegments,
  formatCompactDuration,
  renderClockSvg
} = require('../docs/prototypes/timearc-stats-rework-v1.js');

const catalog = [
  { appId: 'codex', app: 'Codex', category: '开发', lifetimeMinutes: 11250, periods: { day: 88 } },
  { appId: 'chrome', app: 'Chrome', category: '浏览', lifetimeMinutes: 9460, periods: { day: 55 } },
  { appId: 'steam', app: 'Steam', category: '游戏', lifetimeMinutes: 4280, periods: { day: 0 } }
];

// Regression caught: a Top-N ranking cannot answer how long every known app
// has been used, including apps with historical time but no activity today.
const allRows = buildAppLibrary(catalog, 'day', { query: '', sort: 'lifetime', showInactive: true });
assert.equal(allRows.length, 3);
assert.deepEqual(allRows.map((row) => row.appId), ['codex', 'chrome', 'steam']);
assert.equal(allRows[0].lifetimeMinutes, 11250);
assert.equal(allRows[2].periodMinutes, 0);
assert.equal(formatCompactDuration(11250), '187h 30m');
assert.equal(formatCompactDuration(0), '0m');

const activeRows = buildAppLibrary(catalog, 'day', { query: '', sort: 'period', showInactive: false });
assert.deepEqual(activeRows.map((row) => row.appId), ['codex', 'chrome']);
assert.deepEqual(buildAppLibrary(catalog, 'day', { query: '浏览', sort: 'period', showInactive: true }).map((row) => row.appId), ['chrome']);

// Clock sectors and the full library use the same local icon representation;
// concrete app identity remains accessible even when the visual mark is an image.
assert.match(appIconDataUri('codex', 'Codex', '#61cfc3'), /^data:image\/svg\+xml/);
const segments = buildClockSegments([
  { id: 'codex-am', appId: 'codex', app: 'Codex', category: '开发', start: '08:00', end: '09:00', color: '#61cfc3' }
], 'am');
const clockSvg = renderClockSvg(segments, null);
assert.match(clockSvg, /<image class="dial-app-icon"/);
assert.match(clockSvg, /aria-label="Codex，08:00 至 09:00，1 小时"/);

const html = fs.readFileSync(path.join(__dirname, '..', 'docs', 'prototypes', 'timearc-stats-rework-v1.html'), 'utf8');
assert.match(html, /class="app-library-section"/);
assert.match(html, /id="app-library-list"/);
assert.match(html, />累计总时长</);

console.log('stats_prototype_app_library_test: pass');
