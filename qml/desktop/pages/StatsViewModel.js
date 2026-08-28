.pragma library
// Pure statistics view-model helpers shared by QML and Node regression tests.

function safeSeconds(value) {
    var number = Number(value)
    return isFinite(number) && number > 0 ? Math.floor(number) : 0
}

function rowKey(row) {
    if (!row) return ""
    return row.groupKey || row.appId || row.path || row.appName || row.name || ""
}

function displayName(row) {
    if (!row) return "Unknown app"
    return row.customDisplayName || row.adapterDisplayName || row.displayName || row.name || row.appName || "Unknown app"
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
        var category = source[i].category || "Other"
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
            // The app list is handed over unjoined: "、" is the CJK enumeration
            // comma and English wants ", ". I18n.appsText() joins per language.
            apps: row.apps
        }
    })
}

function normalizeTrendRows(range, rows) {
    var source = rows || []
    var maxSeconds = 1
    var i
    for (i = 0; i < source.length; i++)
        maxSeconds = Math.max(maxSeconds, safeSeconds(source[i].seconds))

    var output = []
    for (i = 0; i < source.length; i++) {
        var seconds = safeSeconds(source[i].seconds)
        var label = source[i].label || ""
        // This module stays free of I18n so the Node regression tests can run
        // it, so a generated label travels as a key plus its index and the page
        // renders it. A row that arrived with its own label keeps it.
        var labelKey = ""
        var labelIndex = i
        if (!label) {
            if (range === "month") labelKey = "weekOfMonth"
            else if (range === "year") labelKey = "monthOfYear"
            else labelKey = "weekdayNarrow"
        }
        output.push({
            label: label,
            labelKey: labelKey,
            labelIndex: labelIndex,
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
        return null
    var peak = null
    for (var i = 0; i < bars.length; i++) {
        if (!peak || safeSeconds(bars[i].seconds) > safeSeconds(peak.seconds)) peak = bars[i]
    }
    if (!peak || safeSeconds(peak.seconds) === 0) return null
    // Returns the template name and its fields, not a sentence: the clause
    // order differs by language and this module cannot translate.
    return {
        key: "aggregateFact",
        params: {
            category: categoryRows[0].name,
            range: range === "month" ? "This Month"
                 : (range === "year" ? "This Year" : "This Week"),
            peakLabel: peak.label,
            peakLabelKey: peak.labelKey || "",
            peakLabelIndex: peak.labelIndex === undefined ? -1 : peak.labelIndex
        }
    }
}

// ============================================================================
// Category ring (Stats › Day)
// ============================================================================
// One arc per category run on a single 12-hour ring, replacing the three-lane
// per-app dial. See docs/stats-day-category-ring-redesign.md.
//
// The lanes existed because foregroundSegmentsImpl merges each app's records
// across gaps <= 60s, which lets one segment stretch over a brief excursion to
// another app — so two groups can genuinely claim the same instant. One ring is
// a single-valued function of time, so that overlap is resolved here (§3.1)
// rather than hidden behind a radius.
//
// Ring geometry is denoised; the reported totals are not. The page keeps
// showing unfiltered vmTotalSec / category sums, so the ring can never
// contradict the usage-share donut beside it.

var RING_MIN_SECONDS = 60      // "too short" — matches the backend's kMergeGapSec
var RING_BRIDGE_SECONDS = 60   // sub-threshold hole a same-category run may span
var RING_MIN_SWEEP_DEG = 5.0   // 10-minute display floor on a 12-hour dial
// Legibility floor. Removing sub-minute records is not enough on real data: a
// day of alt-tabbing produces stretches of 90-200s that clear the noise floor
// and still render as 1-degree hairlines, so the ring comes out a barcode
// (measured on a real day: 47 arcs, 35 of them under 2deg). A block thinner
// than this cannot be read or clicked, so it merges into the block it
// interrupts. On the 12-hour dial 1deg = 2 minutes, so 5deg = 10 minutes.
// Only the ring geometry is simplified; every reported duration stays exact.
var RING_MIN_ARC_DEG = 5.0
var RING_HALF_SECONDS = 12 * 3600
var RING_MAX_APPS = 4          // apps carried per arc for the hover readout

// Same precedence as AppVisual.modelCategory(), reimplemented because this
// module is a standalone .pragma library and cannot import that one. Empty
// stays empty here; buildCategoryRing folds it to "other" once.
function ringRawCategory(row) {
    if (!row) return ""
    var value = row.adapterCategory || row.category || ""
    return String(value).trim()
}

// Flatten every group's segments into rows over the whole day. Deliberately
// NOT clipped to the AM/PM half: clipping first would truncate a block that
// straddles noon and let the threshold drop a sliver of what was a long block.
function ringFlatten(segmentGroups, periodApps) {
    var groups = segmentGroups || []
    var apps = periodApps || []
    var appByKey = {}
    var i
    for (i = 0; i < apps.length; i++) appByKey[rowKey(apps[i])] = apps[i]

    var out = []
    for (var g = 0; g < groups.length; g++) {
        var group = groups[g]
        var key = rowKey(group)
        var app = appByKey[key] || group
        var category = ringRawCategory(app) || ringRawCategory(group) || "other"
        var name = displayName(app)
        var segments = group.segments || []
        for (var s = 0; s < segments.length; s++) {
            var start = Number(segments[s].startUnixSec)
            var end = Number(segments[s].endUnixSec)
            if (!isFinite(start) || !isFinite(end) || end <= start) continue
            out.push({ groupKey: key, displayName: name, category: category,
                       start: start, end: end, seconds: end - start })
        }
    }
    return out
}

// A candidate beats the incumbent for a contested instant when it is shorter:
// the overlap is the gap-merge artifact of a long segment stretching over a
// brief excursion, so the interrupting segment is the real foreground.
// Tiebreak later start, then groupKey, so the ring is stable across rebuilds.
function ringOverlapBeats(candidate, current) {
    if (candidate.seconds !== current.seconds) return candidate.seconds < current.seconds
    if (candidate.start !== current.start) return candidate.start > current.start
    return String(candidate.groupKey) < String(current.groupKey)
}

// Sweep line over every segment boundary. Each elementary interval between two
// consecutive boundaries is either fully covered by a row or not touched by it,
// so one winner per interval yields a non-overlapping timeline.
// Lazy-deletion binary heap ordered by ringOverlapBeats, with the row's index
// as a final tiebreak so equal rows keep the original array order (the old
// linear scan kept the first such row).
function ringHeapBeats(a, b) {
    if (ringOverlapBeats(a.row, b.row)) return true
    if (ringOverlapBeats(b.row, a.row)) return false
    return a.index < b.index
}

function ringHeapPush(heap, entry) {
    heap.push(entry)
    var i = heap.length - 1
    while (i > 0) {
        var parent = (i - 1) >> 1
        if (!ringHeapBeats(heap[i], heap[parent])) break
        var swap = heap[i]; heap[i] = heap[parent]; heap[parent] = swap
        i = parent
    }
}

function ringHeapPop(heap) {
    var top = heap[0]
    var last = heap.pop()
    if (heap.length > 0) {
        heap[0] = last
        var i = 0
        for (;;) {
            var l = 2 * i + 1, r = l + 1, best = i
            if (l < heap.length && ringHeapBeats(heap[l], heap[best])) best = l
            if (r < heap.length && ringHeapBeats(heap[r], heap[best])) best = r
            if (best === i) break
            var swap = heap[i]; heap[i] = heap[best]; heap[best] = swap
            i = best
        }
    }
    return top
}

// Sweep line over every segment boundary. Each elementary interval between two
// consecutive boundaries is either fully covered by a row or not touched by it,
// so one winner per interval yields a non-overlapping timeline.
//
// The winner is tracked in a heap instead of rescanning every row per tick.
// That scan made this O(N²): a month window flattens to ~3.2k rows and ~6.5k
// ticks, i.e. ~21M comparisons (~560ms measured). Rows enter the heap at their
// start tick and are discarded from the top once expired; because the heap top
// is the global minimum, an active top is also the best active row, so buried
// expired entries can never win.
//
// Coverage test is unchanged: `row.start <= from && row.end >= to`. Since `to`
// is the next tick after `from` and every row end is itself a tick,
// `row.end >= to` is exactly `row.end > from`, which is the expiry check.
function ringResolveOverlap(rows) {
    if (rows.length === 0) return []
    var bounds = []
    var i
    for (i = 0; i < rows.length; i++) { bounds.push(rows[i].start); bounds.push(rows[i].end) }
    bounds.sort(function (a, b) { return a - b })
    var ticks = []
    for (i = 0; i < bounds.length; i++)
        if (i === 0 || bounds[i] !== bounds[i - 1]) ticks.push(bounds[i])

    var order = []
    for (i = 0; i < rows.length; i++) order.push({ row: rows[i], index: i })
    order.sort(function (a, b) {
        if (a.row.start !== b.row.start) return a.row.start - b.row.start
        return a.index - b.index
    })

    var heap = []
    var pending = 0
    var out = []
    for (var t = 0; t + 1 < ticks.length; t++) {
        var from = ticks[t]
        var to = ticks[t + 1]
        while (pending < order.length && order[pending].row.start <= from) {
            ringHeapPush(heap, order[pending])
            pending++
        }
        while (heap.length > 0 && heap[0].row.end <= from) ringHeapPop(heap)
        if (heap.length === 0) continue
        var winner = heap[0].row
        out.push({
            category: winner.category,
            start: from, end: to, seconds: to - from,
            apps: [{ groupKey: winner.groupKey, displayName: winner.displayName, seconds: to - from }],
            absorbedCount: 0, mergedFrom: 1
        })
    }
    return out
}

function ringMergeApps(target, source) {
    for (var i = 0; i < source.length; i++) {
        var found = null
        for (var j = 0; j < target.length; j++) {
            if (target[j].groupKey === source[i].groupKey) { found = target[j]; break }
        }
        if (found) found.seconds += source[i].seconds
        else target.push({ groupKey: source[i].groupKey,
                           displayName: source[i].displayName,
                           seconds: source[i].seconds })
    }
}

function ringCopyRun(run) {
    return { category: run.category, start: run.start, end: run.end, seconds: run.seconds,
             apps: run.apps.slice(), absorbedCount: run.absorbedCount,
             mergedFrom: run.mergedFrom, pinned: run.pinned === true }
}

// Join adjacent runs that share a category. A hole is spanned only when it is
// under bridgeSeconds AND both sides share a category — a real idle gap stays a
// gap. Bridging never invents a category, it only extends an existing one.
function ringCoalesce(runs, bridgeSeconds) {
    var out = []
    for (var i = 0; i < runs.length; i++) {
        var run = runs[i]
        var last = out.length > 0 ? out[out.length - 1] : null
        if (last && last.category === run.category
                && run.start >= last.end && run.start - last.end <= bridgeSeconds) {
            last.end = Math.max(last.end, run.end)
            last.seconds = last.end - last.start
            last.absorbedCount += run.absorbedCount
            last.mergedFrom += run.mergedFrom
            ringMergeApps(last.apps, run.apps)
            continue
        }
        out.push(ringCopyRun(run))
    }
    return out
}

// Same fold as ringCoalesce, but compacting `runs` in place instead of building
// a copied array. Only for arrays ringSmooth already owns: the copying variant
// stays the entry point, so nothing a caller handed us is ever mutated.
//
// This is where the Month/Year cost actually lived. ringSmooth ran up to 2n+8
// iterations and each one re-coalesced the whole array through ringCopyRun —
// for a month that is ~4.5k iterations over ~4.8k runs, i.e. ~21M fresh objects
// (~2.3s measured). The fold itself is unchanged, so the values it produces are
// identical; only the allocation disappears.
function ringCoalesceInPlace(runs, bridgeSeconds) {
    var write = 0
    for (var i = 0; i < runs.length; i++) {
        var run = runs[i]
        var last = write > 0 ? runs[write - 1] : null
        if (last && last.category === run.category
                && run.start >= last.end && run.start - last.end <= bridgeSeconds) {
            last.end = Math.max(last.end, run.end)
            last.seconds = last.end - last.start
            last.absorbedCount += run.absorbedCount
            last.mergedFrom += run.mergedFrom
            ringMergeApps(last.apps, run.apps)
            continue
        }
        runs[write++] = run
    }
    runs.length = write
    return runs
}

// Shortest first, tiebreak earlier start: left-to-right would let an early
// absorption change a later outcome by scan order.
function ringShortestIndex(runs, minSeconds) {
    var index = -1
    for (var i = 0; i < runs.length; i++) {
        if (runs[i].pinned) continue
        if (runs[i].seconds >= minSeconds) continue
        if (index < 0 || runs[i].seconds < runs[index].seconds) index = i
    }
    return index
}

// Remove one short run, giving its span to a neighbour where there is one.
// Isolated runs — gaps on both sides — are the only case where measured time
// leaves the ring entirely, so they are counted apart from absorptions.
// Splices `runs` in place and returns it. It already mutated prev/next/target
// in place before this change; the array rebuild it also did was pure waste,
// because ringSmooth immediately replaced its `current` with the result.
function ringAbsorbAt(runs, index, stats) {
    var run = runs[index]
    var prev = index > 0 ? runs[index - 1] : null
    var next = index + 1 < runs.length ? runs[index + 1] : null
    var prevTouches = prev !== null && prev.end >= run.start
    var nextTouches = next !== null && next.start <= run.end

    if (!prevTouches && !nextTouches) {
        stats.droppedCount += 1
        stats.droppedSeconds += run.seconds
        runs.splice(index, 1)
        return runs
    }

    stats.absorbedCount += 1
    stats.absorbedSeconds += run.seconds

    if (prevTouches && nextTouches && prev.category === next.category) {
        // Same category on both sides: the run vanishes and the two become one.
        prev.end = Math.max(prev.end, next.end)
        prev.seconds = prev.end - prev.start
        prev.absorbedCount += 1 + next.absorbedCount
        prev.mergedFrom += next.mergedFrom
        ringMergeApps(prev.apps, run.apps)
        ringMergeApps(prev.apps, next.apps)
        runs.splice(index, 2)
        return runs
    }

    var target
    if (prevTouches && nextTouches) target = prev.seconds >= next.seconds ? prev : next
    else target = prevTouches ? prev : next

    if (target === prev) target.end = Math.max(target.end, run.end)
    else target.start = Math.min(target.start, run.start)
    target.seconds = target.end - target.start
    target.absorbedCount += 1
    ringMergeApps(target.apps, run.apps)
    runs.splice(index, 1)
    return runs
}

// One smoothing pass. Absorbing only ever grows runs, so it cannot create a new
// short run — but merging around a deleted run can make two same-category runs
// adjacent, so coalescing and absorbing alternate to a fixpoint.
//
// `dropIsolated` is what separates the two passes. A sub-minute record with
// gaps on both sides is noise and leaves the ring; a *legibility*-thin run with
// gaps on both sides is real time that simply happens to be brief, so it is
// pinned and kept, and ringProject pads it to a visible sweep.
//
// Each iteration either removes a run or pins one, so the loop terminates.
function ringSmooth(runs, minSeconds, bridgeSeconds, stats, dropIsolated) {
    var current = ringCoalesce(runs, bridgeSeconds)
    var guard = current.length * 2 + 8
    while (guard-- > 0) {
        var index = ringShortestIndex(current, minSeconds)
        if (index < 0) break
        var run = current[index]
        var prev = index > 0 ? current[index - 1] : null
        var next = index + 1 < current.length ? current[index + 1] : null
        var isolated = !(prev !== null && prev.end >= run.start)
                    && !(next !== null && next.start <= run.end)
        if (isolated && !dropIsolated) { run.pinned = true; continue }
        // `current` is ours (the first ringCoalesce above already copied), so
        // absorb + re-coalesce in place. Same fold, same order, no allocation.
        current = ringCoalesceInPlace(ringAbsorbAt(current, index, stats),
                                      bridgeSeconds)
    }
    for (var i = 0; i < current.length; i++) current[i].pinned = false
    return current
}

// Two floors, because they answer different questions.
//   1. Noise    — "was this a real stretch of use?"  Sub-minute records are not.
//   2. Legibility — "can this be seen and clicked?"  Sub-2-degree blocks cannot.
// Without the second, a day of rapid switching still renders as a barcode.
function ringDenoise(runs, minSeconds, minArcSeconds, bridgeSeconds, stats) {
    var current = ringSmooth(runs, minSeconds, bridgeSeconds, stats, true)
    if (minArcSeconds > minSeconds)
        current = ringSmooth(current, minArcSeconds, bridgeSeconds, stats, false)
    return current
}

// Clip to the requested half, project onto the dial, and pad a sweep that would
// otherwise be a sub-pixel hairline. `seconds` always reports the true visible
// span, never the padded sweep.
function ringProject(runs, dayStartUnix, half, minSweepDeg) {
    var halfStart = Number(dayStartUnix) + (half === "pm" ? RING_HALF_SECONDS : 0)
    var halfEnd = halfStart + RING_HALF_SECONDS
    var out = []
    for (var i = 0; i < runs.length; i++) {
        var run = runs[i]
        var start = Math.max(run.start, halfStart)
        var end = Math.min(run.end, halfEnd)
        if (end <= start) continue

        var startAngle = (start - halfStart) * 360 / RING_HALF_SECONDS
        var endAngle = (end - halfStart) * 360 / RING_HALF_SECONDS
        var sweepPadded = false
        if (endAngle - startAngle < minSweepDeg) {
            var midpoint = (startAngle + endAngle) / 2
            endAngle = Math.min(360, midpoint + minSweepDeg / 2)
            startAngle = Math.max(0, endAngle - minSweepDeg)
            // An arc at the very start of the half cannot grow leftwards, so
            // give back the clamped remainder on the other side.
            if (endAngle - startAngle < minSweepDeg)
                endAngle = Math.min(360, startAngle + minSweepDeg)
            sweepPadded = true
        }

        var apps = run.apps.slice()
        apps.sort(function (a, b) {
            if (b.seconds !== a.seconds) return b.seconds - a.seconds
            return String(a.displayName).localeCompare(String(b.displayName))
        })

        out.push({
            arcId: run.category + ":" + start + ":" + end,
            category: run.category,
            startUnixSec: start,
            endUnixSec: end,
            seconds: Math.floor(end - start),
            startAngle: startAngle,
            endAngle: endAngle,
            sweepPadded: sweepPadded,
            apps: apps.slice(0, RING_MAX_APPS),
            appCount: apps.length,
            absorbedCount: run.absorbedCount,
            mergedFrom: run.mergedFrom
        })
    }
    return out
}

// Categories present in the denoised ring, most ring-time first. The page pairs
// these ids with real unfiltered per-category seconds, so the legend never
// reports denoised geometry as a number.
function ringCategories(runs) {
    var source = runs || []
    var spans = {}
    var order = []
    for (var i = 0; i < source.length; i++) {
        var id = source[i].category
        if (spans[id] === undefined) { spans[id] = 0; order.push(id) }
        spans[id] += source[i].seconds
    }
    order.sort(function (a, b) {
        if (spans[b] !== spans[a]) return spans[b] - spans[a]
        return a.localeCompare(b)
    })
    return order
}

function ringOption(options, name, fallback) {
    var opts = options || {}
    if (opts[name] === undefined) return fallback
    return Math.max(0, Number(opts[name]) || 0)
}

// Denoise the whole day once. The result does not depend on which half is
// showing, so the page caches it and only re-projects on an AM/PM toggle.
// `stats` carries numbers only — the disclosure sentence is assembled in QML
// through I18n.sentence(), per rule 04 3.
function buildCategoryRingRuns(segmentGroups, periodApps, options) {
    var minSeconds = ringOption(options, "minSeconds", RING_MIN_SECONDS)
    var bridgeSeconds = ringOption(options, "bridgeSeconds", RING_BRIDGE_SECONDS)
    // Degrees are the unit that matters for legibility; seconds are what the
    // pipeline works in. On the 12-hour dial 1 degree is 120 seconds.
    var minArcSeconds = ringOption(options, "minArcDeg", RING_MIN_ARC_DEG)
            * RING_HALF_SECONDS / 360

    var flat = ringFlatten(segmentGroups, periodApps)
    var stats = { droppedCount: 0, droppedSeconds: 0,
                  absorbedCount: 0, absorbedSeconds: 0,
                  mergedFrom: flat.length, coveredSeconds: 0, runCount: 0 }

    var runs = ringDenoise(ringResolveOverlap(flat), minSeconds, minArcSeconds,
                           bridgeSeconds, stats)
    for (var i = 0; i < runs.length; i++) stats.coveredSeconds += runs[i].seconds
    stats.runCount = runs.length
    return { runs: runs, stats: stats }
}

function projectCategoryRing(runs, dayStartUnix, half, options) {
    return ringProject(runs || [], dayStartUnix, half,
                       ringOption(options, "minSweepDeg", RING_MIN_SWEEP_DEG))
}

// Whole pipeline in one call: denoise the day, then project the chosen half.
function buildCategoryRing(segmentGroups, periodApps, dayStartUnix, half, options) {
    var built = buildCategoryRingRuns(segmentGroups, periodApps, options)
    return { arcs: projectCategoryRing(built.runs, dayStartUnix, half, options),
             stats: built.stats }
}
