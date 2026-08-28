import QtQuick
import QtQuick.Layouts
import "../memorylake"
import "../components/AppVisual.js" as AppVisual
import "../../shared/I18n.js" as I18n
import "../components/PlatformCursor.js" as Cursor
import "StatsViewModel.js" as StatsViewModel

// v88「统计」页（暗玻璃全幅复刻）。规范：docs/stats-functional-replication.md /
// stats-render-pipeline-replication.md / stats-backend-data-gaps.md。
// 背景三件套（蓝黑渐变 + 42px 方格 + 双角辉光）由 DesktopAppShell 的 fullBleed 层提供
// （已把 "stats" 加入 fullBleedPage + 栅格 visible）；本页只放内容，暗底自然透出。
// 数据全部来自只读后端（UsageStatManager 读 service DB + DailyCardService 本地聚合，数据由
// 本页传入，维持 db_smoke 契约）；缺真实来源处走诚实占位（G5），零写入（C11）。
Item {
    id: root
    anchors.fill: parent
    clip: true
    focus: true

    // —— 主题契约（由 DesktopAppShell.applyThemeToLoadedPage 注入）——
    property bool nightMode: false
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FBF8F4"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"
    property string languageMode: "zh"

    function tr(source) { return I18n.t(languageMode, source) }
    function sentence(key, params) { return I18n.sentence(languageMode, key, params) }

    // 顶栏「返回首页」/ ESC 切页：Shell 在 onLoaded 连接（已含 stats）。
    signal requestNavigate(string pageKey)

    // 记忆湖统一色板（单一事实源 G1）。夜=暗玻璃霓虹，昼=浅瓷；由 night 切换。
    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        accentSeed: root.themeAccentColor
        injectedTextPrimary: root.themeTextPrimary
        injectedTextSecondary: root.themeTextSecondary
    }

    // ============================================================
    // 状态
    // ============================================================
    property string range: "day"         // 默认先看今天；周/月/年保留聚合视图
    property int periodOffset: 0          // 期次偏移（0=本期，负=过去；不超过本期）
    property int refreshTick: 0           // bump 触发派生绑定重算
    // 重算去重：仅当数据代际 / 范围 / 期次三者之一变化才做昂贵聚合（5s Timer 空闲 tick 跳过，
    // 修复长期卡顿——否则每 5s 重做整窗聚合 + 分类）。
    property int _builtGen: -1
    property string _builtRange: ""
    property int _builtOffset: 2147483647

    // 缓存视图模型（rebuild() 重算，避免在绑定里反复调用后端聚合）
    property var vmApps: []
    property var vmSegments: []
    property int vmTotalSec: 0
    property var vmShare: []
    property string vmShareTotalText: ""
    property var vmMetrics: []
    property var vmBars: []               // 周 7 / 年 12；月为空
    property var vmHeat: []               // 月热力 [{level,day,seconds}]
    property var vmLine: []               // 月周趋势 [{x,y,seconds}]
    property var vmRanking: []
    property var vmCategories: []
    property var vmTrendBars: []
    property var vmAggregateFact: null
    property var vmRingArcs: []           // 日视图分类环：当前半天的弧
    property var vmRingStats: null        // 降噪账目（丢弃/吸收计数），用于卡片脚注
    property var vmRingLegend: []         // 环内类别 + **未过滤**真实秒数
    property var _ringRuns: null          // 全天降噪结果：AM/PM 切换只重投影，不重算
    property var vmLifetimeApps: []
    property var vmLibraryRows: []
    property int vmLifetimeTotalSec: 0
    property string vmInsight: ""
    property var vmRecs: []
    property var vmKeywords: []
    property string vmPeriodLabel: ""     // 顶栏期次标签（周/月/年窗口）
    property string clockHalf: "am"
    property string libraryQuery: ""
    property string librarySort: "period"
    property bool showInactiveApps: true

    readonly property bool hasData: vmTotalSec > 0 || (vmApps && vmApps.length > 0)
    readonly property bool sideCollapsed: root.width < 1200   // ≤1200 左栏折叠（C10）
    readonly property bool statsLayoutStacked: root.width < 900 // 桌面统计在常见 1100px 内容区保持左右布局
    readonly property bool atCurrentPeriod: periodOffset >= 0 // 已是本期/无更新一期（禁「下一期」）

    // 切范围回到本期；offset 非 0 时复位会触发 onPeriodOffsetChanged→rebuild（单次）。
    onRangeChanged: { if (periodOffset !== 0) periodOffset = 0; else rebuild() }
    onPeriodOffsetChanged: rebuild()
    onLanguageModeChanged: { _builtGen = -1; rebuild() }
    // 类别色 / 热力色都是按主题派生的（AppVisual.buildCategoryColors 吃 night），
    // 而 Canvas 不会跟踪它绘制时读到的 token。夜间模式可以在本页上被 macOS 菜单栏
    // 切换，去重守卫会把「只有主题变了」当成无事发生，于是环、刻度和每个类别色点
    // 都留在上一个主题里。和 onLanguageModeChanged 同一处理：让守卫失效、重算一次。
    onNightModeChanged: { _builtGen = -1; rebuild() }
    onClockHalfChanged: reprojectCategoryRing()
    onLibraryQueryChanged: rebuildLibrary()
    onLibrarySortChanged: rebuildLibrary()
    onShowInactiveAppsChanged: rebuildLibrary()

    // ============================================================
    // 工具：时间格式 / 范围文案
    // ============================================================
    function rangeWord(r) { return r === "day" ? tr("Day") : r === "week" ? tr("Week") : r === "month" ? tr("Month") : tr("Year") }
    // 日视图可以用期次导航翻到过去某天，那时「今天」是错的；vmPeriodLabel 已经是
    // 本地化的日期（8月28日 / Aug 28）。周/月/年的期次标签自带日期，标题保持不变。
    function rangeLabel(r) {
        if (r === "day") return periodOffset === 0 ? tr("Today") : vmPeriodLabel
        return r === "week" ? tr("This Week") : r === "month" ? tr("This Month") : tr("This Year")
    }
    function isEnglish() { return I18n.langKey(languageMode) === "en" }
    function weekdayShortLabels() { return I18n.weekdaysNarrow(languageMode) }
    function monthShortLabels() { return isEnglish() ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] }

    function aggregateContextText() {
        if (range === "week") return tr("Recorded this week")
        return vmPeriodLabel + tr("Records")
    }

    function aggregateUnitLabel() {
        return range === "year" ? tr("Active months") : tr("Recorded days")
    }

    function aggregateTrendSubtitle() {
        if (range === "month") return tr("Weekly recorded time")
        if (range === "year") return tr("Monthly recorded time")
        return tr("Daily recorded time")
    }

    function recentRecordText(unixSec) {
        var value = Number(unixSec || 0)
        if (value <= 0) return "—"
        var date = new Date(value * 1000)
        var now = new Date()
        var startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        var startDate = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
        var timeText = Qt.formatTime(date, "HH:mm")
        if (startDate === startToday) return tr("Today") + " " + timeText
        if (startDate === startToday - 86400000) return tr("Yesterday") + " " + timeText
        return I18n.monthDay(languageMode, date)
    }

    function secondsToDisplay(seconds) {
        var total = Math.max(0, Math.floor(seconds ? seconds : 0))
        if (total <= 0) return "0m"
        if (total < 60) return "<1m"
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    function withCommas(n) {
        return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }
    // 指标大号值：<100h 取一位小数（42.6h），≥100h 取整带千分位（1,862h）。
    function hoursText(seconds) {
        var h = (seconds ? seconds : 0) / 3600
        if (h <= 0) return "0h"
        if (h < 100) return (Math.round(h * 10) / 10).toFixed(1) + "h"
        return withCommas(h) + "h"
    }

    // ============================================================
    // 派生算法（全部基于真实只读返回值，QML 端派生；不造假）
    // ============================================================
    // 本页唯一的分类口径。`category` 是 C++ 聚合后的结果：逐记录按时长加权投票，
    // 且吃过读层过滤（关「游戏识别」会把它改写成 other）；`adapterCategory` 只是规则
    // 元数据，任何过滤都不碰它，而 aggregateSoftware() 明确规定「规则不再覆盖这个
    // 投票」。AppVisual.modelCategory() 的优先级正好相反，两套口径混用就是环、图例
    // 和占比饼互相打架的原因（见 StatsViewModel.ringRawCategory 的同一处说明）。
    // 与 StatsViewModel.ringRawCategory 同一优先级：段行（foregroundSegments*）只带
    // adapterCategory，所以它留作兜底，而不是首选。
    function rowCategory(row) {
        if (!row) return "other"
        var value = row.category ? String(row.category).trim() : ""
        if (value.length === 0 && row.adapterCategory)
            value = String(row.adapterCategory).trim()
        return value.length > 0 ? value : "other"
    }

    function categorySums(apps) {
        var sums = {}
        for (var i = 0; i < apps.length; i++) {
            var c = rowCategory(apps[i])
            sums[c] = (sums[c] ? sums[c] : 0) + (apps[i].seconds ? apps[i].seconds : 0)
        }
        return sums
    }

    function topCategory(cat) {
        var best = "", bestSec = -1
        for (var k in cat) {
            if (k === "system" || k === "other") continue
            if (cat[k] > bestSec) { bestSec = cat[k]; best = k }
        }
        return best
    }

    // 类别色：从该类别里用得最多的应用的**图标色**推，再去撞色（AppVisual）。
    // 用户在设置里选过色则直接用那个色。整表随数据刷新重算一次并缓存。
    property var categoryColorMap: ({})

    function rebuildCategoryColors(apps) {
        var sums = categorySums(apps)
        var seedOf = {}, secOf = {}
        for (var i = 0; i < apps.length; i++) {
            var c = rowCategory(apps[i])
            var sec = apps[i].seconds ? apps[i].seconds : 0
            if (secOf[c] === undefined || sec > secOf[c]) {
                secOf[c] = sec
                var cols = apps[i].iconColors
                seedOf[c] = (cols && cols.length > 0) ? cols[0] : AppVisual.modelAppColor(apps[i])
            }
        }
        var ids = []
        for (var k in sums) ids.push(k)
        ids.sort(function (a, b) { return sums[b] - sums[a] })
        var userColors = {}
        if (typeof categorizationManager !== "undefined" && categorizationManager) {
            var defs = categorizationManager.categories()
            for (var d = 0; d < defs.length; d++)
                if (defs[d].color && defs[d].color.length > 0)
                    userColors[defs[d].id] = defs[d].color
        }
        var entries = []
        for (var j = 0; j < ids.length; j++)
            entries.push({ id: ids[j], seed: seedOf[ids[j]], color: userColors[ids[j]] })
        categoryColorMap = AppVisual.buildCategoryColors(entries, root.nightMode)
        return categoryColorMap
    }

    function categoryHeatBase(category) {
        var c = categoryColorMap[category]
        return c ? c : (root.nightMode ? "#4A5568" : "#8BCF9A")
    }

    // 类别名：规则表是唯一来源（含用户自建类别），英语优先、其它语言回退。
    function categoryLabel(categoryId) {
        if (!categoryId)
            return ""
        if (typeof categorizationManager !== "undefined" && categorizationManager)
            return categorizationManager.categoryLabel(categoryId)
        return categoryId
    }

    function heatColor(category, level) {
        if (level <= 0)
            return root.nightMode ? "#161B22" : "#EBEDF0"
        var c = Qt.lighter(categoryHeatBase(category), 1.0)
        var h = c.hslHue
        if (h < 0 || isNaN(h))
            return root.nightMode ? "#78C98F" : "#9ED9A8"
        var l = root.nightMode
                ? (0.20 + level * 0.075)
                : (0.88 - level * 0.080)
        var s = Math.min(0.68, Math.max(0.42, c.hslSaturation * 0.86))
        return Qt.hsla(h, s, l, 1.0)
    }

    function dateKeyFromUnix(sec) {
        var d = new Date(sec * 1000)
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }

    function dayCategorySums(segs, apps) {
        var byGroup = {}
        for (var i = 0; i < apps.length; i++) {
            var k = apps[i].groupKey ? apps[i].groupKey : apps[i].appId
            if (k)
                byGroup[k] = rowCategory(apps[i])
        }
        var out = {}
        for (var s = 0; s < segs.length; s++) {
            var row = segs[s]
            var key = row.groupKey ? row.groupKey : row.appId
            var cat = byGroup[key] || rowCategory(row)
            var list = row.segments ? row.segments : []
            for (var j = 0; j < list.length; j++) {
                var start = list[j].startUnixSec ? Number(list[j].startUnixSec) : 0
                var end = list[j].endUnixSec ? Number(list[j].endUnixSec) : start
                while (end > start) {
                    var d = new Date(start * 1000)
                    var next = Math.floor(new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1, 0, 0, 0, 0).getTime() / 1000)
                    var partEnd = Math.min(end, next)
                    var dk = dateKeyFromUnix(start)
                    if (!out[dk]) out[dk] = {}
                    out[dk][cat] = (out[dk][cat] ? out[dk][cat] : 0) + Math.max(0, partEnd - start)
                    if (partEnd <= start) break
                    start = partEnd
                }
            }
        }
        return out
    }

    function dominantDayCategory(daySums) {
        var best = "other", bestSec = -1
        for (var k in daySums) {
            if (k === "system" || k === "other") continue
            if (daySums[k] > bestSec) { bestSec = daySums[k]; best = k }
        }
        if (bestSec >= 0)
            return best
        for (var any in daySums)
            return any
        return "other"
    }

    // 期次窗口（任意周/月/年；offset：0=本期、负=过去）。end 取末秒（闭区间，
    // 与 C++ matchesRange 当前周期 / dailySecondsForRange / *ForWindow 同口径）。
    function periodWindow(r, off) {
        var now = new Date()
        if (r === "day") {
            var day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + off, 0, 0, 0, 0)
            var nextDay = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1, 0, 0, 0, 0)
            return { start: Math.floor(day.getTime() / 1000), end: Math.floor(nextDay.getTime() / 1000) - 1,
                     label: fmtMD(day), kind: "day" }
        } else if (r === "week") {
            var dow = (now.getDay() + 6) % 7
            var mon = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dow + off * 7, 0, 0, 0, 0)
            var s = Math.floor(mon.getTime() / 1000)
            var sun = new Date(mon.getFullYear(), mon.getMonth(), mon.getDate() + 6)
            // end 由真实「下周一本地零点」推得（非固定 7*86400 秒），DST 周也与 month/年同 DST-safe，
            // 与 C++ matchesRange("week") 按日窗口对齐。
            var nextMon = new Date(mon.getFullYear(), mon.getMonth(), mon.getDate() + 7, 0, 0, 0, 0)
            return { start: s, end: Math.floor(nextMon.getTime() / 1000) - 1, label: fmtMD(mon) + " – " + fmtMD(sun), kind: "week" }
        } else if (r === "month") {
            var d0 = new Date(now.getFullYear(), now.getMonth() + off, 1, 0, 0, 0, 0)
            var d1 = new Date(now.getFullYear(), now.getMonth() + off + 1, 1, 0, 0, 0, 0)
            return { start: Math.floor(d0.getTime() / 1000), end: Math.floor(d1.getTime() / 1000) - 1,
                     y: d0.getFullYear(), m: d0.getMonth() + 1,
                     // 期次标签一律走 I18n：这里曾手写 year + "年" + month + "月"，
                     // 被一次机械的 "年"->"Year" 替换改成了 "2026Year8Month"（该分支
                     // 只在非英文时才走到）。yearMonth() 是同一段文案的唯一实现。
                     label: I18n.yearMonth(languageMode, d0), kind: "month" }
        } else {
            var y = now.getFullYear() + off
            var y0 = new Date(y, 0, 1, 0, 0, 0, 0), y1 = new Date(y + 1, 0, 1, 0, 0, 0, 0)
            return { start: Math.floor(y0.getTime() / 1000), end: Math.floor(y1.getTime() / 1000) - 1,
                     y: y, label: I18n.yearLabel(languageMode, y), kind: "year" }
        }
    }
    function fmtMD(d) { return I18n.monthDay(languageMode, d) }
    // 已过天数（本期到今天为止；过去期 = 整窗），供日均。
    function periodElapsedDays(win) {
        var nowSec = Math.floor(Date.now() / 1000)
        var endSec = Math.min(win.end, nowSec)
        if (endSec < win.start) return 0
        return Math.floor((endSec - win.start) / 86400) + 1
    }

    function activePeriodUnitCount() {
        var rows = range === "month" ? vmHeat : vmBars
        var count = 0
        for (var i = 0; rows && i < rows.length; i++) {
            if (!rows[i].empty && Number(rows[i].seconds || 0) > 0) count++
        }
        return count
    }
    // 环比字串（升=绿/降=粉）；无上一周期真实数据→空（不显示假箭头 C6/A-7）。
    function changeStr(curSec, prevSec, hasPrev) {
        if (!hasPrev) return { change: "", down: false }
        var d = curSec - prevSec
        return { change: (d >= 0 ? "+" : "") + (Math.round((d / 3600) * 10) / 10).toFixed(1) + "h", down: d < 0 }
    }

    // 切换次数（A-4 / G-4 QML 派生）：摊平所有前台会话段、按起始排序、相邻 groupKey 不同计数。
    function computeSwitchCount(segments) {
        var flat = []
        for (var i = 0; i < segments.length; i++) {
            var grp = segments[i].groupKey
            var segs = segments[i].segments ? segments[i].segments : []
            for (var j = 0; j < segs.length; j++)
                flat.push({ key: grp, start: segs[j].startUnixSec })
        }
        flat.sort(function (a, b) { return a.start - b.start })
        var switches = 0
        for (var k = 1; k < flat.length; k++)
            if (flat[k].key !== flat[k - 1].key) switches++
        return switches
    }

    function longestUse(segments) {
        var best = null
        for (var i = 0; i < segments.length; i++)
            if (!best || (segments[i].longestSec ? segments[i].longestSec : 0) > (best.longestSec ? best.longestSec : 0))
                best = segments[i]
        return best
    }

    // 周 7 柱：foregroundDailySecondsForRange(窗口) 真实逐日前台（周一→周日；任意周）。
    function computeWindowDailyBars(win) {
        if (!usageStatManager || !usageStatManager.foregroundDailySecondsForRange) return []
        var series = usageStatManager.foregroundDailySecondsForRange(win.start, win.end)
        if (!series) series = []
        var labels = weekdayShortLabels()
        var maxSec = 1
        for (var i = 0; i < series.length; i++)
            if ((series[i].seconds ? series[i].seconds : 0) > maxSec) maxSec = series[i].seconds
        var bars = []
        for (var j = 0; j < series.length && j < 7; j++) {
            var sec = series[j].seconds ? series[j].seconds : 0
            bars.push({ label: labels[j], ratio: sec / maxSec, valueText: secondsToDisplay(sec), seconds: sec })
        }
        return bars
    }

    // 年 12 柱（G-7）：foregroundMonthlySecondsForYear 单遍聚合（替代 12 次逐月聚合）。
    function computeYearBars(year) {
        if (!usageStatManager || !usageStatManager.foregroundMonthlySecondsForYear) return []
        var series = usageStatManager.foregroundMonthlySecondsForYear(year)
        if (!series) series = []
        var labels = monthShortLabels()
        var maxSec = 1
        for (var i = 0; i < series.length; i++)
            if ((series[i].seconds ? series[i].seconds : 0) > maxSec) maxSec = series[i].seconds
        var bars = []
        for (var m = 0; m < 12 && m < series.length; m++) {
            var sec = series[m].seconds ? series[m].seconds : 0
            bars.push({ label: labels[m], ratio: sec / maxSec, valueText: secondsToDisplay(sec), seconds: sec })
        }
        return bars
    }

    // 月热力（A-2：按当月最大单日秒数分 5 级 0/≤25/≤50/≤75/>75）。
    // daily 来自 foregroundDailySecondsForRange（dayStartUnix）；兼容旧 .day 字段。
    function computeHeat(daily, segs, apps) {
        var maxSec = 0
        for (var i = 0; i < daily.length; i++)
            if ((daily[i].seconds ? daily[i].seconds : 0) > maxSec) maxSec = daily[i].seconds
        var byDayCategory = dayCategorySums(segs ? segs : [], apps ? apps : [])
        var cells = []
        if (daily.length > 0) {
            var firstDate = new Date((daily[0].dayStartUnix ? daily[0].dayStartUnix : 0) * 1000)
            var firstDow = (firstDate.getDay() + 6) % 7
            for (var p = 0; p < firstDow; p++)
                cells.push({ level: 0, day: "", dateKey: "", seconds: 0, empty: true, category: "other" })
        }
        for (var j = 0; j < daily.length; j++) {
            var sec = daily[j].seconds ? daily[j].seconds : 0
            var lv = 0
            if (maxSec > 0 && sec > 0) {
                var r = sec / maxSec
                lv = r > 0.75 ? 4 : r > 0.50 ? 3 : r > 0.25 ? 2 : 1
            }
            var day = daily[j].day !== undefined ? daily[j].day
                      : new Date((daily[j].dayStartUnix ? daily[j].dayStartUnix : 0) * 1000).getDate()
            var dateKey = daily[j].dayStartUnix ? dateKeyFromUnix(daily[j].dayStartUnix) : ""
            var cat = dateKey && byDayCategory[dateKey] ? dominantDayCategory(byDayCategory[dateKey]) : "other"
            cells.push({ level: lv, day: day, dateKey: dateKey, seconds: sec, empty: false, category: cat, color: heatColor(cat, lv) })
        }
        while (cells.length > 0 && cells.length % 7 !== 0)
            cells.push({ level: 0, day: "", dateKey: "", seconds: 0, empty: true, category: "other" })
        return cells
    }

    // 月周趋势（按周一为首分桶求每周总秒，归一化折线）。daily 用 dayStartUnix 还原日期。
    function computeWeekTrendFromDaily(daily) {
        var buckets = {}, order = []
        for (var i = 0; i < daily.length; i++) {
            var dt = new Date((daily[i].dayStartUnix ? daily[i].dayStartUnix : 0) * 1000)
            var dow = (dt.getDay() + 6) % 7
            var mon = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate() - dow)
            var key = mon.getTime()
            if (buckets[key] === undefined) { buckets[key] = 0; order.push(key) }
            buckets[key] += daily[i].seconds ? daily[i].seconds : 0
        }
        order.sort(function (a, b) { return a - b })
        var maxSec = 1
        for (var k = 0; k < order.length; k++) if (buckets[order[k]] > maxSec) maxSec = buckets[order[k]]
        var n = order.length, pts = []
        for (var j = 0; j < n; j++)
            pts.push({ x: n > 1 ? j / (n - 1) : 0.5, y: buckets[order[j]] / maxSec, seconds: buckets[order[j]] })
        return pts
    }

    // 月关键词（memoryLakeRecap 真实 keywords slide；数据由本页传入，维持 db_smoke 契约）。
    function monthKeywords(monthApps, monthSegs, prevApps, dailySeries) {
        if (typeof dailyCardService === "undefined" || !dailyCardService) return []
        var recap = dailyCardService.memoryLakeRecap(monthApps, monthSegs,
                                                     prevApps ? prevApps : [], dailySeries ? dailySeries : [])
        var slides = (recap && recap.slides) ? recap.slides : []
        for (var i = 0; i < slides.length; i++)
            if (slides[i].type === "keywords") return slides[i].keywords ? slides[i].keywords : []
        return []
    }

    // 高频应用排行：activeSoftwareForRange top-N join foregroundSegmentsForRange.sessionCount。
    function buildRanking(apps, segs, n) {
        var byKey = {}
        for (var i = 0; i < segs.length; i++) byKey[segs[i].groupKey] = segs[i].sessionCount ? segs[i].sessionCount : 0
        var sorted = apps.slice().sort(function (a, b) { return (b.seconds ? b.seconds : 0) - (a.seconds ? a.seconds : 0) })
        var totalSeconds = 0
        for (var totalIndex = 0; totalIndex < sorted.length; totalIndex++)
            totalSeconds += sorted[totalIndex].seconds ? sorted[totalIndex].seconds : 0
        var out = []
        for (var j = 0; j < sorted.length && j < n; j++) {
            var a = sorted[j]
            var key = a.groupKey ? a.groupKey : a.appId
            out.push({ name: AppVisual.modelDisplayName(a) || "Unknown app",
                       groupKey: key, path: a.path ? a.path : "",
                       appId: a.appId ? a.appId : "",
                       appName: a.appName ? a.appName : "",
                       adapterIdentifier: a.adapterIdentifier ? a.adapterIdentifier : "",
                       sourceType: a.sourceType ? a.sourceType : "",
                       adapterDisplayName: a.adapterDisplayName ? a.adapterDisplayName : "",
                       adapterCategory: a.adapterCategory ? a.adapterCategory : "",
                       brandColor: a.brandColor ? a.brandColor : "",
                       iconSource: a.iconSource ? a.iconSource : "",
                       iconPath: a.iconPath ? a.iconPath : "",
                       iconUrl: a.iconUrl ? a.iconUrl : "",
                       iconLabel: a.iconLabel ? a.iconLabel : "",
                       category: rowCategory(a),
                       seconds: a.seconds ? a.seconds : 0,
                       time: a.time ? a.time : secondsToDisplay(a.seconds ? a.seconds : 0),
                       sessions: byKey[key] !== undefined ? byKey[key] : 0,
                       percent: totalSeconds > 0 ? Math.round((a.seconds ? a.seconds : 0) * 100 / totalSeconds) : 0 })
        }
        return out
    }

    // Ring arcs intentionally carry only compact app summaries. Rehydrate them
    // from the period model so the focused sector can show the real app icons.
    function clockArcApps(summaries) {
        var source = summaries ? summaries : []
        var apps = vmApps ? vmApps : []
        var out = []
        for (var i = 0; i < source.length; i++) {
            var summary = source[i]
            var full = null
            for (var j = 0; j < apps.length; j++) {
                var key = apps[j].groupKey ? apps[j].groupKey : apps[j].appId
                if (key === summary.groupKey) { full = apps[j]; break }
            }
            var row = {}
            if (full)
                for (var name in full) row[name] = full[name]
            for (var summaryName in summary) row[summaryName] = summary[summaryName]
            out.push(row)
        }
        return out
    }

    // 分类环（日视图）：整天降噪一次 → 按当前半天投影。降噪与 AM/PM 无关，
    // 缓存后切半天只走 reprojectCategoryRing()，不重跑扫描线（性能文档口径）。
    // 分类环只在**日视图**渲染（StatsCategoryClock 的 visible: range === "day"），而且
    // reprojectCategoryRing 永远只投影某一天的半个 12 小时盘。此前不论哪个范围都照算，
    // 于是周/月/年把整段窗口的会话段喂进一条二次复杂度的管线，算完再整个丢掉：
    // 实测月/年 ~2.9s（3253 行 → 12 条弧，且那张卡根本不可见）。这里直接不算。
    // 环所依赖的三个视图态（runs/stats/legend）一起清空，免得留着上一个范围的残值。
    function rebuildCategoryRing() {
        if (range !== "day") {
            _ringRuns = null
            vmRingStats = null
            vmRingLegend = []
            vmRingArcs = []
            return
        }
        var built = StatsViewModel.buildCategoryRingRuns(
                    vmSegments ? vmSegments : [], vmApps ? vmApps : [])
        _ringRuns = built.runs
        vmRingStats = built.stats
        rebuildRingLegend()
        reprojectCategoryRing()
    }

    function reprojectCategoryRing() {
        if (!_ringRuns) { vmRingArcs = []; return }
        var win = periodWindow("day", range === "day" ? periodOffset : 0)
        vmRingArcs = StatsViewModel.projectCategoryRing(_ringRuns, win.start, clockHalf)
    }

    // 环的形状被降噪过，脚注把折叠掉的量说清楚（C6：不静悄悄吃掉记录）。
    // 「折叠」= 短记录并进相邻块（时间还在环上）；「丢弃」= 前后都是空档、
    // 无处可并，是唯一真正离开环的时间，所以分开计。
    function ringFootnote() {
        if (!vmRingStats) return ""
        var folded = vmRingStats.absorbedCount ? vmRingStats.absorbedCount : 0
        var dropped = vmRingStats.droppedCount ? vmRingStats.droppedCount : 0
        if (folded > 0 && dropped > 0)
            return sentence("ringFoldedAndDropped", { folded: folded, dropped: dropped })
        if (folded > 0) return sentence("ringFoldedOnly", { folded: folded })
        if (dropped > 0) return sentence("ringDroppedOnly", { dropped: dropped })
        return ""
    }

    // 图例：类别取自环（全天，不随 AM/PM 抖动），秒数取自**未过滤**的 vmApps。
    // 环只负责形状；数字始终来自原始聚合，避免与右侧占比饼自相矛盾。
    function rebuildRingLegend() {
        var ids = StatsViewModel.ringCategories(_ringRuns ? _ringRuns : [])
        var sums = categorySums(vmApps ? vmApps : [])
        var rows = []
        for (var i = 0; i < ids.length; i++) {
            var seconds = sums[ids[i]] ? sums[ids[i]] : 0
            rows.push({ id: ids[i], seconds: seconds, time: secondsToDisplay(seconds) })
        }
        vmRingLegend = rows
    }

    // vmAggregateFact 的 category 是类别 id；I18n 的词表按英文源串索引，直接丢进去
    // 会把 "dev" 原样印在句子里（三种语言都一样）。规则表是标签的唯一来源，所以在
    // 这里解析好再交给 I18n 组句——和右边「分类构成」卡走同一条路。
    function aggregateFactText() {
        if (!vmAggregateFact) return ""
        var fact = { key: vmAggregateFact.key, params: {} }
        for (var k in vmAggregateFact.params) fact.params[k] = vmAggregateFact.params[k]
        fact.params.category = categoryLabel(fact.params.category)
        return I18n.aggregateFact(languageMode, fact)
    }

    function rebuildLibrary() {
        vmLibraryRows = StatsViewModel.buildAppLibrary(
                    vmApps ? vmApps : [], vmLifetimeApps ? vmLifetimeApps : [],
                    { query: libraryQuery, sort: librarySort,
                      showInactive: showInactiveApps })
    }

    function dayMetrics(total, apps, lifetimeApps, lifetimeTotal) {
        var longest = lifetimeApps && lifetimeApps.length > 0 ? lifetimeApps[0] : null
        return [
            { title: "Total this period", sub: "Recorded this period", badge: "Day", value: secondsToDisplay(total), change: "", changeDown: false },
            { title: "All apps combined", sub: "All retained records", badge: "Total", value: hoursText(lifetimeTotal), change: "", changeDown: false },
            { title: "Active apps this period", sub: "This period / All", badge: "Day", value: apps.length + " / " + lifetimeApps.length, change: "", changeDown: false },
            { title: "Longest overall", sub: longest ? AppVisual.modelDisplayName(longest) : "—", badge: "Total", value: longest ? StatsViewModel.formatCompactDuration(longest.seconds) : "—", change: "", changeDown: false }
        ]
    }

    // ====== 指标卡模型（每范围 4 张；缺真实环比→change:"" 不显示假箭头 C6）======
    function weekMetrics(total, segs, win, prevSec, hasPrev) {
        var elapsed = Math.max(1, periodElapsedDays(win))
        var lu = longestUse(segs)
        var sw = computeSwitchCount(segs)
        var chg = changeStr(total, prevSec, hasPrev)
        return [
            { title: "This Week Total", sub: "vs last week", badge: "Week", value: hoursText(total),
              change: chg.change ? (chg.change + " " + tr("vs last week")) : "", changeDown: chg.down },
            { title: "Daily Average", sub: "By elapsed days", badge: "Week", value: hoursText(total / elapsed), change: "", changeDown: false },
            // 段行同样带 displayName / customDisplayName；直接印 appName 会露出
            // 进程名（Code.exe），并且无视用户改过的显示名。
            { title: "Longest Continuous Use", sub: lu ? (AppVisual.modelDisplayName(lu) || "—") : "—", badge: "Week",
              value: lu ? hoursText(lu.longestSec) : "—", change: "", changeDown: false },
            { title: "Switches", sub: "Foreground app switches", badge: "Week", value: total > 0 ? sentence("switchCount", {count: sw}) : "—", change: "", changeDown: false }
        ]
    }

    function monthMetrics(total, apps, cat, focusDays, prevSec, hasPrev) {
        var chg = changeStr(total, prevSec, hasPrev)
        // categorySums() 的键是规则表的**类别 id**（dev/office/notes/create/game/
        // video…），不是它们的英文标签——标签只在 categoryLabel() 里为显示而生成。
        // 这里原本查的是 cat["Games"] / cat["Creation"]，永远查不到，于是这两张卡
        // 的百分比恒为 0%。
        var ent = total > 0 ? Math.round(100 * ((cat["game"] ? cat["game"] : 0) + (cat["video"] ? cat["video"] : 0)) / total) : 0
        var crt = total > 0 ? Math.round(100 * ((cat["create"] ? cat["create"] : 0) + (cat["notes"] ? cat["notes"] : 0)) / total) : 0
        return [
            { title: "This Month Total", sub: "vs last month", badge: "Month", value: hoursText(total),
              change: chg.change ? (chg.change + " " + tr("vs last month")) : "", changeDown: chg.down },
            { title: "Focus Days", sub: "Dev/Office/Notes", badge: "Month", value: sentence("dayCount", {count: focusDays}), change: "", changeDown: false },
            { title: "Entertainment Share", sub: "Games + Video", badge: "Month", value: total > 0 ? (ent + "%") : "—", change: "", changeDown: false },
            { title: "Creation Share", sub: "Creation + Notes", badge: "Month", value: total > 0 ? (crt + "%") : "—", change: "", changeDown: false }
        ]
    }

    function yearMetrics(total, apps, bars, focusSeconds, prevSec, hasPrev) {
        var peakIdx = -1, peak = 0
        for (var i = 0; i < bars.length; i++)
            if ((bars[i].seconds ? bars[i].seconds : 0) > peak) { peak = bars[i].seconds; peakIdx = i }
        var chg = changeStr(total, prevSec, hasPrev)
        return [
            { title: "Year Total", sub: "vs last year", badge: "Year", value: hoursText(total),
              change: chg.change ? (chg.change + " " + tr("vs last year")) : "", changeDown: chg.down },
            { title: "Most Active Month", sub: "By monthly time", badge: "Year", value: (peakIdx >= 0 && peak > 0) ? I18n.trendLabel(languageMode, bars[peakIdx]) : "—", change: "", changeDown: false },
            { title: "Year Focus", sub: "Dev/Office/Notes", badge: "Year", value: focusSeconds > 0 ? hoursText(focusSeconds) : "—", change: "", changeDown: false },
            { title: "Opened Apps", sub: "Apps used", badge: "Year", value: apps.length > 0 ? sentence("appCount", {count: apps.length}) : "—", change: "", changeDown: false }
        ]
    }

    // ====== 本地确定性洞察/建议模板（aiGenerated:false；不接真 AI、不喂原始日志 C7）======
    function buildInsight(r, share, total, cat) {
        var label = rangeLabel(r)
        if (total <= 0)
            return sentence("insightNoData", {range: label})
        var topName = (share.length > 0) ? root.categoryLabel(share[0].name) : tr("multiple apps")
        var topPercent = (share.length > 0) ? (share[0].percent + "%") : ""
        var s = sentence("insightMain", {
            range: label,
            app: topName,
            percent: topPercent,
            time: hoursText(total)
        })
        var ent = (cat["game"] ? cat["game"] : 0) + (cat["video"] ? cat["video"] : 0)
        if (total > 0 && ent / total > 0.4) s += " " + tr("Entertainment time is relatively high.")
        return s
    }

    function buildRecs(r, share, total, cat) {
        var recs = []
        if (total <= 0) { recs.push(sentence("rangeNoAdvice", {range: rangeWord(r)})); return recs }
        var topCat = topCategory(cat)
        var sug = tr("Keep the current rhythm.")
        // 同上：topCategory() 返回类别 id，不是英文标签。
        if (topCat === "game") sug = tr("Before entertainment time, finish one key task.")
        else if (topCat === "dev" || topCat === "create" || topCat === "office") sug = tr("Keep the focus rhythm and stand up every 50 minutes.")
        else if (topCat === "notes" || topCat === "browse") sug = tr("Turn scattered browsing into notes and output.")
        else if (topCat === "video" || topCat === "music") sug = tr("Reserve fixed deep-work blocks alongside relaxation.")
        else if (topCat === "social") sug = tr("Watch social time; batch messages for better efficiency.")
        recs.push(sug)
        var ent = (cat["game"] ? cat["game"] : 0) + (cat["video"] ? cat["video"] : 0)
        if (ent / total > 0.4) recs.push(sentence("entertainmentRatioAdvice", {percent: Math.round(100 * ent / total)}))
        else recs.push(tr("Your time structure is balanced. Keep it up."))
        return recs
    }

    // ============================================================
    // 重算 + 数据刷新管线（保留契约：Connections + 5s Timer + refresh）
    // ============================================================
    function rebuild() {
        if (!usageStatManager) return
        // 去重守卫：数据代际/范围/期次都没变→跳过（5s 空闲 tick 不再重算，消除长期卡顿）。
        var gen = usageStatManager.recordsGeneration ? usageStatManager.recordsGeneration() : -1
        if (gen === _builtGen && range === _builtRange && periodOffset === _builtOffset) return
        _builtGen = gen; _builtRange = range; _builtOffset = periodOffset
        var r = range
        var win = periodWindow(r, periodOffset)
        vmPeriodLabel = win.label
        // 本页只读 frontmost_sessions：media_sessions 与前台并发（放视频的同时你在读
        // PDF），两条记录同时为真，混进同一份 app 列表后同一秒会被两个 app 各算一次，
        // 一天于是能超过 24h。整页统一走 foreground* 读路径，别改回 active*。
        var apps = usageStatManager.foregroundSoftwareForWindow(win.start, win.end)
        var segs = usageStatManager.foregroundSegmentsForWindow(win.start, win.end)
        var lifetimeApps = usageStatManager.foregroundApps ? usageStatManager.foregroundApps() : []
        if (!apps) apps = []
        if (!segs) segs = []
        if (!lifetimeApps) lifetimeApps = []
        // 总秒由已取 apps 求和（口径同 foregroundSoftwareSecondsForWindow，省一次全量重聚合 / 5s）。
        var total = 0
        for (var ti = 0; ti < apps.length; ti++) total += apps[ti].seconds ? apps[ti].seconds : 0
        // foregroundApps() 特意保留被隐藏的 app（设置页要靠 allApps() 取消隐藏），而其它每条读路径
        // 都过滤 m_hiddenKeys。本页在计数/取最长之前必须自己滤掉，否则「历史最长」
        // 会点名一个用户明确隐藏的 app，「本期活跃应用」的分母也和下方应用库对不上。
        var visibleLifetime = []
        var lifetimeTotal = 0
        for (var li = 0; li < lifetimeApps.length; li++) {
            if (lifetimeApps[li].hidden) continue
            visibleLifetime.push(lifetimeApps[li])
            lifetimeTotal += lifetimeApps[li].seconds ? lifetimeApps[li].seconds : 0
        }
        vmApps = apps; vmSegments = segs; vmTotalSec = total
        vmLifetimeApps = visibleLifetime; vmLifetimeTotalSec = lifetimeTotal
        rebuildCategoryRing()
        rebuildLibrary()

        var share = []
        if (typeof dailyCardService !== "undefined" && dailyCardService) {
            var day = dailyCardService.memoryLakeDay(apps, segs)
            share = (day && day.usageShare) ? day.usageShare : []
        }
        vmShare = share
        vmShareTotalText = hoursText(total)

        rebuildCategoryColors(apps)
        var cat = categorySums(apps)
        vmRanking = buildRanking(apps, segs, 5)

        // 上一周期环比（WoW/MoM/YoY）+ 专注聚合（焦点类目连续块）。
        var prevWin = periodWindow(r, periodOffset - 1)
        var prevApps = usageStatManager.foregroundSoftwareForWindow(prevWin.start, prevWin.end)
        if (!prevApps) prevApps = []
        var prevSec = 0
        for (var pi = 0; pi < prevApps.length; pi++) prevSec += prevApps[pi].seconds ? prevApps[pi].seconds : 0
        var hasPrev = prevApps.length > 0 && prevSec > 0
        var focus = usageStatManager.foregroundFocusStatsForWindow
                    ? usageStatManager.foregroundFocusStatsForWindow(win.start, win.end) : {}
        if (!focus) focus = {}
        var focusSeconds = focus.focusSeconds ? focus.focusSeconds : 0
        var focusDays = focus.focusDays ? focus.focusDays : 0

        if (r === "day") {
            vmBars = []; vmHeat = []; vmLine = []; vmKeywords = []
            vmMetrics = dayMetrics(total, apps, visibleLifetime, lifetimeTotal)
        } else if (r === "week") {
            vmBars = computeWindowDailyBars(win)
            vmHeat = []; vmLine = []; vmKeywords = []
            vmMetrics = weekMetrics(total, segs, win, prevSec, hasPrev)
        } else if (r === "year") {
            vmBars = computeYearBars(win.y)
            vmHeat = []; vmLine = []; vmKeywords = []
            vmMetrics = yearMetrics(total, apps, vmBars, focusSeconds, prevSec, hasPrev)
        } else {
            var daily = usageStatManager.foregroundDailySecondsForRange(win.start, win.end)
            if (!daily) daily = []
            vmBars = []
            vmHeat = computeHeat(daily, segs, apps)
            vmLine = computeWeekTrendFromDaily(daily)
            vmKeywords = monthKeywords(apps, segs, prevApps, daily)
            vmMetrics = monthMetrics(total, apps, cat, focusDays, prevSec, hasPrev)
        }

        vmTrendBars = r === "day" ? [] : StatsViewModel.normalizeTrendRows(r, r === "month" ? vmLine : vmBars)
        vmCategories = r === "day" ? [] : StatsViewModel.buildCategoryDistribution(apps, 6)
        vmAggregateFact = r === "day" ? null : StatsViewModel.buildAggregateFact(r, vmCategories, vmTrendBars)

        vmInsight = buildInsight(r, share, total, cat)
        vmRecs = buildRecs(r, share, total, cat)
        refreshTick++
    }

    // 导出报告（G-10）：UI 组装真实视图模型为 JSON，C++ 写到下载/文档目录（命名 TimeArc，A-6）。
    function buildExportJson() {
        try {
            var win = periodWindow(range, periodOffset)
            var obj = {
                app: "TimeArc", reportKind: "stats", range: range, period: vmPeriodLabel,
                windowStartUnix: win.start, windowEndUnix: win.end,
                generatedUnix: Math.floor(Date.now() / 1000), aiGenerated: false,
                totalSeconds: vmTotalSec, totalText: hoursText(vmTotalSec),
                metrics: vmMetrics, categoryShare: vmShare, ranking: vmRanking,
                insight: vmInsight, recommendations: vmRecs
            }
            if (range === "week" || range === "year") obj.bars = vmBars
            if (range === "month") { obj.heatmap = vmHeat; obj.weekTrend = vmLine; obj.keywords = vmKeywords }
            return JSON.stringify(obj, null, 2)
        } catch (e) {
            return ""   // 序列化异常→空串，doExport 据此报失败（不假装成功）
        }
    }
    function doExport() {
        if (!usageStatManager || !usageStatManager.exportReport) { showToast("Export is unavailable right now"); return }
        var json = buildExportJson()
        if (!json || json.length === 0) { showToast("Export failed: data serialization error"); return }
        var path = usageStatManager.exportReport("timearc-" + range + "-stats", json)
        showToast(path && path.length > 0 ? sentence("exportedPath", {path: path}) : "Export failed")
    }

    Connections {
        target: usageStatManager
        function onUsageStatsChanged() { root.rebuild() }
    }
    Connections {
        target: projectManager
        function onProjectsChanged() { root.refreshTick += 1 }   // 保留管线契约
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (usageStatManager) usageStatManager.refresh() }   // refresh() 发 usageStatsChanged → rebuild
    }

    Keys.onEscapePressed: root.requestNavigate("memorylake")

    Component.onCompleted: {
        // refresh() 现为增量（便宜），其 usageStatsChanged 同步触发一次 guarded rebuild；
        // 不再额外直接 rebuild()（避免双重重算）。数据已由 app 启动/首页刷新载入。
        if (usageStatManager) usageStatManager.refresh()
        root.forceActiveFocus()
    }

    // 整页入场（对齐日历 openAnim：opacity + 上移 + 轻微放大，ml.easeSnappy）。
    // 自启动（running:true）+ 显式 from，使可见性不依赖 onCompleted 的 JS 执行顺序。
    opacity: 0
    transform: [
        Translate { id: openT; y: 18 },
        Scale { id: openS; origin.x: root.width / 2; origin.y: root.height / 2; xScale: 0.99; yScale: 0.99 }
    ]
    ParallelAnimation {
        id: openAnim
        running: true
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openT; property: "y"; from: 18; to: 0; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openS; property: "xScale"; from: 0.99; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openS; property: "yScale"; from: 0.99; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
    }

    // ============================================================
    // toast（底部胶囊，复用 calToastBg 范式）
    // ============================================================
    function showToast(msg) { statsToast.message = tr(msg); statsToast.shown = true; toastTimer.restart() }

    // ============================================================
    // 范围 Tab 数据
    // ============================================================
    readonly property var rangeModel: [
        { key: "day", label: "Day", glyph: "Day", glyphEn: "D", en: "Day" },
        { key: "week", label: "Week", glyph: "Week", glyphEn: "W", en: "Week" },
        { key: "month", label: "Month", glyph: "Month", glyphEn: "M", en: "Month" },
        { key: "year", label: "Year", glyph: "Year", glyphEn: "Y", en: "Year" }
    ]

    // ============================================================
    // 页面壳：左栏（250）+ 右主区（1fr）
    // ============================================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 16

        // —— 左栏 stats-side ——
        GlassPanel {
            id: sidePanel
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            visible: !root.sideCollapsed
            style: ml
            radius: 22

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                // 品牌块
                FrostCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    style: ml
                    radius: 18
                    tintTop: Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.10 * ml.glowStrength)
                    tintBottom: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.05 * ml.glowStrength)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        Text {
                            text: "TIMEARC STATS"
                            color: ml.aqua
                            font.pixelSize: 11
                            font.weight: 800
                            font.letterSpacing: 0.7
                            font.capitalization: Font.AllUppercase
                        }
                        Text {
                            text: root.tr("Time Stats")
                            color: ml.textPrimary
                            font.pixelSize: 22
                            font.weight: 800
                            font.letterSpacing: 0
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.tr("App Usage · Themes · Trends")
                            color: ml.textSecondary
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

                // 范围 Tab ×3
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: root.rangeModel
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            radius: 14
                            color: root.range === modelData.key ? ml.accentSoft
                                   : (tabMa.containsMouse ? ml.calGhostHover : "transparent")
                            border.width: 1
                            border.color: root.range === modelData.key ? ml.accentSoftBorder : "transparent"
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                spacing: 10
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 30; radius: 11
                                    color: ml.calGhostBg
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isEnglish() ? modelData.glyphEn : root.tr(modelData.glyph)
                                        color: root.range === modelData.key ? ml.aqua : ml.calGlyph
                                        font.pixelSize: 14; font.weight: Font.DemiBold
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        text: root.sentence("rangeView", {range: root.tr(modelData.label)})
                                        color: root.range === modelData.key ? ml.textPrimary : ml.textSecondary
                                        font.pixelSize: 14
                                        font.weight: root.range === modelData.key ? Font.DemiBold : Font.Normal
                                    }
                                    Text {
                                        text: modelData.en
                                        color: ml.textTertiary
                                        font.pixelSize: 10
                                        font.capitalization: Font.AllUppercase
                                    }
                                }
                            }
                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Cursor.button()
                                onClicked: { root.range = modelData.key; root.showToast(root.sentence("switchedRangeView", {range: root.tr(modelData.label)})) }
                            }
                        }
                    }
                }

                // 洞察小卡
                FrostCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    style: ml
                    radius: 18
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        Text {
                            text: root.sentence("rangeInsight", {range: root.rangeWord(root.range)})
                            color: ml.glowCyan
                            font.pixelSize: 11
                            font.weight: 800
                            font.capitalization: Font.AllUppercase
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: root.vmInsight
                            color: ml.textSecondary
                            font.pixelSize: 13
                            lineHeight: 1.45
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignTop
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.tr("Local template · Not AI")
                            color: ml.textTertiary
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        // —— 右主区 stats-main ——
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // 顶栏：标题 + 期次 + 导出 + 返回
            GlassPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                style: ml
                radius: 22

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: root.sentence("rangeStats", {range: root.rangeLabel(root.range)})
                            color: ml.textPrimary
                            font.pixelSize: 22
                            font.weight: 800
                            font.letterSpacing: 0
                        }
                        Text {
                            text: root.hasData ? root.sentence("statsTotalApps", {time: root.hoursText(root.vmTotalSec), count: root.vmApps.length})
                                               : root.tr("No usage records yet")
                            color: ml.textSecondary
                            font.pixelSize: 13
                        }
                    }

                    // 折叠态下的紧凑范围切换（左栏隐藏时）
                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.sideCollapsed
                        Repeater {
                            model: root.rangeModel
                            delegate: Rectangle {
                                required property var modelData
                                width: 44; height: 34; radius: 11
                                color: root.range === modelData.key ? ml.accentSoft : ml.calGhostBg
                                border.width: 1
                                border.color: root.range === modelData.key ? ml.accentSoftBorder : ml.calGhostBorder
                                Text {
                                    anchors.centerIn: parent
                                    text: root.tr(modelData.label)
                                    color: root.range === modelData.key ? ml.aqua : ml.calGlyph
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Cursor.button()
                                    onClicked: { root.range = modelData.key; root.showToast(root.sentence("switchedRangeView", {range: root.tr(modelData.label)})) }
                                }
                            }
                        }
                    }

                    // 期次切换（真实任意窗口 G-9）：‹ 上一期、› 下一期（不超过本期）。
                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        StatsGhostButton { glyph: "‹"; onTapped: root.periodOffset -= 1 }
                        Rectangle {
                            width: Math.max(96, periodText.implicitWidth + 22); height: 38; radius: 13
                            anchors.verticalCenter: parent.verticalCenter
                            color: ml.calGhostBg
                            border.width: 1; border.color: ml.calGhostBorder
                            Text {
                                id: periodText
                                anchors.centerIn: parent
                                text: root.vmPeriodLabel + (root.periodOffset === 0 ? " · " + root.tr("Current") : "")
                                color: ml.calGlyph; font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                        }
                        StatsGhostButton {
                            glyph: "›"
                            dim: root.atCurrentPeriod
                            onTapped: { if (!root.atCurrentPeriod) root.periodOffset += 1; else root.showToast(root.tr("Already at the latest period")) }
                        }
                    }

                    // 导出（真实 G-10：序列化视图模型→JSON 写文件）
                    StatsGhostButton { Layout.alignment: Qt.AlignVCenter; label: "Export"; onTapped: root.doExport() }
                    // 返回首页
                    StatsGhostButton { Layout.alignment: Qt.AlignVCenter; label: "Back Home"; primary: true; onTapped: root.requestNavigate("memorylake") }
                }
            }

            // 滚动卡片网格
            SilkyFlickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                style: ml

                Column {
                    width: scroll.width
                    spacing: 14

                    // —— 共享指标条：一条读完，不再重复四张卡片 ——
                    StatsMetricStrip {
                        width: parent.width
                        height: 88
                        metrics: root.vmMetrics
                    }

                    // —— 空态（诚实占位 C6）——
                    Rectangle {
                        width: parent.width
                        height: 240
                        radius: 22
                        visible: !root.hasData
                        color: ml.panelBg
                        border.width: 1; border.color: ml.panelBorder
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.sentence("rangeNoRecords", {range: root.rangeLabel(root.range)}); color: ml.textSecondary; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.tr("Stats will appear here after background collection records data."); color: ml.textTertiary; font.pixelSize: 13 }
                        }
                    }

                    // ====== 日视图：应用时钟 + 今日组成（明细统一下沉到应用库）======
                    GridLayout {
                        width: parent.width
                        columns: 12
                        columnSpacing: 14
                        rowSpacing: 14
                        visible: root.range === "day" && root.hasData

                        StatsCategoryClock {
                            Layout.columnSpan: root.statsLayoutStacked ? 12 : 8
                            Layout.fillWidth: true
                            Layout.preferredHeight: 486
                            arcs: root.vmRingArcs
                            legend: root.vmRingLegend
                            half: root.clockHalf
                            totalText: root.secondsToDisplay(root.vmTotalSec)
                            footnote: root.ringFootnote()
                            onHalfRequested: function (value) { root.clockHalf = value }
                        }
                        DailyUsageShare {
                            Layout.columnSpan: root.statsLayoutStacked ? 12 : 4
                            Layout.fillWidth: true
                            Layout.preferredHeight: 486
                            style: ml
                            languageMode: root.languageMode
                            glassStrength: 0.45
                            showInsight: false
                            titleKicker: root.periodOffset === 0 ? "Today" : root.vmPeriodLabel
                            titleText: root.periodOffset === 0 ? "What made up today" : "What made up this day"
                            share: root.vmShare
                            total: root.vmShareTotalText
                        }
                    }

                    // ====== 周视图（与月/年共用同一桌面聚合拓扑）======
                    // ====== 周/月/年共用聚合视图 ======
                    GridLayout {
                        width: parent.width
                        columns: 12
                        columnSpacing: 14
                        rowSpacing: 14
                        visible: root.range !== "day" && root.hasData

                        ColumnLayout {
                            id: aggregateOverviewColumn
                            Layout.columnSpan: root.statsLayoutStacked ? 12 : 4
                            Layout.fillWidth: true
                            Layout.preferredHeight: 440
                            spacing: 14

                            StatsAggregateSummary {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 132
                                contextText: root.aggregateContextText()
                                totalText: root.hoursText(root.vmTotalSec)
                                unitValue: root.activePeriodUnitCount()
                                unitLabel: root.aggregateUnitLabel()
                                factText: root.aggregateFactText()
                            }
                            StatsCategoryDistribution {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                rows: root.vmCategories
                            }
                        }
                        StatsBarChart {
                            Layout.columnSpan: root.statsLayoutStacked ? 12 : 8
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.statsLayoutStacked ? 360 : 440
                            title: "Time trend"
                            sub: root.aggregateTrendSubtitle()
                            bars: root.vmTrendBars
                            barCount: root.vmTrendBars.length
                        }
                    }

                    StatsAppLibrary {
                        width: parent.width
                        height: 540
                        visible: root.vmLifetimeApps && root.vmLifetimeApps.length > 0
                        rows: root.vmLibraryRows
                        lifetimeTotalText: root.hoursText(root.vmLifetimeTotalSec)
                    }

                    Item { width: 1; height: 6 }
                }
            }
        }
    }

    // ============================================================
    // toast 胶囊
    // ============================================================
    Rectangle {
        id: statsToast
        property string message: ""
        property bool shown: false
        z: 300
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        implicitWidth: Math.max(180, toastLabel.implicitWidth + 36)
        height: 40
        radius: 20
        color: ml.calToastBg
        border.width: 1; border.color: ml.chipEventBd
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        transform: Translate {
            y: statsToast.shown ? 0 : 10
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy } }
        }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text { id: toastLabel; anchors.centerIn: parent; text: statsToast.message; color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
        Timer { id: toastTimer; interval: 1600; onTriggered: statsToast.shown = false }
    }

    // ============================================================
    // 内联可复用组件（薄封装，避免新增 .qml 文件触碰资源清单）
    // ============================================================

    // ghost 玻璃按钮（顶栏期次/导出/返回）
    component StatsGhostButton: Rectangle {
        id: gbtn
        property string label: ""
        property string glyph: ""
        property bool primary: false
        property bool tip: false
        property bool dim: false           // 置灰（如「下一期」在本期时）
        signal tapped()
        implicitWidth: glyph !== "" ? 38 : Math.min(Math.max(gbtnLabel.implicitWidth + 28, 72), 170)
        height: 38
        radius: 13
        opacity: dim ? 0.4 : 1.0
        color: primary ? "transparent" : (gbtnMa.containsMouse ? ml.calGhostHover : ml.calGhostBg)
        border.width: 1
        border.color: primary ? ml.accentSoftBorder : ml.calGhostBorder
        gradient: primary ? primaryGrad : null
        Gradient {
            id: primaryGrad
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.82) }
            GradientStop { position: 1; color: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.78) }
        }
        Text {
            id: gbtnLabel
            anchors.centerIn: parent
            width: parent.width - 16
            text: gbtn.glyph !== "" ? gbtn.glyph : root.tr(gbtn.label)
            color: gbtn.primary ? ml.calBtnInk : ml.calGlyph
            font.pixelSize: gbtn.glyph !== "" ? 17 : 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        MouseArea {
            id: gbtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Cursor.button()
            preventStealing: true
            onClicked: gbtn.tapped()
        }
    }

    component StatsMetricStrip: Item {
        id: metricStrip
        property var metrics: []

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: ml.cardBorder }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: ml.cardBorder }
        RowLayout {
            anchors.fill: parent
            spacing: 0
            Repeater {
                model: metricStrip.metrics
                delegate: Item {
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        visible: index > 0
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1; height: parent.height - 28
                        color: ml.cardBorder
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { Layout.fillWidth: true; text: root.tr(modelData.title); color: ml.textTertiary; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: root.tr(modelData.sub); color: ml.textTertiary; font.pixelSize: 9; elide: Text.ElideRight }
                        }
                        ColumnLayout {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 4
                            Text { Layout.alignment: Qt.AlignRight; text: modelData.value; color: ml.textPrimary; font.pixelSize: 21; font.weight: 900; font.letterSpacing: -0.5; font.features: { "tnum": 1 } }
                            Text { Layout.alignment: Qt.AlignRight; visible: modelData.change !== ""; text: modelData.change; color: modelData.changeDown ? ml.changeDown : ml.changeUp; font.pixelSize: 9; font.weight: Font.DemiBold }
                        }
                    }
                }
            }
        }
    }

    // 分类环（日视图）：单环 = 一天的时间地图，一段弧 = 一段同类别的连续时间。
    // 旧的三条同心轨道只是为了躲开 60s 合并造成的区间重叠（见 StatsViewModel
    // §3.1 扫描线），半径不承载任何含义；单环把重叠**解掉**而不是藏起来。
    // 环只负责形状：中心总时长与图例秒数仍取未过滤聚合，绝不显示降噪后的数字。
    component StatsCategoryClock: FrostCard {
        id: ringCard
        property var arcs: []
        property var legend: []
        property string half: "am"
        property string totalText: "0m"
        property string footnote: ""
        property string hoveredId: ""
        property string lockedId: ""
        readonly property string activeId: lockedId !== "" ? lockedId : hoveredId
        signal halfRequested(string value)

        // 单环几何：中心 0.64·base、宽 0.17·base（原三轨的径向包络内），
        // 内缘 0.555·base 仍与 0.39·base 的中心盘留有净空。
        readonly property real ringRadiusScale: 0.64
        readonly property real ringWidthScale: 0.17

        readonly property var focusedArc: {
            for (var i = 0; i < arcs.length; i++)
                if (arcs[i].arcId === activeId) return arcs[i]
            return null
        }
        function clockTime(unixSec) {
            return Qt.formatTime(new Date(unixSec * 1000), "HH:mm")
        }

        style: ml
        radius: 18
        onArcsChanged: {
            lockedId = ""
            hoveredId = ""
            ringCanvas.requestPaint()
        }
        onActiveIdChanged: ringCanvas.requestPaint()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: root.tr("Category clock"); color: ml.textPrimary; font.pixelSize: 17; font.weight: Font.DemiBold }
                    // 口径写在脸上：环只画前台记录，中心总时长含音频，两者本就不等。
                    Text { text: root.tr("Grouped into readable 10-minute category blocks; exact totals stay unchanged"); color: ml.textTertiary; font.pixelSize: 12 }
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: [{ key: "am", label: "AM" }, { key: "pm", label: "PM" }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 44; height: 32; radius: 10
                            color: ringCard.half === modelData.key ? ml.accentSoft : ml.calGhostBg
                            border.width: 1
                            border.color: ringCard.half === modelData.key ? ml.accentSoftBorder : ml.calGhostBorder
                            Text { anchors.centerIn: parent; text: modelData.label; color: ringCard.half === modelData.key ? ml.aqua : ml.calGlyph; font.pixelSize: 11; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Cursor.button(); onClicked: ringCard.halfRequested(modelData.key) }
                        }
                    }
                }
            }

            Item {
                id: ringWrap
                Layout.fillWidth: true
                Layout.fillHeight: true

                Canvas {
                    id: ringCanvas
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    antialiasing: true

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2, cy = height / 2
                        var base = Math.min(width, height) / 2
                        var ringRadius = base * ringCard.ringRadiusScale
                        var trackWidth = base * ringCard.ringWidthScale
                        var trackInner = ringRadius - trackWidth / 2
                        var trackOuter = ringRadius + trackWidth / 2

                        // Filled annulus: empty time remains a quiet sector of the dial.
                        ctx.beginPath()
                        ctx.arc(cx, cy, trackOuter, 0, Math.PI * 2, false)
                        ctx.arc(cx, cy, trackInner, Math.PI * 2, 0, true)
                        ctx.closePath()
                        ctx.fillStyle = ml.calSunkBg
                        ctx.fill()

                        // Each category is a filled annular sector. The active
                        // sector grows both inward and outward without changing time.
                        for (var i = 0; i < ringCard.arcs.length; i++) {
                            var arc = ringCard.arcs[i]
                            var dimmed = ringCard.activeId !== "" && ringCard.activeId !== arc.arcId
                            var emphasized = ringCard.activeId === arc.arcId
                            var startDeg = arc.startAngle + 0.15
                            var endDeg = arc.endAngle - 0.15
                            if (endDeg <= startDeg) { startDeg = arc.startAngle; endDeg = arc.endAngle }
                            var start = (startDeg - 90) * Math.PI / 180
                            var end = (endDeg - 90) * Math.PI / 180
                            var inner = trackInner - (emphasized ? base * 0.02 : 0)
                            var outer = trackOuter + (emphasized ? base * 0.03 : 0)
                            ctx.globalAlpha = dimmed ? 0.22 : 1.0
                            ctx.beginPath()
                            ctx.arc(cx, cy, outer, start, end, false)
                            ctx.arc(cx, cy, inner, end, start, true)
                            ctx.closePath()
                            ctx.fillStyle = root.categoryHeatBase(arc.category)
                            ctx.fill()
                        }
                        ctx.globalAlpha = 1.0

                        // Sixty ticks make the dial read as an actual clock;
                        // five-minute marks are longer and stronger.
                        for (var tick = 0; tick < 60; tick++) {
                            var major = tick % 5 === 0
                            var angle = (tick * 6 - 90) * Math.PI / 180
                            var tickInner = base * (major ? 0.89 : 0.925)
                            ctx.strokeStyle = major ? ml.textTertiary : ml.cardBorder
                            ctx.lineWidth = major ? 1.6 : 1
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(cx + Math.cos(angle) * tickInner, cy + Math.sin(angle) * tickInner)
                            ctx.lineTo(cx + Math.cos(angle) * base * 0.97, cy + Math.sin(angle) * base * 0.97)
                            ctx.stroke()
                        }
                    }
                }

                Repeater {
                    model: 12
                    delegate: Text {
                        id: hourNumber
                        required property int index
                        readonly property real hourAngle: ((index + 1) * 30 - 90) * Math.PI / 180
                        readonly property real hourRadius: ringCanvas.width * 0.418
                        width: 22; height: 22
                        x: ringCanvas.x + ringCanvas.width / 2 + Math.cos(hourAngle) * hourRadius - width / 2
                        y: ringCanvas.y + ringCanvas.height / 2 + Math.sin(hourAngle) * hourRadius - height / 2
                        z: 3
                        text: index + 1
                        color: ml.textTertiary
                        font.pixelSize: index === 11 || index === 2 || index === 5 || index === 8 ? 11 : 9
                        font.weight: index === 11 || index === 2 || index === 5 || index === 8 ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Rectangle {
                    anchors.centerIn: ringCanvas
                    width: ringCanvas.width * 0.39; height: width; radius: width / 2
                    z: 5
                    color: ml.panelBg
                    border.width: 1; border.color: ml.panelBorder
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 26
                        spacing: 5
                        Text {
                            width: parent.width
                            text: ringCard.focusedArc ? root.categoryLabel(ringCard.focusedArc.category)
                                                     : (root.periodOffset === 0 ? root.tr("Recorded today") : root.tr("Recorded this period"))
                            color: ringCard.focusedArc ? ml.aqua : ml.textTertiary
                            font.pixelSize: 11; font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: -4
                            visible: ringCard.focusedArc !== null
                            Repeater {
                                model: ringCard.focusedArc ? root.clockArcApps(ringCard.focusedArc.apps).slice(0, 3) : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 30; height: 30; radius: 9
                                    color: AppVisual.modelAppColor(modelData)
                                    border.width: 2; border.color: ml.panelBg
                                    Image {
                                        id: clockArcAppImage
                                        anchors.centerIn: parent; width: 21; height: 21
                                        source: AppVisual.modelIconSource(modelData)
                                        sourceSize.width: 64; sourceSize.height: 64
                                        fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true; mipmap: true
                                        visible: source != "" && status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: AppVisual.modelIconSource(modelData) === "" || clockArcAppImage.status !== Image.Ready
                                        text: AppVisual.modelIconLabel(modelData)
                                        color: "#FFFFFF"; font.pixelSize: 10; font.weight: 900
                                    }
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            // 未聚焦时是**未过滤**的当日总时长，与右侧占比饼同源。
                            text: ringCard.focusedArc ? StatsViewModel.formatCompactDuration(ringCard.focusedArc.seconds) : ringCard.totalText
                            color: ml.textPrimary; font.pixelSize: 29; font.weight: 900
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            width: parent.width
                            text: ringCard.focusedArc
                                  ? root.sentence("dateRange", { from: ringCard.clockTime(ringCard.focusedArc.startUnixSec),
                                                                 to: ringCard.clockTime(ringCard.focusedArc.endUnixSec) })
                                  : root.sentence("appCount", { count: root.vmApps.length })
                            color: ml.textTertiary; font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: ringCanvas
                    z: 8
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: ringCard.hoveredId !== "" ? Cursor.button() : Qt.ArrowCursor
                    function segmentAt(x, y) {
                        var dx = x - width / 2, dy = y - height / 2
                        var radius = Math.sqrt(dx * dx + dy * dy)
                        var base = Math.min(width, height) / 2
                        var ringRadius = base * ringCard.ringRadiusScale
                        // 命中带比可视环略宽，细弧也点得中。
                        if (Math.abs(radius - ringRadius) > base * ringCard.ringWidthScale / 2 + base * 0.02)
                            return ""
                        var angle = (Math.atan2(dy, dx) * 180 / Math.PI + 450) % 360
                        // 弧互不重叠；补宽后的细弧可能与邻弧贴边，取中点最近者。
                        var found = "", bestDelta = 0
                        for (var i = 0; i < ringCard.arcs.length; i++) {
                            var arc = ringCard.arcs[i]
                            if (angle < arc.startAngle || angle > arc.endAngle) continue
                            var delta = Math.abs(angle - (arc.startAngle + arc.endAngle) / 2)
                            if (found === "" || delta < bestDelta) { found = arc.arcId; bestDelta = delta }
                        }
                        return found
                    }
                    onPositionChanged: function (mouse) { ringCard.hoveredId = segmentAt(mouse.x, mouse.y) }
                    onExited: ringCard.hoveredId = ""
                    onClicked: function (mouse) {
                        var hitId = segmentAt(mouse.x, mouse.y)
                        ringCard.lockedId = hitId === ringCard.lockedId ? "" : hitId
                    }
                }
            }

            // 图例 / 明细：图标从环上撤掉后，这一行承担「里面是什么」。
            // 未聚焦 = 全天类别（秒数取未过滤聚合）；聚焦 = 该块里的应用。
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 14
                Repeater {
                    model: ringCard.focusedArc ? ringCard.focusedArc.apps : ringCard.legend
                    delegate: Row {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            width: 9; height: 9; radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: ringCard.focusedArc ? AppVisual.modelAppColor(modelData)
                                                       : root.categoryHeatBase(modelData.id)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ringCard.focusedArc
                                  ? AppVisual.modelDisplayNameForLanguage(modelData, root.languageMode)
                                  : root.categoryLabel(modelData.id)
                            color: ml.textSecondary; font.pixelSize: 11
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ringCard.focusedArc ? StatsViewModel.formatCompactDuration(modelData.seconds)
                                                      : modelData.time
                            color: ml.textTertiary; font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // 诚实脚注：环的形状被降噪过，这里说明折叠掉了多少条短记录。
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: ringCard.footnote !== "" ? ringCard.footnote
                                               : root.tr("Hover to preview, click a block to pin its detail")
                color: ml.textTertiary; font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    component StatsAppLibrary: FrostCard {
        id: libraryCard
        property var rows: []
        property string lifetimeTotalText: "0h"
        style: ml
        radius: 18
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: root.tr("All apps"); color: ml.textPrimary; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { text: root.tr("See each app's records for this period and its running total, beyond the Top ranking"); color: ml.textTertiary; font.pixelSize: 12 }
                }
                ColumnLayout {
                    spacing: 1
                    Text { Layout.alignment: Qt.AlignRight; text: root.tr("All apps, combined records"); color: ml.textTertiary; font.pixelSize: 10 }
                    Text { Layout.alignment: Qt.AlignRight; text: libraryCard.lifetimeTotalText; color: ml.textPrimary; font.pixelSize: 26; font.weight: 900 }
                    Text { Layout.alignment: Qt.AlignRight; text: libraryCard.rows.length + " " + root.tr("apps"); color: ml.textTertiary; font.pixelSize: 10 }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40
                    radius: 11; color: ml.calSunkBg
                    border.width: 1; border.color: librarySearch.activeFocus ? ml.accentSoftBorder : ml.cardBorder
                    Text { anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: ml.textTertiary; font.pixelSize: 14 }
                    TextInput {
                        id: librarySearch
                        anchors.left: parent.left; anchors.leftMargin: 36
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: ml.textPrimary; selectionColor: ml.accentSoft; selectedTextColor: ml.textPrimary
                        font.pixelSize: 12; clip: true
                        onTextChanged: root.libraryQuery = text
                    }
                    Text { anchors.left: librarySearch.left; anchors.verticalCenter: parent.verticalCenter; visible: librarySearch.text.length === 0 && !librarySearch.activeFocus; text: root.tr("Search apps or categories"); color: ml.textTertiary; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: librarySearch.forceActiveFocus(); z: -1 }
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: [{ key: "period", label: "This period" }, { key: "lifetime", label: "Running total" }, { key: "name", label: "Name" }]
                        delegate: Rectangle {
                            required property var modelData
                            width: sortText.implicitWidth + 20; height: 40; radius: 11
                            color: root.librarySort === modelData.key ? ml.accentSoft : ml.calGhostBg
                            border.width: 1; border.color: root.librarySort === modelData.key ? ml.accentSoftBorder : ml.calGhostBorder
                            Text { id: sortText; anchors.centerIn: parent; text: root.tr(modelData.label); color: root.librarySort === modelData.key ? ml.aqua : ml.calGlyph; font.pixelSize: 11; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Cursor.button(); onClicked: root.librarySort = modelData.key }
                        }
                    }
                }
                Row {
                    spacing: 7; Layout.alignment: Qt.AlignVCenter
                    Rectangle {
                        width: 34; height: 20; radius: 10
                        color: root.showInactiveApps ? ml.aqua : ml.calSunkBg
                        border.width: 1; border.color: root.showInactiveApps ? ml.accentSoftBorder : ml.cardBorder
                        Rectangle {
                            width: 14; height: 14; radius: 7; y: 3
                            x: root.showInactiveApps ? parent.width - width - 3 : 3
                            color: root.showInactiveApps ? ml.calBtnInk : ml.textTertiary
                            Behavior on x { NumberAnimation { duration: 130 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Cursor.button(); onClicked: root.showInactiveApps = !root.showInactiveApps }
                    }
                    Text { text: root.tr("Show apps unused this period"); color: ml.textSecondary; font.pixelSize: 11 }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 24
                Text { Layout.fillWidth: true; text: root.tr("App"); color: ml.textTertiary; font.pixelSize: 10 }
                Text { Layout.preferredWidth: 170; text: root.tr("This period"); color: ml.textTertiary; font.pixelSize: 10 }
                Text { Layout.preferredWidth: 130; text: root.tr("Running total"); color: ml.textTertiary; font.pixelSize: 10 }
                Text { Layout.preferredWidth: 140; text: root.tr("Recent records"); color: ml.textTertiary; font.pixelSize: 10 }
            }

            ListView {
                id: libraryList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: libraryCard.rows
                delegate: Rectangle {
                    required property var modelData
                    width: libraryList.width; height: 58
                    color: "transparent"
                    border.width: 0
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: ml.cardBorder }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 2; anchors.rightMargin: 2
                        spacing: 11
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 12
                            color: AppVisual.modelAppColor(modelData)
                            Image {
                                id: libraryAppImage
                                anchors.centerIn: parent; width: 25; height: 25
                                source: AppVisual.modelIconSource(modelData)
                                sourceSize.width: 64; sourceSize.height: 64
                                fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true; mipmap: true
                                visible: source != "" && status === Image.Ready
                            }
                            Text { anchors.centerIn: parent; visible: AppVisual.modelIconSource(modelData) === "" || libraryAppImage.status !== Image.Ready; text: AppVisual.modelIconLabel(modelData); color: root.nightMode ? "#FFFFFF" : "#2D2724"; font.pixelSize: 13; font.weight: 900 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { Layout.fillWidth: true; text: AppVisual.modelDisplayNameForLanguage(modelData, root.languageMode); color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: root.categoryLabel(root.rowCategory(modelData)) + (modelData.periodSeconds > 0 ? " · " + root.tr("Recorded this period") : " · " + root.tr("Unused this period")); color: ml.textTertiary; font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 170; spacing: 4
                            Text { text: modelData.periodTime; color: modelData.periodSeconds > 0 ? ml.textPrimary : ml.textTertiary; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Rectangle {
                                Layout.preferredWidth: 150; Layout.preferredHeight: 3; radius: 2; color: ml.calSunkBg
                                Rectangle { width: parent.width * Math.min(1, modelData.percent / 100); height: parent.height; radius: parent.radius; color: ml.aqua }
                            }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 130; spacing: 2
                            Text { text: modelData.lifetimeTime; color: ml.textPrimary; font.pixelSize: 14; font.weight: 800 }
                            Text { text: root.tr("Running total"); color: ml.textTertiary; font.pixelSize: 9 }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 140; spacing: 2
                            Text { text: root.recentRecordText(modelData.lastUsedUnixSec); color: ml.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text { text: modelData.periodSeconds > 0 ? root.tr("Recorded this period") : root.tr("History"); color: ml.textTertiary; font.pixelSize: 9 }
                        }
                    }
                }
                Text { anchors.centerIn: parent; visible: libraryList.count === 0; text: root.tr("No apps match"); color: ml.textTertiary; font.pixelSize: 12 }
            }
        }
    }

    component StatsAggregateSummary: FrostCard {
        id: aggregateSummary
        property string contextText: ""
        property string totalText: "0m"
        property int unitValue: 0
        property string unitLabel: ""
        property string factText: ""
        style: ml
        radius: 18

        Rectangle {
            anchors.fill: parent
            radius: aggregateSummary.radius
            color: root.nightMode ? Qt.rgba(0.16, 0.50, 0.45, 0.10) : Qt.rgba(0.20, 0.58, 0.50, 0.08)
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: 126
                Layout.alignment: Qt.AlignVCenter
                spacing: 3
                Text {
                    text: aggregateSummary.contextText
                    color: ml.textTertiary
                    font.pixelSize: 11; font.weight: Font.DemiBold
                }
                Text {
                    text: aggregateSummary.totalText
                    color: ml.textPrimary
                    font.pixelSize: 30; font.weight: 900; font.letterSpacing: -0.8
                    font.features: { "tnum": 1 }
                }
                Row {
                    spacing: 5
                    Text { text: aggregateSummary.unitValue; color: ml.accentText; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Text { text: aggregateSummary.unitLabel; color: ml.textTertiary; font.pixelSize: 11 }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: ml.cardBorder
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: aggregateSummary.factText
                color: ml.textSecondary
                font.pixelSize: 12
                lineHeight: 1.45
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }

    component StatsCategoryDistribution: FrostCard {
        id: categoryCard
        property var rows: []
        style: ml
        radius: 18

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: root.tr("Category split"); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { text: root.tr("Keeps only the structure that matters most for this period"); color: ml.textTertiary; font.pixelSize: 12 }
            }
            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Repeater {
                    model: categoryCard.rows ? categoryCard.rows.slice(0, 6) : []
                    delegate: Item {
                        required property var modelData
                        width: parent.width
                        height: 36
                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: ml.cardBorder }
                        RowLayout {
                            anchors.fill: parent
                            spacing: 10
                            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 3; color: root.categoryHeatBase(modelData.name) }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { Layout.fillWidth: true; text: root.categoryLabel(modelData.name); color: ml.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: I18n.appsText(root.languageMode, modelData.apps); color: ml.textTertiary; font.pixelSize: 9; elide: Text.ElideRight }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: 96; spacing: 1
                                Text { Layout.alignment: Qt.AlignRight; text: modelData.time; color: ml.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold }
                                Text { Layout.alignment: Qt.AlignRight; text: modelData.percent + "%"; color: ml.textTertiary; font.pixelSize: 9 }
                            }
                        }
                    }
                }
            }
        }
    }

    // 柱状图卡（周 7 / 年 12）。柱高用 Behavior 平滑跟随数据（避免每 5s 重建重播入场）。
    component StatsBarChart: FrostCard {
        id: chart
        property string title: ""
        property string sub: ""
        property var bars: []
        property int barCount: 7
        style: ml
        radius: 18
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: root.tr(chart.title); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { visible: chart.sub !== ""; text: root.tr(chart.sub); color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                Row {
                    spacing: 7; Layout.alignment: Qt.AlignTop
                    Rectangle { width: 8; height: 8; radius: 2; color: ml.aqua }
                    Text { text: root.tr("Recorded time"); color: ml.textTertiary; font.pixelSize: 10 }
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Row {
                    id: barsRow
                    anchors.fill: parent
                    spacing: 8
                    Repeater {
                        model: chart.barCount
                        delegate: Item {
                            id: barItem
                            required property int index
                            readonly property var bar: (chart.bars && barItem.index < chart.bars.length) ? chart.bars[barItem.index] : null
                            width: (barsRow.width - 8 * (chart.barCount - 1)) / chart.barCount
                            height: barsRow.height
                            readonly property real avail: height - 34

                            Rectangle {
                                id: barRect
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 20
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(42, Math.max(8, parent.width * 0.62))
                                radius: 6
                                height: Math.max(2, barItem.avail * (barItem.bar ? (barItem.bar.ratio ? barItem.bar.ratio : 0) : 0))
                                color: Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, barMa.containsMouse ? 0.96 : 0.72)
                                Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                anchors.bottom: barRect.top
                                anchors.bottomMargin: 3
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: barItem.bar !== null
                                text: barItem.bar ? barItem.bar.valueText : ""
                                color: ml.textSecondary
                                font.pixelSize: chart.barCount > 7 ? 9 : 10; font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: barItem.bar ? I18n.trendLabel(root.languageMode, barItem.bar) : ""
                                color: ml.textTertiary
                                font.pixelSize: chart.barCount > 7 ? 9.5 : 11
                            }
                            MouseArea { id: barMa; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }
            }
        }
    }

}
