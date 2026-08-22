(function (globalScope) {
  'use strict';

  function toMinutes(value) {
    const parts = String(value || '00:00').split(':').map(Number);
    return Math.max(0, Math.min(1440, (parts[0] || 0) * 60 + (parts[1] || 0)));
  }

  function formatDuration(minutes) {
    const safeMinutes = Math.max(0, Math.round(minutes));
    const hours = Math.floor(safeMinutes / 60);
    const rest = safeMinutes % 60;
    if (hours && rest) return `${hours} 小时 ${rest} 分钟`;
    if (hours) return `${hours} 小时`;
    return `${rest} 分钟`;
  }

  function formatCompactDuration(minutes) {
    const safeMinutes = Math.max(0, Math.round(minutes));
    const hours = Math.floor(safeMinutes / 60);
    const rest = safeMinutes % 60;
    if (hours && rest) return `${hours}h ${rest}m`;
    if (hours) return `${hours}h`;
    return `${rest}m`;
  }

  function buildAppLibrary(catalog, range, options = {}) {
    const query = String(options.query || '').trim().toLocaleLowerCase('zh-CN');
    const sort = options.sort || 'period';
    const showInactive = options.showInactive !== false;
    const rows = (catalog || []).map((item) => ({
      ...item,
      periodMinutes: Math.max(0, Number(item.periods && item.periods[range]) || 0),
      lifetimeMinutes: Math.max(0, Number(item.lifetimeMinutes) || 0)
    })).filter((item) => {
      const searchable = `${item.app || ''} ${item.category || ''}`.toLocaleLowerCase('zh-CN');
      return (!query || searchable.includes(query)) && (showInactive || item.periodMinutes > 0);
    });

    return rows.sort((left, right) => {
      if (sort === 'lifetime') return right.lifetimeMinutes - left.lifetimeMinutes || left.app.localeCompare(right.app, 'zh-CN');
      if (sort === 'name') return left.app.localeCompare(right.app, 'zh-CN');
      if (sort === 'recent') return (right.lastUsedOrder || 0) - (left.lastUsedOrder || 0) || right.periodMinutes - left.periodMinutes;
      return right.periodMinutes - left.periodMinutes || right.lifetimeMinutes - left.lifetimeMinutes;
    });
  }

  function appIconDataUri(appId, app, color) {
    const marks = {
      codex: '✦', chrome: '◉', wechat: '••', vscode: '〈〉', bilibili: '哔',
      figma: 'F', spotify: '≋', notion: 'N', steam: 'S', obsidian: '◆',
      discord: 'D', photoshop: 'Ps', edge: 'e', explorer: '▰'
    };
    const id = String(appId || '').toLocaleLowerCase('en-US');
    const fallback = String(app || '?').trim().slice(0, 2);
    const mark = marks[id] || fallback;
    const ink = ['figma', 'notion', 'explorer'].includes(id) ? '#10161d' : '#f7fbfc';
    const safeMark = String(mark).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="15" fill="${color || '#55727d'}"/><circle cx="32" cy="30" r="20" fill="rgba(7,14,19,.13)"/><text x="32" y="38" text-anchor="middle" font-family="Arial,sans-serif" font-size="${safeMark.length > 2 ? 18 : 23}" font-weight="700" fill="${ink}">${safeMark}</text></svg>`;
    return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
  }

  function buildClockSegments(records, period) {
    const windowStart = period === 'pm' ? 720 : 0;
    const windowEnd = windowStart + 720;

    return (records || []).flatMap((record) => {
      const rawStart = toMinutes(record.start);
      const rawEnd = Math.max(rawStart, toMinutes(record.end));
      const start = Math.max(windowStart, rawStart);
      const end = Math.min(windowEnd, rawEnd);
      if (end <= start) return [];

      return [{
        ...record,
        minutes: end - start,
        startMinutes: start,
        endMinutes: end,
        startAngle: ((start - windowStart) / 2) - 90,
        endAngle: ((end - windowStart) / 2) - 90
      }];
    });
  }

  function buildCategorySummary(records) {
    const totals = new Map();
    (records || []).forEach((record) => {
      const minutes = Math.max(0, toMinutes(record.end) - toMinutes(record.start));
      const current = totals.get(record.category) || { category: record.category, minutes: 0, color: record.color };
      current.minutes += minutes;
      totals.set(record.category, current);
    });
    return Array.from(totals.values()).sort((a, b) => b.minutes - a.minutes);
  }

  function buildFocusState(segments, focusedId) {
    const focused = (segments || []).find((segment) => segment.id === focusedId);
    return {
      center: focused ? {
        app: focused.app,
        category: focused.category,
        timeRange: `${focused.start} 至 ${focused.end}`,
        duration: formatDuration(focused.minutes)
      } : null,
      segments: (segments || []).map((segment) => ({
        ...segment,
        scale: focused ? (segment.id === focusedId ? 1.12 : 0.97) : 1,
        opacity: focused ? (segment.id === focusedId ? 1 : 0.24) : 1
      }))
    };
  }

  function polarPoint(cx, cy, radius, angle) {
    const radians = angle * Math.PI / 180;
    return {
      x: cx + radius * Math.cos(radians),
      y: cy + radius * Math.sin(radians)
    };
  }

  function describeDonutSector(startAngle, endAngle, innerRadius, outerRadius, cx = 220, cy = 220) {
    const startOuter = polarPoint(cx, cy, outerRadius, endAngle);
    const endOuter = polarPoint(cx, cy, outerRadius, startAngle);
    const startInner = polarPoint(cx, cy, innerRadius, startAngle);
    const endInner = polarPoint(cx, cy, innerRadius, endAngle);
    const largeArc = endAngle - startAngle <= 180 ? 0 : 1;
    return [
      'M', startOuter.x, startOuter.y,
      'A', outerRadius, outerRadius, 0, largeArc, 0, endOuter.x, endOuter.y,
      'L', startInner.x, startInner.y,
      'A', innerRadius, innerRadius, 0, largeArc, 1, endInner.x, endInner.y,
      'Z'
    ].join(' ');
  }

  function escapeMarkup(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  }

  function appMark(app) {
    const marks = {
      Codex: 'Co',
      'Visual Studio Code': 'VS',
      Chrome: 'Ch',
      '微信': '微',
      '哔哩哔哩': '哔',
      Figma: 'Fi',
      Spotify: 'Sp',
      Notion: 'No'
    };
    return marks[app] || String(app || '?').slice(0, 2);
  }

  function renderClockSvg(segments, focusedId) {
    const focusState = buildFocusState(segments, focusedId);
    return focusState.segments.map((segment) => {
      const gap = segment.minutes >= 10 ? 1.2 : 0.35;
      const sectorPath = describeDonutSector(segment.startAngle + gap, segment.endAngle - gap, 108, 184);
      const midpoint = (segment.startAngle + segment.endAngle) / 2;
      const marker = polarPoint(220, 220, 147, midpoint);
      const focusedClass = segment.id === focusedId ? ' is-focused' : '';
      const label = `${segment.app}，${segment.start} 至 ${segment.end}，${formatDuration(segment.minutes)}`;
      const iconHref = appIconDataUri(segment.appId || segment.id, segment.app, segment.color);
      return `<g data-app-id="${escapeMarkup(segment.id)}" class="dial-app${focusedClass}" tabindex="0" role="button" aria-label="${escapeMarkup(label)}" style="--segment-opacity:${segment.opacity};--segment-scale:${segment.scale}">
        <path class="dial-sector" d="${sectorPath}" fill="${escapeMarkup(segment.color)}"></path>
        <rect class="dial-app-mark" x="${(marker.x - 18).toFixed(2)}" y="${(marker.y - 18).toFixed(2)}" width="36" height="36" rx="10"></rect>
        <image class="dial-app-icon" href="${iconHref}" x="${(marker.x - 15).toFixed(2)}" y="${(marker.y - 15).toFixed(2)}" width="30" height="30" preserveAspectRatio="xMidYMid slice"></image>
        <title>${escapeMarkup(label)}</title>
      </g>`;
    }).join('');
  }

  function initializeBrowserDemo() {
    if (typeof document === 'undefined') return;

    const records = [
      { id: 'codex-am', appId: 'codex', app: 'Codex', category: '开发', start: '08:12', end: '09:40', color: '#61cfc3' },
      { id: 'chrome-am', appId: 'chrome', app: 'Chrome', category: '浏览', start: '09:40', end: '10:10', color: '#73a9ed' },
      { id: 'wechat', appId: 'wechat', app: '微信', category: '社交', start: '10:10', end: '10:32', color: '#76d37d' },
      { id: 'vscode', appId: 'vscode', app: 'Visual Studio Code', category: '开发', start: '10:32', end: '11:20', color: '#61cfc3' },
      { id: 'chrome-late-am', appId: 'chrome', app: 'Chrome', category: '浏览', start: '11:20', end: '11:45', color: '#73a9ed' },
      { id: 'notion', appId: 'notion', app: 'Notion', category: '创作', start: '13:15', end: '13:50', color: '#d7b870' },
      { id: 'figma', appId: 'figma', app: 'Figma', category: '创作', start: '14:00', end: '14:35', color: '#d7b870' },
      { id: 'codex-pm', appId: 'codex', app: 'Codex', category: '开发', start: '14:45', end: '15:45', color: '#61cfc3' },
      { id: 'chrome-pm', appId: 'chrome', app: 'Chrome', category: '浏览', start: '16:20', end: '16:50', color: '#73a9ed' },
      { id: 'bilibili', appId: 'bilibili', app: '哔哩哔哩', category: '视频', start: '19:10', end: '20:05', color: '#e97aa8' },
      { id: 'spotify', appId: 'spotify', app: 'Spotify', category: '音乐', start: '20:10', end: '20:44', color: '#73ca92' }
    ];

    const rangeContent = {
      week: {
        context: '本周记录', total: '31h 24m', days: '6 个记录日',
        fact: '开发是本周出现时间最长的类别，周三的记录最完整。',
        labels: ['一', '二', '三', '四', '五', '六', '日'], values: [4.2, 5.1, 6.8, 4.7, 5.9, 3.2, 1.6]
      },
      month: {
        context: '8月记录', total: '126h 18m', days: '19 个记录日',
        fact: '这个月的时间分布较稳定，开发与浏览共同构成主要记录。',
        labels: ['第1周', '第2周', '第3周', '第4周', '第5周'], values: [26, 31, 38, 24, 7]
      },
      year: {
        context: '2026年记录', total: '1,184h', days: '196 个记录日',
        fact: '从春季开始，创作类应用的占比逐步增加。',
        labels: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月'], values: [98, 112, 126, 142, 158, 171, 184, 193]
      }
    };

    const appCatalogSeed = [
      { appId: 'codex', app: 'Codex', category: '开发', color: '#61cfc3', lifetimeMinutes: 18000, day: 148, week: 490, lastUsed: '今天 15:45', lastUsedOrder: 1400, sessions: 2 },
      { appId: 'chrome', app: 'Chrome', category: '浏览', color: '#73a9ed', lifetimeMinutes: 16000, day: 85, week: 340, lastUsed: '今天 16:50', lastUsedOrder: 1500, sessions: 3 },
      { appId: 'vscode', app: 'Visual Studio Code', category: '开发', color: '#55a9e8', lifetimeMinutes: 13500, day: 48, week: 260, lastUsed: '今天 11:20', lastUsedOrder: 1300, sessions: 1 },
      { appId: 'wechat', app: '微信', category: '社交', color: '#76d37d', lifetimeMinutes: 10500, day: 22, week: 150, lastUsed: '今天 10:32', lastUsedOrder: 1200, sessions: 1 },
      { appId: 'notion', app: 'Notion', category: '创作', color: '#e8ecef', lifetimeMinutes: 9000, day: 35, week: 140, lastUsed: '今天 13:50', lastUsedOrder: 1250, sessions: 1 },
      { appId: 'figma', app: 'Figma', category: '创作', color: '#e8b96a', lifetimeMinutes: 8000, day: 35, week: 120, lastUsed: '今天 14:35', lastUsedOrder: 1350, sessions: 1 },
      { appId: 'bilibili', app: '哔哩哔哩', category: '视频', color: '#e97aa8', lifetimeMinutes: 7300, day: 55, week: 110, lastUsed: '今天 20:05', lastUsedOrder: 1700, sessions: 1 },
      { appId: 'spotify', app: 'Spotify', category: '音乐', color: '#73ca92', lifetimeMinutes: 6200, day: 34, week: 90, lastUsed: '今天 20:44', lastUsedOrder: 1800, sessions: 1 },
      { appId: 'steam', app: 'Steam', category: '游戏', color: '#406789', lifetimeMinutes: 5600, day: 0, week: 60, lastUsed: '昨天 23:18', lastUsedOrder: 900, sessions: 0 },
      { appId: 'obsidian', app: 'Obsidian', category: '笔记', color: '#8468c8', lifetimeMinutes: 5000, day: 0, week: 50, lastUsed: '8月19日', lastUsedOrder: 700, sessions: 0 },
      { appId: 'discord', app: 'Discord', category: '社交', color: '#6876d7', lifetimeMinutes: 4300, day: 0, week: 40, lastUsed: '8月18日', lastUsedOrder: 600, sessions: 0 },
      { appId: 'photoshop', app: 'Adobe Photoshop', category: '创作', color: '#4a9bd8', lifetimeMinutes: 3800, day: 0, week: 20, lastUsed: '8月16日', lastUsedOrder: 500, sessions: 0 },
      { appId: 'edge', app: 'Microsoft Edge', category: '浏览', color: '#5ab9ad', lifetimeMinutes: 3400, day: 0, week: 10, lastUsed: '8月12日', lastUsedOrder: 400, sessions: 0 },
      { appId: 'explorer', app: '文件资源管理器', category: '系统', color: '#e6c467', lifetimeMinutes: 2000, day: 0, week: 4, lastUsed: '8月10日', lastUsedOrder: 300, sessions: 0 }
    ];
    const appCatalog = appCatalogSeed.map((item) => ({
      ...item,
      periods: {
        day: item.day,
        week: item.week,
        month: Math.round(item.week * 4.02),
        year: Math.round(item.week * 37.7)
      }
    }));

    const state = { halfday: 'am', lockedId: null, range: 'day', privacy: false, libraryQuery: '', librarySort: 'period', showInactive: true };
    const $ = (selector, root = document) => root.querySelector(selector);
    const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
    const totalMinutes = records.reduce((sum, record) => sum + toMinutes(record.end) - toMinutes(record.start), 0);
    const appTotals = Array.from(records.reduce((totals, record) => {
      const minutes = toMinutes(record.end) - toMinutes(record.start);
      const current = totals.get(record.appId) || { ...record, id: record.appId, minutes: 0, sessions: 0 };
      current.minutes += minutes;
      current.sessions += 1;
      totals.set(record.appId, current);
      return totals;
    }, new Map()).values()).sort((a, b) => b.minutes - a.minutes);

    const showToast = (message) => {
      const toast = $('#toast');
      toast.textContent = message;
      toast.classList.add('is-visible');
      window.clearTimeout(showToast.timer);
      showToast.timer = window.setTimeout(() => toast.classList.remove('is-visible'), 2200);
    };

    const renderTicks = () => {
      const tickRoot = $('#clock-ticks');
      tickRoot.innerHTML = Array.from({ length: 48 }, (_, index) => {
        const angle = index * 7.5 - 90;
        const outer = polarPoint(220, 220, 202, angle);
        const inner = polarPoint(220, 220, index % 4 === 0 ? 190 : 195, angle);
        return `<line class="clock-tick${index % 4 === 0 ? ' is-major' : ''}" x1="${inner.x.toFixed(2)}" y1="${inner.y.toFixed(2)}" x2="${outer.x.toFixed(2)}" y2="${outer.y.toFixed(2)}"></line>`;
      }).join('');
    };

    const resetCenter = () => {
      $('.center-kicker').textContent = '今日已记录';
      $('#center-total').textContent = formatDuration(totalMinutes).replace(' 小时 ', 'h ').replace(' 分钟', 'm');
      $('#center-detail').textContent = `${appTotals.length} 个应用 · ${records.length} 段记录`;
      $('#center-hint').textContent = '滑过扇区查看应用';
    };

    const applyDialFocus = (id) => {
      const segments = buildClockSegments(records, state.halfday);
      const focus = buildFocusState(segments, id);
      $$('.dial-app', $('#clock-sectors')).forEach((node) => {
        const isFocused = node.dataset.appId === id;
        node.classList.toggle('is-focused', isFocused);
        node.style.setProperty('--segment-scale', id ? (isFocused ? 1.12 : .97) : 1);
        node.style.setProperty('--segment-opacity', id ? (isFocused ? 1 : .24) : 1);
      });
      if (!focus.center) {
        resetCenter();
        return;
      }
      $('.center-kicker').textContent = focus.center.category;
      $('#center-total').textContent = state.privacy ? '隐藏应用' : focus.center.app;
      $('#center-detail').textContent = focus.center.timeRange;
      $('#center-hint').textContent = focus.center.duration;
    };

    const renderClock = () => {
      const segments = buildClockSegments(records, state.halfday);
      $('#clock-sectors').innerHTML = renderClockSvg(segments, state.lockedId);
      resetCenter();
      if (state.lockedId) applyDialFocus(state.lockedId);
    };

    const renderCategories = (target, multiplier = 1) => {
      const summary = buildCategorySummary(records);
      const total = summary.reduce((sum, item) => sum + item.minutes, 0);
      $(target).innerHTML = summary.map((item) => {
        const percentage = Math.round(item.minutes / total * 100);
        const apps = Array.from(new Set(records.filter((record) => record.category === item.category).map((record) => record.app))).join('、');
        return `<div class="category-row" style="--category-color:${item.color}">
          <span class="category-dot" aria-hidden="true"></span>
          <span class="category-name"><strong>${item.category}</strong><span>${state.privacy ? '应用名称已隐藏' : apps}</span></span>
          <span class="category-time"><strong>${formatDuration(item.minutes * multiplier)}</strong><span>${percentage}%</span></span>
        </div>`;
      }).join('');
    };

    const openDetail = (recordOrTotal) => {
      const record = recordOrTotal;
      const minutes = record.minutes || toMinutes(record.end) - toMinutes(record.start);
      $('#detail-app-icon').innerHTML = `<img src="${appIconDataUri(record.appId || record.id, record.app, record.color)}" alt="">`;
      $('#detail-app-icon').style.background = 'transparent';
      $('#detail-category').textContent = record.category;
      $('#detail-app-name').textContent = state.privacy ? '应用名称已隐藏' : record.app;
      $('#detail-duration').textContent = formatDuration(minutes);
      $('#detail-start').textContent = record.start;
      $('#detail-end').textContent = record.end;
      $('#detail-copy').textContent = `${record.start} 至 ${record.end} 留在${state.privacy ? '这个应用' : record.app}。该时间来自前台与运行活动记录。`;
      const panel = $('#app-detail-panel');
      panel.classList.add('is-open');
      panel.setAttribute('aria-hidden', 'false');
      $('#detail-close').focus();
    };

    const renderTimeline = () => {
      $('#timeline-track').innerHTML = records.map((record) => {
        const start = toMinutes(record.start);
        const minutes = toMinutes(record.end) - start;
        return `<button type="button" class="timeline-block" data-record-id="${record.id}" style="left:${(start / 1440 * 100).toFixed(3)}%;width:${(minutes / 1440 * 100).toFixed(3)}%;--block-color:${record.color}" aria-label="${record.app}，${record.start} 至 ${record.end}">
          <strong>${state.privacy ? '••' : appMark(record.app)}</strong><small>${record.start}</small>
        </button>`;
      }).join('');
    };

    const renderRanking = (target = '#ranking-list', compact = false) => {
      $(target).innerHTML = appTotals.slice(0, compact ? 4 : 5).map((item, index) => `<button type="button" class="ranking-row" data-app-total="${item.appId}">
        <span class="ranking-index">${String(index + 1).padStart(2, '0')}</span>
        <span class="app-icon" style="--app-color:${item.color}"><img src="${appIconDataUri(item.appId, item.app, item.color)}" alt=""></span>
        <span class="ranking-app"><strong>${state.privacy ? '应用名称已隐藏' : item.app}</strong><span>${item.category} · ${item.sessions} 段记录</span></span>
        <span class="ranking-time"><strong>${formatDuration(item.minutes)}</strong><span>${Math.round(item.minutes / totalMinutes * 100)}%</span></span>
      </button>`).join('');
    };

    const renderAppLibrary = () => {
      const allPeriodRows = buildAppLibrary(appCatalog, state.range, { query: '', sort: 'period', showInactive: true });
      const rows = buildAppLibrary(appCatalog, state.range, {
        query: state.libraryQuery,
        sort: state.librarySort,
        showInactive: state.showInactive
      });
      const periodTotal = allPeriodRows.reduce((sum, item) => sum + item.periodMinutes, 0);
      const lifetimeTotal = appCatalog.reduce((sum, item) => sum + item.lifetimeMinutes, 0);
      const activeCount = allPeriodRows.filter((item) => item.periodMinutes > 0).length;
      const rangeWords = { day: '今日', week: '本周', month: '本月', year: '本年' };
      $('#library-lifetime-total').textContent = formatCompactDuration(lifetimeTotal);
      $('#library-app-count').textContent = `${appCatalog.length} 个应用 · ${rangeWords[state.range]} ${activeCount} 个活跃`;
      $('#overview-lifetime-total').textContent = formatCompactDuration(lifetimeTotal);
      $('#overview-active-apps').textContent = `${activeCount} / ${appCatalog.length}`;
      $('#app-library-list').innerHTML = rows.length ? rows.map((item) => {
        const percentage = periodTotal > 0 ? Math.round(item.periodMinutes / periodTotal * 100) : 0;
        const hiddenName = state.privacy ? '应用名称已隐藏' : item.app;
        return `<div class="app-library-row${item.periodMinutes === 0 ? ' is-inactive' : ''}" role="row" data-library-app="${item.appId}">
          <div class="library-app-cell" role="cell">
            <img src="${appIconDataUri(item.appId, item.app, item.color)}" alt="">
            <span><strong>${hiddenName}</strong><small>${item.category} · ${item.sessions || 0} 段记录</small></span>
          </div>
          <div class="library-period-cell" role="cell">
            <strong>${formatCompactDuration(item.periodMinutes)}</strong>
            <span><i style="--usage-width:${percentage}%"></i></span>
            <small>${item.periodMinutes ? `${percentage}%` : '本期未使用'}</small>
          </div>
          <div class="library-lifetime-cell" role="cell"><strong>${formatCompactDuration(item.lifetimeMinutes)}</strong><small>累计总时长</small></div>
          <div class="library-recent-cell" role="cell"><strong>${item.lastUsed}</strong><small>${item.periodMinutes ? rangeWords[state.range] + '有记录' : '保留历史记录'}</small></div>
        </div>`;
      }).join('') : `<div class="library-empty">没有符合条件的应用。试试清除搜索或显示本期未使用的软件。</div>`;
    };

    const renderTrend = (range) => {
      const content = rangeContent[range];
      const max = Math.max(...content.values);
      $('#aggregate-context').textContent = content.context;
      $('#aggregate-total').textContent = content.total;
      $('#aggregate-days').textContent = content.days;
      $('#aggregate-fact').textContent = content.fact;
      $('#trend-description').textContent = range === 'week' ? '每日记录时长' : range === 'month' ? '每周记录时长' : '每月记录时长';
      $('#trend-chart').innerHTML = content.values.map((value, index) => `<div class="trend-bar-wrap">
        <span class="trend-value">${value}h</span>
        <span class="trend-bar" style="--bar-height:${Math.max(3, value / max * 170)}px"></span>
        <span class="trend-label">${content.labels[index]}</span>
      </div>`).join('');
      const factor = range === 'week' ? 4.05 : range === 'month' ? 16.3 : 153;
      renderCategories('#aggregate-category-list', factor);
      renderRanking('#aggregate-ranking-list', true);
    };

    const selectRange = (range) => {
      state.range = range;
      $$('.range-tabs button').forEach((button) => button.setAttribute('aria-selected', String(button.dataset.range === range)));
      const daily = range === 'day';
      $('#daily-view').hidden = !daily;
      $('#daily-view').classList.toggle('is-visible', daily);
      $('#aggregate-view').hidden = daily;
      $('#aggregate-view').classList.toggle('is-visible', !daily);
      const labels = { day: '8月21日 · 星期五', week: '8月17日 至 8月23日', month: '2026年8月', year: '2026年' };
      $('#period-label').textContent = labels[range];
      $('#next-period').disabled = true;
      if (!daily) renderTrend(range);
      renderAppLibrary();
    };

    renderTicks();
    renderClock();
    renderCategories('#category-list');
    renderTimeline();
    renderRanking();
    renderAppLibrary();

    const requestedRange = new URLSearchParams(window.location.search).get('range');
    if (['week', 'month', 'year'].includes(requestedRange)) selectRange(requestedRange);
    const requestedFocus = new URLSearchParams(window.location.search).get('focus');
    if (requestedFocus && records.some((record) => record.id === requestedFocus)) applyDialFocus(requestedFocus);

    $('#clock-sectors').addEventListener('pointerover', (event) => {
      const target = event.target.closest('.dial-app');
      if (target && !state.lockedId) applyDialFocus(target.dataset.appId);
    });
    $('#clock-sectors').addEventListener('pointerleave', () => {
      if (!state.lockedId) applyDialFocus(null);
    });
    $('#clock-sectors').addEventListener('focusin', (event) => {
      const target = event.target.closest('.dial-app');
      if (target && !state.lockedId) applyDialFocus(target.dataset.appId);
    });
    $('#clock-sectors').addEventListener('click', (event) => {
      const target = event.target.closest('.dial-app');
      if (!target) return;
      state.lockedId = state.lockedId === target.dataset.appId ? null : target.dataset.appId;
      applyDialFocus(state.lockedId);
      const record = records.find((item) => item.id === target.dataset.appId);
      if (state.lockedId && record) openDetail(record);
    });
    $('#clock-sectors').addEventListener('keydown', (event) => {
      if (event.key !== 'Enter' && event.key !== ' ') return;
      event.preventDefault();
      event.target.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });

    $$('.halfday-toggle button').forEach((button) => button.addEventListener('click', () => {
      state.halfday = button.dataset.halfday;
      state.lockedId = null;
      $$('.halfday-toggle button').forEach((item) => item.classList.toggle('is-active', item === button));
      renderClock();
    }));
    $$('.range-tabs button').forEach((button) => button.addEventListener('click', () => selectRange(button.dataset.range)));

    $('#timeline-track').addEventListener('pointerover', (event) => {
      const block = event.target.closest('.timeline-block');
      if (!block || state.lockedId) return;
      const record = records.find((item) => item.id === block.dataset.recordId);
      if (!record) return;
      const nextHalfday = toMinutes(record.start) < 720 ? 'am' : 'pm';
      if (state.halfday !== nextHalfday) {
        state.halfday = nextHalfday;
        $$('.halfday-toggle button').forEach((item) => item.classList.toggle('is-active', item.dataset.halfday === nextHalfday));
        renderClock();
      }
      applyDialFocus(record.id);
    });
    $('#timeline-track').addEventListener('pointerleave', () => { if (!state.lockedId) applyDialFocus(null); });
    $('#timeline-track').addEventListener('click', (event) => {
      const block = event.target.closest('.timeline-block');
      const record = block && records.find((item) => item.id === block.dataset.recordId);
      if (record) openDetail(record);
    });

    $$('.ranking-list').forEach((list) => list.addEventListener('click', (event) => {
      const row = event.target.closest('.ranking-row');
      const total = row && appTotals.find((item) => item.appId === row.dataset.appTotal);
      if (total) openDetail(total);
    }));

    $('#detail-close').addEventListener('click', () => {
      const panel = $('#app-detail-panel');
      panel.classList.remove('is-open');
      panel.setAttribute('aria-hidden', 'true');
      state.lockedId = null;
      applyDialFocus(null);
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && $('#app-detail-panel').classList.contains('is-open')) $('#detail-close').click();
    });

    $('#privacy-toggle').addEventListener('click', (event) => {
      state.privacy = !state.privacy;
      event.currentTarget.setAttribute('aria-pressed', String(state.privacy));
      document.body.classList.toggle('is-private', state.privacy);
      renderCategories('#category-list');
      renderTimeline();
      renderRanking();
      renderAppLibrary();
      if (state.range !== 'day') renderTrend(state.range);
      showToast(state.privacy ? '应用名称已隐藏' : '应用名称已显示');
    });
    $('#export-button').addEventListener('click', () => showToast('Demo：已生成隐私预览，未写入本地文件'));
    $('#manage-categories').addEventListener('click', () => showToast('分类管理将在正式实现中连接用户配置'));
    $('#expand-timeline').addEventListener('click', () => showToast('已显示全部 11 段有效记录，零碎时刻为 0 段'));
    $('#previous-period').addEventListener('click', () => showToast(`已切换到上一${state.range === 'day' ? '天' : state.range === 'week' ? '周' : state.range === 'month' ? '月' : '年'}的演示数据`));
    $('#period-label').addEventListener('click', () => showToast('正式版本中这里打开日期选择器'));
    $('#app-library-search').addEventListener('input', (event) => {
      state.libraryQuery = event.currentTarget.value;
      renderAppLibrary();
    });
    $('#app-library-sort').addEventListener('change', (event) => {
      state.librarySort = event.currentTarget.value;
      renderAppLibrary();
    });
    $('#show-inactive-apps').addEventListener('change', (event) => {
      state.showInactive = event.currentTarget.checked;
      renderAppLibrary();
    });
    $$('[data-shell-page]').forEach((button) => button.addEventListener('click', () => {
      if (button.dataset.shellPage !== 'stats') showToast(`${button.querySelector('strong').textContent}保持现有实现，本 Demo 不修改`);
    }));
    if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
    window.requestAnimationFrame(() => window.scrollTo(0, 0));
  }

  const api = {
    appIconDataUri,
    buildAppLibrary,
    buildClockSegments,
    buildCategorySummary,
    buildFocusState,
    describeDonutSector,
    formatCompactDuration,
    renderClockSvg,
    formatDuration,
    toMinutes
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  globalScope.TimeArcStatsDemo = api;
  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeBrowserDemo);
    else initializeBrowserDemo();
  }
})(typeof window !== 'undefined' ? window : globalThis);
