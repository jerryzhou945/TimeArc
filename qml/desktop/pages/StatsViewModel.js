// Pure statistics view-model helpers shared by QML and Node regression tests.

function safeSeconds(value) {
    var number = Number(value)
    return isFinite(number) && number > 0 ? Math.floor(number) : 0
}

function clockLaneRadiusScale(lane) {
    var normalized = Math.max(0, Math.min(2, Math.floor(Number(lane) || 0)))
    return Math.round((0.54 + normalized * 0.09) * 100) / 100
}

function rowKey(row) {
    if (!row) return ""
    return row.groupKey || row.appId || row.path || row.appName || row.name || ""
}

function displayName(row) {
    if (!row) return "未知应用"
    return row.customDisplayName || row.adapterDisplayName || row.displayName || row.name || row.appName || "未知应用"
}

function formatCompactDuration(seconds) {
    var total = safeSeconds(seconds)
    if (total === 0) return "0m"
    if (total < 60) return "<1m"
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    if (hours > 0) return hours + "h" + (minutes > 0 ? (" " + minutes + "m") : "")
    return minutes + "m"
}

function mergeRow(base, periodSeconds, lifetimeSeconds, percent) {
    var row = {}
    for (var key in base) row[key] = base[key]
    row.groupKey = rowKey(base)
    row.displayName = displayName(base)
    row.name = row.displayName
    row.periodSeconds = safeSeconds(periodSeconds)
    row.lifetimeSeconds = safeSeconds(lifetimeSeconds)
    row.percent = percent
    row.periodTime = formatCompactDuration(row.periodSeconds)
    row.lifetimeTime = formatCompactDuration(row.lifetimeSeconds)
    return row
}

function buildAppLibrary(periodApps, lifetimeApps, options) {
    var period = periodApps || []
    var lifetime = lifetimeApps || []
    var opts = options || {}
    var periodByKey = {}
    var totalPeriod = 0
    var i
    for (i = 0; i < period.length; i++) {
        var periodKey = rowKey(period[i])
        if (!periodKey) continue
        periodByKey[periodKey] = period[i]
        totalPeriod += safeSeconds(period[i].seconds)
    }

    var rows = []
    var seen = {}
    for (i = 0; i < lifetime.length; i++) {
        var life = lifetime[i]
        var lifeKey = rowKey(life)
        if (!lifeKey || life.hidden) continue
        var current = periodByKey[lifeKey]
        var currentSeconds = current ? safeSeconds(current.seconds) : 0
        var source = current || life
        var merged = mergeRow(source, currentSeconds, life.seconds,
                              totalPeriod > 0 ? Math.round(currentSeconds * 100 / totalPeriod) : 0)
        var customDisplayName = (current && current.customDisplayName) || life.customDisplayName || ""
        if (customDisplayName) {
            merged.customDisplayName = customDisplayName
            merged.displayName = customDisplayName
            merged.name = customDisplayName
        }
        merged.lastUsedUnixSec = safeSeconds(life.lastUsedUnixSec || source.lastUsedUnixSec)
        rows.push(merged)
        seen[lifeKey] = true
    }
    for (i = 0; i < period.length; i++) {
        var currentOnly = period[i]
        var currentKey = rowKey(currentOnly)
        if (!currentKey || seen[currentKey]) continue
        var seconds = safeSeconds(currentOnly.seconds)
        var currentMerged = mergeRow(currentOnly, seconds, seconds,
                                     totalPeriod > 0 ? Math.round(seconds * 100 / totalPeriod) : 0)
        currentMerged.lastUsedUnixSec = safeSeconds(currentOnly.lastUsedUnixSec)
        rows.push(currentMerged)
    }

    var query = String(opts.query || "").toLowerCase().trim()
    var showInactive = opts.showInactive !== false
    rows = rows.filter(function (row) {
        if (!showInactive && row.periodSeconds === 0) return false
        if (!query) return true
        var haystack = (row.displayName + " " + (row.category || "") + " " + row.groupKey).toLowerCase()
        return haystack.indexOf(query) >= 0
    })

    var sort = opts.sort || "period"
    rows.sort(function (a, b) {
        if (sort === "lifetime" && b.lifetimeSeconds !== a.lifetimeSeconds)
            return b.lifetimeSeconds - a.lifetimeSeconds
        if (sort === "period" && b.periodSeconds !== a.periodSeconds)
            return b.periodSeconds - a.periodSeconds
        var nameOrder = a.displayName.localeCompare(b.displayName)
        if (nameOrder !== 0) return nameOrder
        return a.groupKey.localeCompare(b.groupKey)
    })
    return rows
}

function buildCategoryDistribution(apps, limit) {
    var source = apps || []
    var maximum = Math.max(1, Number(limit) || 6)
    var grouped = {}
    var total = 0
    for (var i = 0; i < source.length; i++) {
        var seconds = safeSeconds(source[i].seconds)
        if (seconds <= 0) continue
        var category = source[i].category || "其他"
        if (!grouped[category]) grouped[category] = { name: category, seconds: 0, apps: [] }
        grouped[category].seconds += seconds
        total += seconds
        var name = displayName(source[i])
        if (name && grouped[category].apps.indexOf(name) < 0 && grouped[category].apps.length < 3)
            grouped[category].apps.push(name)
    }

    var rows = []
    for (var key in grouped) rows.push(grouped[key])
    rows.sort(function (a, b) {
        if (b.seconds !== a.seconds) return b.seconds - a.seconds
        return a.name.localeCompare(b.name)
    })
    rows = rows.slice(0, maximum)
    return rows.map(function (row) {
        return {
            name: row.name,
            seconds: row.seconds,
            time: formatCompactDuration(row.seconds),
            percent: total > 0 ? Math.round(row.seconds * 100 / total) : 0,
            appsText: row.apps.join("、")
        }
    })
}

function normalizeTrendRows(range, rows) {
    var source = rows || []
    var maxSeconds = 1
    var i
    for (i = 0; i < source.length; i++)
        maxSeconds = Math.max(maxSeconds, safeSeconds(source[i].seconds))

    var weekLabels = ["一", "二", "三", "四", "五", "六", "日"]
    var output = []
    for (i = 0; i < source.length; i++) {
        var seconds = safeSeconds(source[i].seconds)
        var label = source[i].label || ""
        if (!label) {
            if (range === "month") label = "第" + (i + 1) + "周"
            else if (range === "year") label = (i + 1) + "月"
            else label = weekLabels[i] || String(i + 1)
        }
        output.push({
            label: label,
            seconds: seconds,
            ratio: seconds / maxSeconds,
            valueText: formatCompactDuration(seconds)
        })
    }
    return output
}

function buildAggregateFact(range, categories, trendRows) {
    var categoryRows = categories || []
    var bars = trendRows || []
    if (categoryRows.length === 0 || safeSeconds(categoryRows[0].seconds) === 0)
        return ""
    var peak = null
    for (var i = 0; i < bars.length; i++) {
        if (!peak || safeSeconds(bars[i].seconds) > safeSeconds(peak.seconds)) peak = bars[i]
    }
    if (!peak || safeSeconds(peak.seconds) === 0) return ""
    var period = range === "month" ? "本月" : (range === "year" ? "本年" : "本周")
    return categoryRows[0].name + "是" + period + "记录时长最长的分类，" + peak.label + "的记录最集中。"
}

function buildClockSegments(segmentGroups, periodApps, dayStartUnix, half) {
    var groups = segmentGroups || []
    var apps = periodApps || []
    var appByKey = {}
    for (var i = 0; i < apps.length; i++) appByKey[rowKey(apps[i])] = apps[i]
    var halfOffset = half === "pm" ? 12 * 3600 : 0
    var halfStart = Number(dayStartUnix) + halfOffset
    var halfEnd = halfStart + 12 * 3600
    var out = []
    for (var g = 0; g < groups.length; g++) {
        var group = groups[g]
        var key = rowKey(group)
        var app = appByKey[key] || group
        var segments = group.segments || []
        for (var s = 0; s < segments.length; s++) {
            var start = Math.max(Number(segments[s].startUnixSec), halfStart)
            var end = Math.min(Number(segments[s].endUnixSec), halfEnd)
            if (!isFinite(start) || !isFinite(end) || end <= start) continue
            var row = {}
            for (var appKey in app) row[appKey] = app[appKey]
            row.groupKey = key
            row.appId = row.appId || group.appId || ""
            row.appName = row.appName || group.appName || displayName(app)
            row.path = row.path || group.path || ""
            row.startUnixSec = start
            row.endUnixSec = end
            row.seconds = Math.floor(end - start)
            row.startAngle = (start - halfStart) * 360 / (12 * 3600)
            row.endAngle = (end - halfStart) * 360 / (12 * 3600)
            row.segmentId = key + ":" + start + ":" + end
            out.push(row)
        }
    }
    out.sort(function (a, b) { return a.startUnixSec - b.startUnixSec })

    // Foreground and media observations may overlap. Give concurrent records
    // one of three concentric clock lanes instead of painting them on top of
    // each other; when all lanes are occupied, reuse the lane that clears first.
    var laneEnds = [-Infinity, -Infinity, -Infinity]
    for (var rowIndex = 0; rowIndex < out.length; rowIndex++) {
        var row = out[rowIndex]
        var lane = -1
        for (var candidateLane = 0; candidateLane < laneEnds.length; candidateLane++) {
            if (row.startUnixSec >= laneEnds[candidateLane]) {
                lane = candidateLane
                break
            }
        }
        if (lane < 0) {
            lane = 0
            for (var occupiedLane = 1; occupiedLane < laneEnds.length; occupiedLane++)
                if (laneEnds[occupiedLane] < laneEnds[lane]) lane = occupiedLane
        }
        row.lane = lane
        laneEnds[lane] = Math.max(laneEnds[lane], row.endUnixSec)
        row.showIcon = false
    }

    // The arc remains visible for every measured segment. Icons are progressive
    // disclosure: reserve them for arcs with enough angular room and keep their
    // centers separated so a busy day still reads as a clock, not an icon pile.
    var iconCandidates = out.slice().sort(function (a, b) {
        if (b.seconds !== a.seconds) return b.seconds - a.seconds
        return a.startUnixSec - b.startUnixSec
    })
    var iconAngles = []
    for (var iconIndex = 0; iconIndex < iconCandidates.length && iconAngles.length < 8; iconIndex++) {
        var iconRow = iconCandidates[iconIndex]
        var span = iconRow.endAngle - iconRow.startAngle
        if (span < 8) continue
        var midpoint = (iconRow.startAngle + iconRow.endAngle) / 2
        var clear = true
        for (var angleIndex = 0; angleIndex < iconAngles.length; angleIndex++) {
            var delta = Math.abs(midpoint - iconAngles[angleIndex])
            if (Math.min(delta, 360 - delta) < 20) { clear = false; break }
        }
        if (!clear) continue
        iconRow.showIcon = true
        iconAngles.push(midpoint)
    }
    return out
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        clockLaneRadiusScale: clockLaneRadiusScale,
        buildAppLibrary: buildAppLibrary,
        buildCategoryDistribution: buildCategoryDistribution,
        normalizeTrendRows: normalizeTrendRows,
        buildAggregateFact: buildAggregateFact,
        buildClockSegments: buildClockSegments,
        formatCompactDuration: formatCompactDuration
    }
}
