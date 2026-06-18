import QtQuick
import QtQuick.Layouts
import "../memorylake"
import "../components/AppVisual.js" as AppVisual
import "../components/I18n.js" as I18n

// v88「统计」页（暗玻璃全幅复刻）。规范：docs/stats-functional-replication.md /
// stats-render-pipeline-replication.md / stats-backend-data-gaps.md。
// 背景三件套（蓝黑渐变 + 42px 方格 + 双角辉光）由 DesktopAppShell 的 fullBleed 层提供
// （已把 "stats" 加入 fullBleedPage + 栅格 visible）；本页只放内容，暗底自然透出。
// 数据全部来自只读后端（UsageStatManager 读 JSONL + DailyCardService 本地聚合，数据由
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
    function sentence(key, params, fallback) { return I18n.sentence(languageMode, key, params, fallback) }

    // 顶栏「返回首页」/ ESC 切页：Shell 在 onLoaded 连接（已含 stats）。
    signal requestNavigate(string pageKey)

    // 记忆湖统一色板（单一事实源 G1）。夜=暗玻璃霓虹，昼=浅瓷；由 night 切换。
    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        injectedTextPrimary: root.themeTextPrimary
        injectedTextSecondary: root.themeTextSecondary
    }

    // ============================================================
    // 状态
    // ============================================================
    property string range: "week"        // 默认周（§2.2 必须）；week 由 G-1 后端支持
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
    property string vmInsight: ""
    property var vmRecs: []
    property var vmKeywords: []
    property string vmPeriodLabel: ""     // 顶栏期次标签（周/月/年窗口）

    readonly property bool hasData: vmTotalSec > 0 || (vmApps && vmApps.length > 0)
    readonly property bool sideCollapsed: root.width < 1200   // ≤1200 左栏折叠（C10）
    readonly property bool atCurrentPeriod: periodOffset >= 0 // 已是本期/无更新一期（禁「下一期」）

    // 切范围回到本期；offset 非 0 时复位会触发 onPeriodOffsetChanged→rebuild（单次）。
    onRangeChanged: { if (periodOffset !== 0) periodOffset = 0; else rebuild() }
    onPeriodOffsetChanged: rebuild()
    onLanguageModeChanged: { _builtGen = -1; rebuild() }

    // ============================================================
    // 工具：时间格式 / 范围文案
    // ============================================================
    function rangeWord(r) { return r === "week" ? tr("周") : r === "month" ? tr("月") : tr("年") }
    function rangeLabel(r) { return r === "week" ? tr("本周") : r === "month" ? tr("本月") : tr("本年") }
    function isEnglish() { return I18n.langKey(languageMode) === "en" }
    function weekdayShortLabels() { return isEnglish() ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] : ["周一", "周二", "周三", "周四", "周五", "周六", "周日"] }
    function heatWeekLabels() { return isEnglish() ? ["Mon", "", "Wed", "", "Fri", "", ""] : ["一", "", "三", "", "五", "", ""] }
    function monthShortLabels() { return isEnglish() ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] : ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"] }

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
    function categorySums(apps) {
        var sums = {}
        for (var i = 0; i < apps.length; i++) {
            var c = apps[i].category ? apps[i].category : "其他"
            sums[c] = (sums[c] ? sums[c] : 0) + (apps[i].seconds ? apps[i].seconds : 0)
        }
        return sums
    }

    function topCategory(cat) {
        var best = "", bestSec = -1
        for (var k in cat) {
            if (k === "系统" || k === "其他") continue
            if (cat[k] > bestSec) { bestSec = cat[k]; best = k }
        }
        return best
    }

    function categoryHeatBase(category) {
        switch (category) {
        case "学习": return "#76B7F2"
        case "笔记": return "#8BC6F0"
        case "开发": return "#7ECF9A"
        case "办公": return "#7DD6D0"
        case "社交": return "#BBA7F2"
        case "创作": return "#E7C86E"
        case "游戏": return "#F2B279"
        case "视频": return "#EE8F9A"
        case "音乐": return "#9FDFAE"
        case "浏览": return "#A9CBEF"
        default: return "#8BCF9A"
        }
    }

    function heatColor(category, level) {
        if (level <= 0)
            return root.nightMode ? "#202A36" : "#EDF1F4"
        var c = Qt.lighter(categoryHeatBase(category), 1.0)
        var h = c.hslHue
        if (h < 0 || isNaN(h))
            return root.nightMode ? "#78C98F" : "#9ED9A8"
        var l = root.nightMode
                ? (0.24 + level * 0.055)
                : (0.90 - level * 0.065)
        var s = Math.min(0.56, Math.max(0.34, c.hslSaturation * 0.72))
        return Qt.hsla(h, s, l, 1.0)
    }

    function dateKeyFromUnix(sec) {
        var d = new Date(sec * 1000)
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }

    function heatDateLabel(cell) {
        if (!cell || !cell.dateKey)
            return ""
        var p = cell.dateKey.split("-")
        if (p.length < 3)
            return "" + (cell.day ? cell.day : "")
        var m = Math.max(1, Math.min(12, parseInt(p[1]) || 1))
        var d = parseInt(p[2]) || cell.day
        return isEnglish() ? (monthShortLabels()[m - 1] + " " + d) : (m + "月" + d + "日")
    }

    function heatTooltipText(cell) {
        var date = heatDateLabel(cell)
        if (!cell || cell.empty)
            return date.length > 0 ? sentence("heatTooltipEmpty", {date: date}, date + " · 暂无使用") : ""
        return sentence("heatTooltip", {
            date: date,
            time: secondsToDisplay(cell.seconds),
            category: I18n.category(languageMode, cell.category)
        }, date + " · " + secondsToDisplay(cell.seconds) + " · " + I18n.category(languageMode, cell.category))
    }

    function dayCategorySums(segs, apps) {
        var byGroup = {}
        for (var i = 0; i < apps.length; i++) {
            var k = apps[i].groupKey ? apps[i].groupKey : apps[i].appId
            if (k)
                byGroup[k] = AppVisual.modelCategory(apps[i])
        }
        var out = {}
        for (var s = 0; s < segs.length; s++) {
            var row = segs[s]
            var key = row.groupKey ? row.groupKey : row.appId
            var cat = byGroup[key] || AppVisual.modelCategory(row) || "其他"
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
        var best = "其他", bestSec = -1
        for (var k in daySums) {
            if (k === "系统" || k === "其他") continue
            if (daySums[k] > bestSec) { bestSec = daySums[k]; best = k }
        }
        if (bestSec >= 0)
            return best
        for (var any in daySums)
            return any
        return "其他"
    }

    // 期次窗口（任意周/月/年；offset：0=本期、负=过去）。end 取末秒（闭区间，
    // 与 C++ matchesRange 当前周期 / dailySecondsForRange / *ForWindow 同口径）。
    function periodWindow(r, off) {
        var now = new Date()
        if (r === "week") {
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
                     label: isEnglish() ? (monthShortLabels()[d0.getMonth()] + " " + d0.getFullYear()) : (d0.getFullYear() + "年" + (d0.getMonth() + 1) + "月"), kind: "month" }
        } else {
            var y = now.getFullYear() + off
            var y0 = new Date(y, 0, 1, 0, 0, 0, 0), y1 = new Date(y + 1, 0, 1, 0, 0, 0, 0)
            return { start: Math.floor(y0.getTime() / 1000), end: Math.floor(y1.getTime() / 1000) - 1,
                     y: y, label: isEnglish() ? String(y) : (y + "年"), kind: "year" }
        }
    }
    function fmtMD(d) { return isEnglish() ? (monthShortLabels()[d.getMonth()] + " " + d.getDate()) : ((d.getMonth() + 1) + "月" + d.getDate() + "日") }
    // 已过天数（本期到今天为止；过去期 = 整窗），供日均。
    function periodElapsedDays(win) {
        var nowSec = Math.floor(Date.now() / 1000)
        var endSec = Math.min(win.end, nowSec)
        if (endSec < win.start) return 0
        return Math.floor((endSec - win.start) / 86400) + 1
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

    // 周 7 柱：dailySecondsForRange(窗口) 真实逐日 active（周一→周日；任意周）。
    function computeWindowDailyBars(win) {
        if (!usageStatManager || !usageStatManager.dailySecondsForRange) return []
        var series = usageStatManager.dailySecondsForRange(win.start, win.end)
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

    // 年 12 柱（G-7）：monthlySecondsForYear 单遍聚合（替代 12 次 activeSoftwareForMonth）。
    function computeYearBars(year) {
        if (!usageStatManager || !usageStatManager.monthlySecondsForYear) return []
        var series = usageStatManager.monthlySecondsForYear(year)
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
    // daily 来自 dailySecondsForRange（dayStartUnix）；兼容旧 .day 字段。
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
                cells.push({ level: 0, day: "", dateKey: "", seconds: 0, empty: true, category: "其他" })
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
            var cat = dateKey && byDayCategory[dateKey] ? dominantDayCategory(byDayCategory[dateKey]) : "其他"
            cells.push({ level: lv, day: day, dateKey: dateKey, seconds: sec, empty: false, category: cat, color: heatColor(cat, lv) })
        }
        while (cells.length > 0 && cells.length % 7 !== 0)
            cells.push({ level: 0, day: "", dateKey: "", seconds: 0, empty: true, category: "其他" })
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
        var out = []
        for (var j = 0; j < sorted.length && j < n; j++) {
            var a = sorted[j]
            var key = a.groupKey ? a.groupKey : a.appId
            out.push({ name: AppVisual.modelDisplayName(a) || "未知应用",
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
                       category: AppVisual.modelCategory(a),
                       seconds: a.seconds ? a.seconds : 0,
                       time: a.time ? a.time : secondsToDisplay(a.seconds ? a.seconds : 0),
                       sessions: byKey[key] !== undefined ? byKey[key] : 0 })
        }
        return out
    }

    // ====== 指标卡模型（每范围 4 张；缺真实环比→change:"" 不显示假箭头 C6）======
    function weekMetrics(total, segs, win, prevSec, hasPrev) {
        var elapsed = Math.max(1, periodElapsedDays(win))
        var lu = longestUse(segs)
        var sw = computeSwitchCount(segs)
        var chg = changeStr(total, prevSec, hasPrev)
        return [
            { title: "本周总使用", sub: "较上周", badge: "周", value: hoursText(total),
              change: chg.change ? (chg.change + " " + tr("较上周")) : "", changeDown: chg.down },
            { title: "日均使用", sub: "按已过天数", badge: "周", value: hoursText(total / elapsed), change: "", changeDown: false },
            { title: "最长连续使用", sub: lu ? (lu.appName ? lu.appName : "—") : "—", badge: "周",
              value: lu ? hoursText(lu.longestSec) : "—", change: "", changeDown: false },
            { title: "切换次数", sub: "前台应用切换", badge: "周", value: total > 0 ? sentence("switchCount", {count: sw}, sw + " 次") : "—", change: "", changeDown: false }
        ]
    }

    function monthMetrics(total, apps, cat, focusDays, prevSec, hasPrev) {
        var chg = changeStr(total, prevSec, hasPrev)
        var ent = total > 0 ? Math.round(100 * ((cat["游戏"] ? cat["游戏"] : 0) + (cat["视频"] ? cat["视频"] : 0)) / total) : 0
        var crt = total > 0 ? Math.round(100 * ((cat["创作"] ? cat["创作"] : 0) + (cat["笔记"] ? cat["笔记"] : 0)) / total) : 0
        return [
            { title: "本月总使用", sub: "较上月", badge: "月", value: hoursText(total),
              change: chg.change ? (chg.change + " " + tr("较上月")) : "", changeDown: chg.down },
            { title: "专注天数", sub: "开发/办公/笔记", badge: "月", value: sentence("dayCount", {count: focusDays}, focusDays + " 天"), change: "", changeDown: false },
            { title: "娱乐占比", sub: "游戏 + 视频", badge: "月", value: total > 0 ? (ent + "%") : "—", change: "", changeDown: false },
            { title: "创作占比", sub: "创作 + 笔记", badge: "月", value: total > 0 ? (crt + "%") : "—", change: "", changeDown: false }
        ]
    }

    function yearMetrics(total, apps, bars, focusSeconds, prevSec, hasPrev) {
        var peakIdx = -1, peak = 0
        for (var i = 0; i < bars.length; i++)
            if ((bars[i].seconds ? bars[i].seconds : 0) > peak) { peak = bars[i].seconds; peakIdx = i }
        var chg = changeStr(total, prevSec, hasPrev)
        return [
            { title: "年度总使用", sub: "较上年", badge: "年", value: hoursText(total),
              change: chg.change ? (chg.change + " " + tr("较上年")) : "", changeDown: chg.down },
            { title: "最活跃月份", sub: "按月度时长", badge: "年", value: (peakIdx >= 0 && peak > 0) ? bars[peakIdx].label : "—", change: "", changeDown: false },
            { title: "年度专注", sub: "开发/办公/笔记", badge: "年", value: focusSeconds > 0 ? hoursText(focusSeconds) : "—", change: "", changeDown: false },
            { title: "打开应用", sub: "使用过的应用", badge: "年", value: apps.length > 0 ? sentence("appCount", {count: apps.length}, apps.length + " 个") : "—", change: "", changeDown: false }
        ]
    }

    // ====== 本地确定性洞察/建议模板（aiGenerated:false；不接真 AI、不喂原始日志 C7）======
    function buildInsight(r, share, total, cat) {
        var label = rangeLabel(r)
        if (total <= 0)
            return sentence("insightNoData", {range: label}, label + "记录较少，暂不下结论。")
        var topName = (share.length > 0) ? I18n.category(languageMode, share[0].name) : tr("多个应用")
        var topPercent = (share.length > 0) ? (share[0].percent + "%") : ""
        var s = sentence("insightMain", {
            range: label,
            app: topName,
            percent: topPercent,
            time: hoursText(total)
        }, label + "你主要把时间花在" + (share.length > 0 ? ("「" + I18n.category(languageMode, share[0].name) + "」（" + share[0].percent + "%）") : "多个应用上") + "，共计 " + hoursText(total) + "。")
        var ent = (cat["游戏"] ? cat["游戏"] : 0) + (cat["视频"] ? cat["视频"] : 0)
        if (total > 0 && ent / total > 0.4) s += " " + tr("其中娱乐时间占比偏高。")
        return s
    }

    function buildRecs(r, share, total, cat) {
        var recs = []
        if (total <= 0) { recs.push(sentence("rangeNoAdvice", {range: rangeWord(r)}, "本" + rangeWord(r) + "暂无足够数据生成建议。")); return recs }
        var topCat = topCategory(cat)
        var sug = tr("继续保持当前节奏。")
        if (topCat === "游戏") sug = tr("进入娱乐时段前，先完成一项关键任务。")
        else if (topCat === "开发" || topCat === "创作" || topCat === "办公") sug = tr("保持专注节奏，建议每 50 分钟起身休息。")
        else if (topCat === "笔记" || topCat === "浏览") sug = tr("把零散浏览沉淀成笔记，形成输出。")
        else if (topCat === "视频" || topCat === "音乐") sug = tr("放松之余，预留固定的深度工作时段。")
        else if (topCat === "社交") sug = tr("留意社交占用，集中处理消息更高效。")
        recs.push(sug)
        var ent = (cat["游戏"] ? cat["游戏"] : 0) + (cat["视频"] ? cat["视频"] : 0)
        if (ent / total > 0.4) recs.push(sentence("entertainmentRatioAdvice", {percent: Math.round(100 * ent / total)}, "娱乐占比约 " + Math.round(100 * ent / total) + "%，可考虑设定每日上限。"))
        else recs.push(tr("时间结构较均衡，继续保持。"))
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
        var apps = usageStatManager.activeSoftwareForWindow(win.start, win.end)
        var segs = usageStatManager.foregroundSegmentsForWindow(win.start, win.end)
        if (!apps) apps = []
        if (!segs) segs = []
        // 总秒由已取 apps 求和（口径同 activeSoftwareSecondsForWindow，省一次全量重聚合 / 5s）。
        var total = 0
        for (var ti = 0; ti < apps.length; ti++) total += apps[ti].seconds ? apps[ti].seconds : 0
        vmApps = apps; vmSegments = segs; vmTotalSec = total

        var share = []
        if (typeof dailyCardService !== "undefined" && dailyCardService) {
            var day = dailyCardService.memoryLakeDay(apps, segs)
            share = (day && day.usageShare) ? day.usageShare : []
        }
        vmShare = share
        vmShareTotalText = hoursText(total)

        var cat = categorySums(apps)
        vmRanking = buildRanking(apps, segs, 4)

        // 上一周期环比（WoW/MoM/YoY）+ 专注聚合（焦点类目连续块）。
        var prevWin = periodWindow(r, periodOffset - 1)
        var prevApps = usageStatManager.activeSoftwareForWindow(prevWin.start, prevWin.end)
        if (!prevApps) prevApps = []
        var prevSec = 0
        for (var pi = 0; pi < prevApps.length; pi++) prevSec += prevApps[pi].seconds ? prevApps[pi].seconds : 0
        var hasPrev = prevApps.length > 0 && prevSec > 0
        var focus = usageStatManager.focusStatsForWindow ? usageStatManager.focusStatsForWindow(win.start, win.end) : {}
        if (!focus) focus = {}
        var focusSeconds = focus.focusSeconds ? focus.focusSeconds : 0
        var focusDays = focus.focusDays ? focus.focusDays : 0

        if (r === "week") {
            vmBars = computeWindowDailyBars(win)
            vmHeat = []; vmLine = []; vmKeywords = []
            vmMetrics = weekMetrics(total, segs, win, prevSec, hasPrev)
        } else if (r === "year") {
            vmBars = computeYearBars(win.y)
            vmHeat = []; vmLine = []; vmKeywords = []
            vmMetrics = yearMetrics(total, apps, vmBars, focusSeconds, prevSec, hasPrev)
        } else {
            var daily = usageStatManager.dailySecondsForRange(win.start, win.end)
            if (!daily) daily = []
            vmBars = []
            vmHeat = computeHeat(daily, segs, apps)
            vmLine = computeWeekTrendFromDaily(daily)
            vmKeywords = monthKeywords(apps, segs, prevApps, daily)
            vmMetrics = monthMetrics(total, apps, cat, focusDays, prevSec, hasPrev)
        }

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
        if (!usageStatManager || !usageStatManager.exportReport) { showToast("导出暂不可用"); return }
        var json = buildExportJson()
        if (!json || json.length === 0) { showToast("导出失败：数据序列化错误"); return }
        var path = usageStatManager.exportReport("timearc-" + range + "-stats", json)
        showToast(path && path.length > 0 ? sentence("exportedPath", {path: path}, "已导出：" + path) : "导出失败")
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
        { key: "week", label: "周", glyph: "周", glyphEn: "W", en: "Week" },
        { key: "month", label: "月", glyph: "月", glyphEn: "M", en: "Month" },
        { key: "year", label: "年", glyph: "年", glyphEn: "Y", en: "Year" }
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
                            text: root.tr("时间统计")
                            color: ml.textPrimary
                            font.pixelSize: 22
                            font.weight: 800
                            font.letterSpacing: 0
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.tr("软件使用 · 主题 · 趋势")
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
                                        text: root.isEnglish() ? modelData.glyphEn : modelData.glyph
                                        color: root.range === modelData.key ? ml.aqua : ml.calGlyph
                                        font.pixelSize: 14; font.weight: Font.DemiBold
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        text: root.sentence("rangeView", {range: root.tr(modelData.label)}, modelData.label + "视图")
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
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.range = modelData.key; root.showToast(root.sentence("switchedRangeView", {range: root.tr(modelData.label)}, "已切换到" + modelData.label + "视图")) }
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
                            text: root.sentence("rangeInsight", {range: root.rangeWord(root.range)}, "本" + root.rangeWord(root.range) + "洞察")
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
                            text: root.tr("本地生成 · 非 AI")
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
                            text: root.sentence("rangeStats", {range: root.rangeLabel(root.range)}, root.rangeLabel(root.range) + "统计")
                            color: ml.textPrimary
                            font.pixelSize: 22
                            font.weight: 800
                            font.letterSpacing: 0
                        }
                        Text {
                            text: root.hasData ? root.sentence("statsTotalApps", {time: root.hoursText(root.vmTotalSec), count: root.vmApps.length}, "共 " + root.hoursText(root.vmTotalSec) + " · " + root.vmApps.length + " 个应用")
                                               : root.tr("暂无使用记录")
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
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.range = modelData.key; root.showToast(root.sentence("switchedRangeView", {range: root.tr(modelData.label)}, "已切换到" + modelData.label + "视图")) }
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
                                text: root.vmPeriodLabel + (root.periodOffset === 0 ? " · " + root.tr("本期") : "")
                                color: ml.calGlyph; font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                        }
                        StatsGhostButton {
                            glyph: "›"
                            dim: root.atCurrentPeriod
                            onTapped: { if (!root.atCurrentPeriod) root.periodOffset += 1; else root.showToast(root.tr("已是最新一期")) }
                        }
                    }

                    // 导出（真实 G-10：序列化视图模型→JSON 写文件）
                    StatsGhostButton { Layout.alignment: Qt.AlignVCenter; label: "导出"; onTapped: root.doExport() }
                    // 返回首页
                    StatsGhostButton { Layout.alignment: Qt.AlignVCenter; label: "返回首页"; primary: true; onTapped: root.requestNavigate("memorylake") }
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

                    // —— 共享指标行（4 卡）——
                    GridLayout {
                        width: parent.width
                        columns: 12
                        columnSpacing: 14
                        rowSpacing: 14
                        Repeater {
                            model: root.vmMetrics
                            delegate: FrostCard {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.columnSpan: root.sideCollapsed ? 3 : 3
                                Layout.preferredHeight: 118
                                style: ml
                                radius: 18
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 4
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text { text: root.tr(modelData.title); color: ml.textSecondary; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: root.tr(modelData.sub); color: ml.textTertiary; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                        }
                                        Rectangle {
                                            visible: modelData.badge !== ""
                                            radius: 13; color: ml.accentSoft
                                            border.width: 1; border.color: ml.accentSoftBorder
                                            implicitWidth: badgeT.implicitWidth + 16; implicitHeight: 24
                                            Text { id: badgeT; anchors.centerIn: parent; text: root.tr(modelData.badge); color: ml.aqua; font.pixelSize: 11; font.weight: Font.DemiBold }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        color: ml.textPrimary
                                        font.pixelSize: 27; font.weight: 900; font.letterSpacing: -0.8
                                        font.features: { "tnum": 1 }
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        visible: modelData.change !== ""
                                        text: modelData.change
                                        color: modelData.changeDown ? ml.changeDown : ml.changeUp
                                        font.pixelSize: 12; font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
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
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.sentence("rangeNoRecords", {range: root.rangeLabel(root.range)}, root.rangeLabel(root.range) + "还没有使用记录"); color: ml.textSecondary; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.tr("后台服务采集到数据后，这里会自动出现统计"); color: ml.textTertiary; font.pixelSize: 13 }
                        }
                    }

                    // ====== 周视图 ======
                    GridLayout {
                        width: parent.width
                        columns: 12
                        columnSpacing: 14
                        rowSpacing: 14
                        visible: root.range === "week" && root.hasData

                        StatsBarChart {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 8
                            Layout.fillWidth: true
                            Layout.preferredHeight: 262
                            title: "每日使用"; sub: "本周 7 天 active 时长"
                            bars: root.vmBars; barCount: 7
                        }
                        DailyUsageShare {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 4
                            Layout.fillWidth: true
                            Layout.preferredHeight: 262
                            style: ml
                            languageMode: root.languageMode
                            glassStrength: 0.45
                            showInsight: false
                            titleKicker: "Category Share"
                            titleText: root.tr("本周主题占比")
                            share: root.vmShare
                            total: root.vmShareTotalText
                        }
                        StatsRankingList {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 7
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            title: "高频应用"; sub: "本周使用排行"
                            rows: root.vmRanking
                        }
                        StatsInsightCard {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 5
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            insight: root.vmInsight
                            recs: root.vmRecs
                            keywords: []
                            onExportRequested: root.doExport()
                        }
                    }

                    // ====== 月视图 ======
                    GridLayout {
                        width: parent.width
                        columns: 12
                        columnSpacing: 14
                        rowSpacing: 14
                        visible: root.range === "month" && root.hasData

                        DailyUsageShare {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 4
                            Layout.fillWidth: true
                            Layout.preferredHeight: 262
                            style: ml
                            languageMode: root.languageMode
                            glassStrength: 0.45
                            showInsight: false
                            titleKicker: "Category Share"
                            titleText: root.tr("本月主题占比")
                            share: root.vmShare
                            total: root.vmShareTotalText
                        }
                        StatsLineChart {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 8
                            Layout.fillWidth: true
                            Layout.preferredHeight: 262
                            title: "周趋势"; sub: "本月各周 active 时长"
                            points: root.vmLine
                        }
                        StatsHeatmap {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 7
                            Layout.fillWidth: true
                            Layout.preferredHeight: 320
                            title: "活跃热力"; sub: "本月每日强度（按当月峰值分级）"
                            cells: root.vmHeat
                        }
                        StatsRankingList {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 5
                            Layout.fillWidth: true
                            Layout.preferredHeight: 320
                            title: "高频应用"; sub: "本月使用排行"
                            rows: root.vmRanking
                        }
                        StatsInsightCard {
                            Layout.columnSpan: 12
                            Layout.fillWidth: true
                            Layout.preferredHeight: 260
                            insight: root.vmInsight
                            recs: root.vmRecs
                            keywords: root.vmKeywords
                            onExportRequested: root.doExport()
                        }
                    }

                    // ====== 年视图 ======
                    GridLayout {
                        width: parent.width
                        columns: 12
                        columnSpacing: 14
                        rowSpacing: 14
                        visible: root.range === "year" && root.hasData

                        StatsBarChart {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 8
                            Layout.fillWidth: true
                            Layout.preferredHeight: 262
                            title: "月度使用"; sub: "本年 12 个月 active 时长"
                            bars: root.vmBars; barCount: 12
                        }
                        DailyUsageShare {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 4
                            Layout.fillWidth: true
                            Layout.preferredHeight: 262
                            style: ml
                            languageMode: root.languageMode
                            glassStrength: 0.45
                            showInsight: false
                            titleKicker: "Category Share"
                            titleText: root.tr("本年主题占比")
                            share: root.vmShare
                            total: root.vmShareTotalText
                        }
                        StatsRankingList {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 6
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            title: "高频应用"; sub: "本年使用排行"
                            rows: root.vmRanking
                        }
                        StatsInsightCard {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 6
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            insight: root.vmInsight
                            recs: root.vmRecs
                            keywords: []
                            onExportRequested: root.doExport()
                        }
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
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: gbtn.tapped()
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
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: root.tr(chart.title); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: chart.sub !== ""; text: root.tr(chart.sub); color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
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
                            readonly property real avail: height - 22

                            Rectangle {
                                id: barRect
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 20
                                width: parent.width
                                radius: 6
                                height: Math.max(2, barItem.avail * (barItem.bar ? (barItem.bar.ratio ? barItem.bar.ratio : 0) : 0))
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.88) }
                                    GradientStop { position: 1; color: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.58) }
                                }
                                Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy } }
                            }
                            Text {
                                anchors.bottom: barRect.top
                                anchors.bottomMargin: 3
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: barMa.containsMouse && barItem.bar
                                text: barItem.bar ? barItem.bar.valueText : ""
                                color: ml.accentText
                                font.pixelSize: 11; font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: barItem.bar ? barItem.bar.label : ""
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

    // 折线/面积图卡（月周趋势）
    component StatsLineChart: FrostCard {
        id: lc
        property string title: ""
        property string sub: ""
        property var points: []
        style: ml
        radius: 18
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: root.tr(lc.title); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: lc.sub !== ""; text: root.tr(lc.sub); color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Canvas {
                    id: lineCanvas
                    anchors.fill: parent
                    property var pts: lc.points
                    property bool nm: root.nightMode
                    onPtsChanged: requestPaint()
                    onNmChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var n = pts ? pts.length : 0
                        var w = width, h = height, padT = 10, padB = 8
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, root.nightMode ? 0.06 : 0.10)
                        ctx.lineWidth = 1
                        for (var g = 0; g < 3; g++) {
                            var gy = padT + (h - padT - padB) * g / 2
                            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke()
                        }
                        if (n < 2) return
                        function X(i) { return (i / (n - 1)) * w }
                        function Y(v) { return padT + (1 - v) * (h - padT - padB) }
                        ctx.beginPath(); ctx.moveTo(X(0), h)
                        ctx.lineTo(X(0), Y(pts[0].y))
                        for (var i = 1; i < n; i++) ctx.lineTo(X(i), Y(pts[i].y))
                        ctx.lineTo(X(n - 1), h); ctx.closePath()
                        var grad = ctx.createLinearGradient(0, 0, 0, h)
                        grad.addColorStop(0, Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.36))
                        grad.addColorStop(1, Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0))
                        ctx.fillStyle = grad; ctx.fill()
                        ctx.beginPath(); ctx.moveTo(X(0), Y(pts[0].y))
                        for (var j = 1; j < n; j++) ctx.lineTo(X(j), Y(pts[j].y))
                        ctx.lineWidth = 3; ctx.lineJoin = "round"
                        ctx.strokeStyle = ml.aqua; ctx.stroke()
                        ctx.fillStyle = ml.aqua
                        for (var k = 0; k < n; k++) { ctx.beginPath(); ctx.arc(X(k), Y(pts[k].y), 3, 0, 2 * Math.PI); ctx.fill() }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !lc.points || lc.points.length < 2
                    text: root.tr("本月数据不足以绘制趋势")
                    color: ml.textTertiary
                    font.pixelSize: 12
                }
            }
        }
    }

    // 热力图卡（按天，7 列周对齐；色级 token 派生）
    component StatsHeatmap: FrostCard {
        id: heat
        property string title: ""
        property string sub: ""
        property var cells: []
        property var hoveredCell: null
        readonly property int weekCount: Math.max(1, Math.ceil((cells ? cells.length : 0) / 7))
        readonly property real gridGap: 7
        readonly property real labelWidth: 36
        readonly property real availableCellByWidth: (heatBody.width - labelWidth - 14 - Math.max(0, weekCount - 1) * gridGap) / weekCount
        readonly property real availableCellByHeight: (heatBody.height - 6 * gridGap) / 7
        readonly property real cellSide: Math.max(20, Math.min(38, Math.floor(Math.min(availableCellByWidth, availableCellByHeight))))
        readonly property real cellRadius: Math.max(5, Math.min(9, cellSide * 0.22))
        style: ml
        radius: 18
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: root.tr(heat.title); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: heat.sub !== ""; text: root.tr(heat.sub); color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Item {
                id: heatBody
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Row {
                    id: heatGridWrap
                    anchors.centerIn: parent
                    width: heat.labelWidth + 14 + heat.weekCount * heat.cellSide + Math.max(0, heat.weekCount - 1) * heat.gridGap
                    height: 7 * heat.cellSide + 6 * heat.gridGap
                    spacing: 12
                    Column {
                        width: heat.labelWidth
                        spacing: heat.gridGap
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: root.heatWeekLabels()
                            delegate: Text {
                                required property var modelData
                                width: heat.labelWidth
                                height: heat.cellSide
                                text: root.tr(modelData)
                                color: ml.textTertiary
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    Grid {
                        rows: 7
                        flow: Grid.TopToBottom
                        rowSpacing: heat.gridGap
                        columnSpacing: heat.gridGap
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: heat.cells
                            delegate: Rectangle {
                                id: heatCell
                                required property var modelData
                                width: heat.cellSide
                                height: heat.cellSide
                                radius: heat.cellRadius
                                opacity: modelData.empty ? 0 : 1
                                color: modelData.color ? modelData.color : root.heatColor(modelData.category, modelData.level)
                                border.width: 1
                                border.color: cellMa.containsMouse
                                    ? Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.65)
                                    : (modelData.level === 0 ? (root.nightMode ? "#2E3947" : "#D7DEE5") : Qt.rgba(1, 1, 1, root.nightMode ? 0.08 : 0.34))
                                scale: cellMa.containsMouse ? 1.08 : 1
                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !modelData.empty && heat.cellSide >= 28
                                    text: modelData.day
                                    color: modelData.level > 2 ? Qt.rgba(1, 1, 1, 0.82) : ml.textTertiary
                                    font.pixelSize: Math.min(11, heat.cellSide * 0.38)
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: cellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: heat.hoveredCell = modelData
                                    onExited: if (heat.hoveredCell === modelData) heat.hoveredCell = null
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    width: Math.min(parent.width - 16, tipText.implicitWidth + 22)
                    height: 30
                    radius: 15
                    visible: heat.hoveredCell !== null && !heat.hoveredCell.empty
                    color: ml.calToastBg
                    border.width: 1
                    border.color: ml.chipEventBd
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: heat.hoveredCell ? root.heatTooltipText(heat.hoveredCell) : ""
                        color: ml.textPrimary
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    // 高频应用排行卡
    component StatsRankingList: FrostCard {
        id: rl
        property string title: ""
        property string sub: ""
        property var rows: []
        style: ml
        radius: 18
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: root.tr(rl.title); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: rl.sub !== ""; text: root.tr(rl.sub); color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Item {
                id: rlBody
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Column {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8
                    Repeater {
                        model: rl.rows ? rl.rows.slice(0, 4) : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: rlBody.width
                            height: 50
                            radius: 14
                            color: ml.calSunkBg
                            border.width: 1; border.color: ml.cardBorder
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 34; Layout.preferredHeight: 34
                                    radius: 11
                                    color: AppVisual.modelAppColor(modelData)
                                    Image {
                                        id: statsAppIconImage
                                        anchors.centerIn: parent
                                        width: 22; height: 22
                                        source: AppVisual.modelIconSource(modelData)
                                        sourceSize.width: 64; sourceSize.height: 64
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true; smooth: true; mipmap: true
                                        visible: source != "" && status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: AppVisual.modelIconSource(modelData) === "" || statsAppIconImage.status !== Image.Ready
                                        text: AppVisual.modelIconLabel(modelData)
                                        color: nightMode ? "#FFFFFF" : "#2D2724"
                                        font.pixelSize: 14; font.weight: 900
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: AppVisual.modelDisplayNameForLanguage(modelData, root.languageMode)
                                        color: ml.textPrimary
                                        font.pixelSize: 13; font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.tr(AppVisual.modelCategory(modelData) !== "" ? AppVisual.modelCategory(modelData) : "应用") + " · " + root.sentence("openCount", {count: modelData.sessions}, modelData.sessions + " 次打开")
                                        color: ml.textTertiary
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    text: modelData.time
                                    color: ml.accentText
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }
                    Text {
                        visible: !rl.rows || rl.rows.length === 0
                        text: root.tr("当前范围还没有应用记录")
                        color: ml.textTertiary
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // 洞察 + 行动建议 + (可选)关键词
    component StatsInsightCard: FrostCard {
        id: ic
        property string insight: ""
        property var recs: []
        property var keywords: []
        signal exportRequested()
        style: ml
        radius: 18
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text { text: root.tr("洞察 & 建议"); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Rectangle {
                    width: expLabel.implicitWidth + 24; height: 32; radius: 11
                    color: expMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                    border.width: 1; border.color: ml.calGhostBorder
                    Text { id: expLabel; anchors.centerIn: parent; text: root.tr("导出报告"); color: ml.calGlyph; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea { id: expMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: ic.exportRequested() }
                }
            }
            // 洞察段落（135° aqua/violet 浅染）
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: insightText.implicitHeight + 24
                radius: 14
                color: Qt.rgba(0, 0, 0, root.nightMode ? 0.13 : 0.04)
                border.width: 1
                border.color: Qt.rgba(ml.glowCyan.r, ml.glowCyan.g, ml.glowCyan.b, 0.11)
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(ml.glowCyan.r, ml.glowCyan.g, ml.glowCyan.b, 0.09 * ml.glowStrength) }
                        GradientStop { position: 1; color: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.06 * ml.glowStrength) }
                    }
                }
                Text {
                    id: insightText
                    anchors.fill: parent
                    anchors.margins: 12
                    text: I18n.smartText(root.languageMode, ic.insight)
                    color: ml.textSecondary
                    font.pixelSize: 13
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
            // 关键词 chips（月视图）
            Flow {
                Layout.fillWidth: true
                visible: ic.keywords && ic.keywords.length > 0
                spacing: 6
                Repeater {
                    model: ic.keywords
                    delegate: Rectangle {
                        required property var modelData
                        height: 26
                        width: kwT.implicitWidth + 20
                        radius: 9
                        color: ml.accentSoft
                        border.width: 1; border.color: ml.accentSoftBorder
                        Text { id: kwT; anchors.centerIn: parent; text: I18n.smartText(root.languageMode, modelData); color: ml.accentText; font.pixelSize: 11; font.weight: Font.DemiBold }
                    }
                }
            }
            // 行动建议（编号）
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                Repeater {
                    model: ic.recs
                    delegate: RowLayout {
                        id: recRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                            radius: 8
                            color: ml.accentSoft
                            border.width: 1; border.color: ml.accentSoftBorder
                            Text { anchors.centerIn: parent; text: (recRow.index + 1); color: ml.aqua; font.pixelSize: 12; font.weight: Font.DemiBold }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: I18n.smartText(root.languageMode, modelData)
                            color: ml.textSecondary
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.tr("以上为本地确定性模板生成（aiGenerated:false），非 AI、不读原始日志。")
                color: ml.textTertiary
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }
}
