const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const prototypeDir = path.join(__dirname, '..', 'docs', 'prototypes');
const html = fs.readFileSync(path.join(prototypeDir, 'timearc-stats-rework-v1.html'), 'utf8');
const css = fs.readFileSync(path.join(prototypeDir, 'timearc-stats-rework-v1.css'), 'utf8');

// Regression caught: the first prototype retained a desktop sidebar but stacked
// the actual statistics content like a tall mobile screen.
assert.match(html, /class="desktop-overview"/);
assert.equal((html.match(/class="overview-item"/g) || []).length, 4);
assert.match(html, /class="desktop-lower-grid"/);
assert.match(html, /class="summary-evidence"/);

// The desktop shell keeps the current 232px navigation rhythm and a genuine
// wide two-column workbench for both the main analysis and lower detail row.
assert.match(css, /grid-template-columns:\s*232px\s+minmax\(0,\s*1fr\)/);
assert.match(css, /\.daily-layout\s*\{[^}]*minmax\(560px,\s*1\.45fr\)[^}]*minmax\(320px,\s*\.75fr\)/s);
assert.match(css, /\.desktop-lower-grid\s*\{[^}]*minmax\(0,\s*1\.45fr\)[^}]*minmax\(320px,\s*\.75fr\)/s);

// A narrow desktop may collapse the sidebar, but this desktop concept must not
// silently turn it into the mobile app's fixed bottom navigation.
assert.doesNotMatch(css, /\.sidebar\s*\{[^}]*position:\s*fixed;[^}]*inset:\s*auto\s+0\s+0/s);

console.log('stats_prototype_desktop_layout_test: pass');
