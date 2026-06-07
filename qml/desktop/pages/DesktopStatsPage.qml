import QtQuick
import QtQuick.Layouts
import "../memorylake"
import "../components/AppVisual.js" as AppVisual

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
    property int refreshTick: 0           // bump 触发派生绑定重算

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

    readonly property bool hasData: vmTotalSec > 0 || (vmApps && vmApps.length > 0)
    readonly property bool sideCollapsed: root.width < 1200   // ≤1200 左栏折叠（C10）

    onRangeChanged: rebuild()

    // ============================================================
    // 工具：时间格式 / 范围文案
    // ============================================================
    function curYear() { return new Date().getFullYear() }
    function curMonth() { return new Date().getMonth() + 1 }

    function rangeWord(r) { return r === "week" ? "周" : r === "month" ? "月" : "年" }
    function rangeLabel(r) { return r === "week" ? "本周" : r === "month" ? "本月" : "本年" }
    function rangeEnLabel(r) { return r === "week" ? "Week" : r === "month" ? "Month" : "Year" }

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

    // 当周窗口（周一为首，含两端）——与 C++ matchesRange("week") 同口径。
    function weekBounds() {
        var now = new Date()
        var dow = (now.getDay() + 6) % 7   // 0=周一 … 6=周日
        var monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dow, 0, 0, 0, 0)
        var start = Math.floor(monday.getTime() / 1000)
        return { start: start, end: start + 7 * 86400 - 1, dow: dow }
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

    // 周 7 柱（G-1：dailySecondsForRange 真实逐日 active 秒数，周一→周日）。
    function computeWeekBars() {
        if (!usageStatManager || !usageStatManager.dailySecondsForRange) return []
        var wb = weekBounds()
        var series = usageStatManager.dailySecondsForRange(wb.start, wb.end)
        var labels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
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

    // 年 12 柱（G-7 临时 QML：循环 activeSoftwareForMonth；未来的月不查询、留 0）。
    function computeYearBars() {
        if (!usageStatManager) return []
        var now = new Date()
        var y = now.getFullYear()
        var labels = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
        var secs = [], maxSec = 1
        for (var m = 1; m <= 12; m++) {
            var sec = 0
            if (m <= now.getMonth() + 1) {
                var apps = usageStatManager.activeSoftwareForMonth(y, m)
                for (var i = 0; i < apps.length; i++) sec += apps[i].seconds ? apps[i].seconds : 0
            }
            secs.push(sec)
            if (sec > maxSec) maxSec = sec
        }
        var bars = []
        for (var mm = 0; mm < 12; mm++)
            bars.push({ label: labels[mm], ratio: secs[mm] / maxSec, valueText: secondsToDisplay(secs[mm]), seconds: secs[mm] })
        return bars
    }

    // 月热力（A-2：按当月最大单日秒数分 5 级 0/≤25/≤50/≤75/>75）。
    function computeHeat(daily) {
        var maxSec = 0
        for (var i = 0; i < daily.length; i++)
            if ((daily[i].seconds ? daily[i].seconds : 0) > maxSec) maxSec = daily[i].seconds
        var cells = []
        for (var j = 0; j < daily.length; j++) {
            var sec = daily[j].seconds ? daily[j].seconds : 0
            var lv = 0
            if (maxSec > 0 && sec > 0) {
                var r = sec / maxSec
                lv = r > 0.75 ? 4 : r > 0.50 ? 3 : r > 0.25 ? 2 : 1
            }
            cells.push({ level: lv, day: daily[j].day, seconds: sec })
        }
        return cells
    }

    // 月周趋势（按周一为首的周分桶求每周总秒，归一化为折线点）。
    function computeWeekTrend(daily) {
        var now = new Date()
        var y = now.getFullYear(), mo = now.getMonth()
        var buckets = {}, order = []
        for (var i = 0; i < daily.length; i++) {
            var dt = new Date(y, mo, daily[i].day)
            var dow = (dt.getDay() + 6) % 7
            var monday = new Date(y, mo, daily[i].day - dow)
            var key = monday.getTime()
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

    function monthActiveDays(daily) {
        var c = 0
        for (var i = 0; i < daily.length; i++) if ((daily[i].seconds ? daily[i].seconds : 0) > 0) c++
        return c
    }

    // 环比上月（真实：本月总秒 vs 上月聚合总秒）。无上月数据→honest 不显示箭头。
    function computeMoM() {
        if (!usageStatManager) return { thisSec: 0, lastSec: 0, hasLast: false }
        var y = curYear(), m = curMonth()
        var py = m === 1 ? y - 1 : y, pm = m === 1 ? 12 : m - 1
        var lastApps = usageStatManager.activeSoftwareForMonth(py, pm)
        var lastSec = 0
        for (var i = 0; i < lastApps.length; i++) lastSec += lastApps[i].seconds ? lastApps[i].seconds : 0
        return { thisSec: usageStatManager.activeSoftwareSecondsForRange("month"),
                 lastSec: lastSec, hasLast: lastApps.length > 0 && lastSec > 0 }
    }

    // 月关键词（memoryLakeRecap 真实 keywords slide；数据由本页传入，维持 db_smoke 契约）。
    function monthKeywords(monthApps, monthSegs) {
        if (typeof dailyCardService === "undefined" || !dailyCardService) return []
        var y = curYear(), m = curMonth()
        var py = m === 1 ? y - 1 : y, pm = m === 1 ? 12 : m - 1
        var lastApps = usageStatManager.activeSoftwareForMonth(py, pm)
        var dailySeries = usageStatManager.dailySecondsForMonth(y, m)
        var recap = dailyCardService.memoryLakeRecap(monthApps, monthSegs, lastApps, dailySeries)
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
            out.push({ name: a.name ? a.name : (a.appName ? a.appName : "未知应用"),
                       groupKey: key, path: a.path ? a.path : "",
                       category: a.category ? a.category : "",
                       seconds: a.seconds ? a.seconds : 0,
                       time: a.time ? a.time : secondsToDisplay(a.seconds ? a.seconds : 0),
                       sessions: byKey[key] !== undefined ? byKey[key] : 0 })
        }
        return out
    }

    // ====== 指标卡模型（每范围 4 张；缺真实环比→change:"" 不显示假箭头 C6）======
    function weekMetrics(total, segs) {
        var wb = weekBounds()
        var elapsed = Math.max(1, wb.dow + 1)
        var lu = longestUse(segs)
        var sw = computeSwitchCount(segs)
        return [
            { title: "本周总使用", sub: "本周累计", badge: "周", value: hoursText(total), change: "", changeDown: false },
            { title: "日均使用", sub: "按已过天数", badge: "周", value: hoursText(total / elapsed), change: "", changeDown: false },
            { title: "最长连续使用", sub: lu ? (lu.appName ? lu.appName : "—") : "—", badge: "周",
              value: lu ? hoursText(lu.longestSec) : "—", change: "", changeDown: false },
            { title: "切换次数", sub: "前台应用切换", badge: "周", value: total > 0 ? (sw + " 次") : "—", change: "", changeDown: false }
        ]
    }

    function monthMetrics(total, apps, cat, daily) {
        var mom = computeMoM()
        var change = "", down = false
        if (mom.hasLast) {
            var d = mom.thisSec - mom.lastSec
            change = (d >= 0 ? "+" : "") + (Math.round((d / 3600) * 10) / 10).toFixed(1) + "h"
            down = d < 0
        }
        var ent = total > 0 ? Math.round(100 * ((cat["游戏"] ? cat["游戏"] : 0) + (cat["视频"] ? cat["视频"] : 0)) / total) : 0
        var crt = total > 0 ? Math.round(100 * ((cat["创作"] ? cat["创作"] : 0) + (cat["笔记"] ? cat["笔记"] : 0)) / total) : 0
        return [
            { title: "本月总使用", sub: "较上月", badge: "月", value: hoursText(total), change: change, changeDown: down },
            { title: "活跃天数", sub: "有记录的天", badge: "月", value: monthActiveDays(daily) + " 天", change: "", changeDown: false },
            { title: "娱乐占比", sub: "游戏 + 视频", badge: "月", value: total > 0 ? (ent + "%") : "—", change: "", changeDown: false },
            { title: "创作占比", sub: "创作 + 笔记", badge: "月", value: total > 0 ? (crt + "%") : "—", change: "", changeDown: false }
        ]
    }

    function yearMetrics(total, apps, bars) {
        var peakIdx = -1, peak = 0
        for (var i = 0; i < bars.length; i++)
            if ((bars[i].seconds ? bars[i].seconds : 0) > peak) { peak = bars[i].seconds; peakIdx = i }
        return [
            { title: "年度总使用", sub: "本年累计", badge: "年", value: hoursText(total), change: "", changeDown: false },
            { title: "最活跃月份", sub: "按月度时长", badge: "年", value: (peakIdx >= 0 && peak > 0) ? bars[peakIdx].label : "—", change: "", changeDown: false },
            { title: "年度专注", sub: "待支持 · 阶段三", badge: "年", value: "—", change: "", changeDown: false },
            { title: "打开应用", sub: "本年使用过", badge: "年", value: apps.length > 0 ? (apps.length + " 个") : "—", change: "", changeDown: false }
        ]
    }

    // ====== 本地确定性洞察/建议模板（aiGenerated:false；不接真 AI、不喂原始日志 C7）======
    function buildInsight(r, share, total, cat) {
        var label = rangeLabel(r)
        if (total <= 0) return label + "记录较少，暂不下结论。"
        var s = label + "你主要把时间花在"
        s += (share.length > 0) ? ("「" + share[0].name + "」（" + share[0].percent + "%）") : "多个应用上"
        s += "，共计 " + hoursText(total) + "。"
        var ent = (cat["游戏"] ? cat["游戏"] : 0) + (cat["视频"] ? cat["视频"] : 0)
        if (total > 0 && ent / total > 0.4) s += " 其中娱乐时间占比偏高。"
        return s
    }

    function buildRecs(r, share, total, cat) {
        var recs = []
        if (total <= 0) { recs.push("本" + rangeWord(r) + "暂无足够数据生成建议。"); return recs }
        var topCat = topCategory(cat)
        var sug = "继续保持当前节奏。"
        if (topCat === "游戏") sug = "进入娱乐时段前，先完成一项关键任务。"
        else if (topCat === "开发" || topCat === "创作" || topCat === "办公") sug = "保持专注节奏，建议每 50 分钟起身休息。"
        else if (topCat === "笔记" || topCat === "浏览") sug = "把零散浏览沉淀成笔记，形成输出。"
        else if (topCat === "视频" || topCat === "音乐") sug = "放松之余，预留固定的深度工作时段。"
        else if (topCat === "社交") sug = "留意社交占用，集中处理消息更高效。"
        recs.push(sug)
        var ent = (cat["游戏"] ? cat["游戏"] : 0) + (cat["视频"] ? cat["视频"] : 0)
        if (ent / total > 0.4) recs.push("娱乐占比约 " + Math.round(100 * ent / total) + "%，可考虑设定每日上限。")
        else recs.push("时间结构较均衡，继续保持。")
        return recs
    }

    // ============================================================
    // 重算 + 数据刷新管线（保留契约：Connections + 5s Timer + refresh）
    // ============================================================
    function rebuild() {
        if (!usageStatManager) return
        var r = range
        var apps = usageStatManager.activeSoftwareForRange(r)
        var segs = usageStatManager.foregroundSegmentsForRange(r)
        if (!apps) apps = []
        if (!segs) segs = []
        var total = usageStatManager.activeSoftwareSecondsForRange(r)
        vmApps = apps; vmSegments = segs; vmTotalSec = total

        var share = []
        if (typeof dailyCardService !== "undefined" && dailyCardService) {
            var day = dailyCardService.memoryLakeDay(apps, segs)
            share = (day && day.usageShare) ? day.usageShare : []
        }
        vmShare = share
        vmShareTotalText = hoursText(total)

        var cat = categorySums(apps)
        vmRanking = buildRanking(apps, segs, 6)

        if (r === "week") {
            vmBars = computeWeekBars()
            vmHeat = []; vmLine = []; vmKeywords = []
            vmMetrics = weekMetrics(total, segs)
        } else if (r === "year") {
            vmBars = computeYearBars()
            vmHeat = []; vmLine = []; vmKeywords = []
            vmMetrics = yearMetrics(total, apps, vmBars)
        } else {
            var daily = usageStatManager.dailySecondsForMonth(curYear(), curMonth())
            if (!daily) daily = []
            vmBars = []
            vmHeat = computeHeat(daily)
            vmLine = computeWeekTrend(daily)
            vmKeywords = monthKeywords(apps, segs)
            vmMetrics = monthMetrics(total, apps, cat, daily)
        }

        vmInsight = buildInsight(r, share, total, cat)
        vmRecs = buildRecs(r, share, total, cat)
        refreshTick++
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
        if (usageStatManager) usageStatManager.refresh()
        rebuild()
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
    function showToast(msg) { statsToast.message = msg; statsToast.shown = true; toastTimer.restart() }

    // ============================================================
    // 范围 Tab 数据
    // ============================================================
    readonly property var rangeModel: [
        { key: "week", label: "周", glyph: "周", en: "Week" },
        { key: "month", label: "月", glyph: "月", en: "Month" },
        { key: "year", label: "年", glyph: "年", en: "Year" }
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
                            text: "时间统计"
                            color: ml.textPrimary
                            font.pixelSize: 22
                            font.weight: 800
                            font.letterSpacing: -0.4
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "软件使用 · 主题 · 趋势"
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
                                        text: modelData.glyph
                                        color: root.range === modelData.key ? ml.aqua : ml.calGlyph
                                        font.pixelSize: 14; font.weight: Font.DemiBold
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        text: modelData.label + "视图"
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
                                onClicked: { root.range = modelData.key; root.showToast("已切换到" + modelData.label + "视图") }
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
                            text: "本" + root.rangeWord(root.range) + "洞察"
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
                            text: "本地生成 · 非 AI"
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
                            text: root.rangeLabel(root.range) + "统计"
                            color: ml.textPrimary
                            font.pixelSize: 22
                            font.weight: 800
                            font.letterSpacing: -0.4
                        }
                        Text {
                            text: root.hasData ? ("共 " + root.hoursText(root.vmTotalSec) + " · " + root.vmApps.length + " 个应用")
                                               : "暂无使用记录"
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
                                    text: modelData.label
                                    color: root.range === modelData.key ? ml.aqua : ml.calGlyph
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.range = modelData.key; root.showToast("已切换到" + modelData.label + "视图") }
                                }
                            }
                        }
                    }

                    // 期次切换（诚实占位：阶段三实装任意窗口；当前点了提示，不改数据）
                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        StatsGhostButton { glyph: "‹"; tip: true; onTapped: root.showToast("期次切换将在阶段三支持") }
                        Rectangle {
                            width: 64; height: 38; radius: 13
                            color: ml.calGhostBg
                            border.width: 1; border.color: ml.calGhostBorder
                            Text { anchors.centerIn: parent; text: "本期"; color: ml.calGlyph; font.pixelSize: 13; font.weight: Font.DemiBold }
                        }
                        StatsGhostButton { glyph: "›"; tip: true; onTapped: root.showToast("期次切换将在阶段三支持") }
                    }

                    // 导出（诚实占位）
                    StatsGhostButton { Layout.alignment: Qt.AlignVCenter; label: "导出"; onTapped: root.showToast("导出将在阶段三支持") }
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
                                            Text { text: modelData.title; color: ml.textSecondary; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: modelData.sub; color: ml.textTertiary; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                        }
                                        Rectangle {
                                            visible: modelData.badge !== ""
                                            radius: 13; color: ml.accentSoft
                                            border.width: 1; border.color: ml.accentSoftBorder
                                            implicitWidth: badgeT.implicitWidth + 16; implicitHeight: 24
                                            Text { id: badgeT; anchors.centerIn: parent; text: modelData.badge; color: ml.aqua; font.pixelSize: 11; font.weight: Font.DemiBold }
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
                                        text: modelData.change + " 较上月"
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
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.rangeLabel(root.range) + "还没有使用记录"; color: ml.textSecondary; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "后台服务采集到数据后，这里会自动出现统计"; color: ml.textTertiary; font.pixelSize: 13 }
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
                            glassStrength: 0.45
                            showInsight: false
                            titleKicker: "Category Share"
                            titleText: "本周主题占比"
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
                            onExportRequested: root.showToast("导出将在阶段三支持")
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
                            glassStrength: 0.45
                            showInsight: false
                            titleKicker: "Category Share"
                            titleText: "本月主题占比"
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
                            Layout.preferredHeight: 262
                            title: "活跃热力"; sub: "本月每日强度（按当月峰值分级）"
                            cells: root.vmHeat
                        }
                        StatsRankingList {
                            Layout.columnSpan: root.sideCollapsed ? 12 : 5
                            Layout.fillWidth: true
                            Layout.preferredHeight: 262
                            title: "高频应用"; sub: "本月使用排行"
                            rows: root.vmRanking
                        }
                        StatsInsightCard {
                            Layout.columnSpan: 12
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            insight: root.vmInsight
                            recs: root.vmRecs
                            keywords: root.vmKeywords
                            onExportRequested: root.showToast("导出将在阶段三支持")
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
                            glassStrength: 0.45
                            showInsight: false
                            titleKicker: "Category Share"
                            titleText: "本年主题占比"
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
                            onExportRequested: root.showToast("导出将在阶段三支持")
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
        signal tapped()
        implicitWidth: glyph !== "" ? 38 : (gbtnLabel.implicitWidth + 28)
        height: 38
        radius: 13
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
            text: gbtn.glyph !== "" ? gbtn.glyph : gbtn.label
            color: gbtn.primary ? ml.calBtnInk : ml.calGlyph
            font.pixelSize: gbtn.glyph !== "" ? 17 : 13
            font.weight: Font.DemiBold
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
                Text { text: chart.title; color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: chart.sub !== ""; text: chart.sub; color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
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
                            readonly property var bar: (chart.bars && index < chart.bars.length) ? chart.bars[index] : null
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
                Text { text: lc.title; color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: lc.sub !== ""; text: lc.sub; color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
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
                    text: "本月数据不足以绘制趋势"
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
        readonly property var levelColors: [
            ml.trackBg,
            Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.18),
            Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.32),
            Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.42),
            Qt.rgba(ml.shareGold.r, ml.shareGold.g, ml.shareGold.b, 0.50)
        ]
        style: ml
        radius: 18
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: heat.title; color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: heat.sub !== ""; text: heat.sub; color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Item {
                id: heatBody
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Grid {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    columns: 7
                    rowSpacing: 6
                    columnSpacing: 6
                    Repeater {
                        model: heat.cells
                        delegate: Rectangle {
                            required property var modelData
                            width: (heatBody.width - 6 * 6) / 7
                            height: width
                            radius: 7
                            color: heat.levelColors[modelData.level]
                            border.width: modelData.level === 0 ? 1 : 0
                            border.color: ml.cardBorder
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.level >= 3 ? ml.calBtnInk : ml.textTertiary
                                font.pixelSize: 10
                                font.weight: modelData.level >= 3 ? Font.DemiBold : Font.Normal
                            }
                        }
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
                Text { text: rl.title; color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { visible: rl.sub !== ""; text: rl.sub; color: ml.textTertiary; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
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
                        model: rl.rows
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
                                    color: AppVisual.appColor(modelData.groupKey, modelData.name, modelData.path)
                                    Image {
                                        anchors.centerIn: parent
                                        width: 22; height: 22
                                        source: AppVisual.appIconSource(modelData.groupKey, modelData.path)
                                        sourceSize.width: 64; sourceSize.height: 64
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true; smooth: true; mipmap: true
                                        visible: source != ""
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: AppVisual.appIconSource(modelData.groupKey, modelData.path) === ""
                                        text: AppVisual.appIconLabel(modelData.groupKey, modelData.name)
                                        color: nightMode ? "#FFFFFF" : "#2D2724"
                                        font.pixelSize: 14; font.weight: 900
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: ml.textPrimary
                                        font.pixelSize: 13; font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.category !== "" ? modelData.category : "应用") + " · " + modelData.sessions + " 次打开"
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
                        text: "当前范围还没有应用记录"
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
                Text { text: "洞察 & 建议"; color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Rectangle {
                    width: expLabel.implicitWidth + 24; height: 32; radius: 11
                    color: expMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                    border.width: 1; border.color: ml.calGhostBorder
                    Text { id: expLabel; anchors.centerIn: parent; text: "导出报告"; color: ml.calGlyph; font.pixelSize: 12; font.weight: Font.DemiBold }
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
                    text: ic.insight
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
                        Text { id: kwT; anchors.centerIn: parent; text: modelData; color: ml.accentText; font.pixelSize: 11; font.weight: Font.DemiBold }
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
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                            radius: 8
                            color: ml.accentSoft
                            border.width: 1; border.color: ml.accentSoftBorder
                            Text { anchors.centerIn: parent; text: (index + 1); color: ml.aqua; font.pixelSize: 12; font.weight: Font.DemiBold }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: ml.textSecondary
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "以上为本地确定性模板生成（aiGenerated:false），非 AI、不读原始日志。"
                color: ml.textTertiary
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }
}
