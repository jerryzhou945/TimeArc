from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = (ROOT / "qml/desktop/pages/DesktopStatsPage.qml").read_text(encoding="utf-8")


def section(start, end):
    return QML.split(start, 1)[1].split(end, 1)[0]


def main():
    day = section("// ====== 日视图", "// ====== 周视图")
    dial = section("component StatsCategoryClock", "component StatsDayTimeline")
    summary = section("component StatsAggregateSummary", "component StatsCategoryDistribution")

    assert 'readonly property bool statsLayoutStacked: root.width < 900' in QML

    assert "StatsCategoryClock" in day
    assert "DailyUsageShare" in day
    assert "StatsDayTimeline" not in day
    assert "StatsRankingList" not in day
    assert "root.statsLayoutStacked" in day
    assert "root.sideCollapsed" not in day
    # The clock stays a clock: 60 ticks and the 12 hour numbers survive the
    # redesign, and so does hover-preview / click-to-pin.
    assert "for (var tick = 0; tick < 60; tick++)" in dial
    assert "model: 12" in dial
    assert 'property string lockedId: ""' in dial
    assert "readonly property string activeId:" in dial
    assert "acceptedButtons: Qt.LeftButton" in dial
    assert "onClicked: function (mouse)" in dial
    assert "ringCard.lockedId = hitId === ringCard.lockedId ? \"\" : hitId" in dial

    # One ring, not three lanes: no lane radius, no per-app icon heuristic.
    for retired in ("modelData.lane", "modelData.showIcon", "clockLaneRadiusScale",
                    "StatsApplicationClock", "buildClockSegments"):
        assert retired not in QML, retired

    # Records render as filled annular sectors; hover/click expands the selected
    # sector without mutating its time geometry.
    assert "ctx.fill()" in dial
    assert "trackInner" in dial and "trackOuter" in dial
    assert "var inner = trackInner - (emphasized" in dial
    assert "var outer = trackOuter + (emphasized" in dial
    assert "ringRadiusScale" in dial and "ringWidthScale" in dial

    # A focused category block resolves its compact summaries back to full app
    # rows, so real app icons appear in the hub while the legend stays compact.
    assert "root.clockArcApps(ringCard.focusedArc.apps)" in dial
    assert "AppVisual.modelIconSource(modelData)" in dial
    assert "ringCard.legend" in dial
    assert "ringCard.footnote" in dial
    assert "root.ringFootnote()" in QML

    # Geometry is denoised; the numbers are not. The hub total and the legend
    # seconds must keep coming from the unfiltered aggregate.
    assert "totalText: root.secondsToDisplay(root.vmTotalSec)" in day
    assert "categorySums(vmApps ? vmApps : [])" in QML

    # The whole day is denoised once; an AM/PM toggle only re-projects.
    assert "onClockHalfChanged: reprojectCategoryRing()" in QML
    assert "buildCategoryRingRuns" in QML and "projectCategoryRing" in QML

    assert "// ====== 周/月/年共用聚合视图 ======" in QML
    aggregate = section("// ====== 周/月/年共用聚合视图 ======", "StatsAppLibrary {")
    assert 'visible: root.range !== "day" && root.hasData' in aggregate
    assert "id: aggregateOverviewColumn" in aggregate
    assert "StatsAggregateSummary" in aggregate
    assert "StatsCategoryDistribution" in aggregate
    assert "StatsBarChart" in aggregate
    assert "StatsRankingList" not in aggregate
    summary_pos = aggregate.index("StatsAggregateSummary")
    categories_pos = aggregate.index("StatsCategoryDistribution")
    chart_pos = aggregate.index("StatsBarChart")
    assert summary_pos < categories_pos < chart_pos
    assert 'Layout.columnSpan: root.statsLayoutStacked ? 12 : 4' in aggregate
    assert 'Layout.columnSpan: root.statsLayoutStacked ? 12 : 8' in aggregate
    assert "root.sideCollapsed" not in aggregate
    assert "Layout.preferredHeight: 440" in aggregate
    assert "Layout.preferredHeight: 132" in aggregate
    assert 'barCount: root.vmTrendBars.length' in aggregate
    assert 'rows: root.vmCategories' in aggregate
    for old_component in ("StatsHeatmap", "StatsLineChart", "StatsYearRhythm", "StatsInsightCard"):
        assert old_component not in aggregate

    assert "component StatsAggregateSummary" in QML
    assert "component StatsCategoryDistribution" in QML
    assert "component StatsMetricStrip" in QML
    assert "StatsMetricStrip {" in QML
    assert "RowLayout {" in summary
    assert "Item { Layout.fillHeight: true }" not in summary
    library = section("component StatsAppLibrary", "component StatsAggregateSummary")
    assert 'text: root.tr("Recent records")' in library
    assert "root.recentRecordText(modelData.lastUsedUnixSec)" in library
    # The category ring is day-only. It is rendered inside a card gated on
    # `range === "day"`, and reprojectCategoryRing only ever projects one 12h
    # half of one day -- so building it for week/month/year was ~2.9s of work
    # whose result was discarded. rebuildCategoryRing must bail out early, and
    # must clear the ring view state so no stale arcs/legend survive a range
    # switch. See journal/errors/20260826-095248-C-stats-ring-quadratic-offscreen.
    ring = section("function rebuildCategoryRing()", "function reprojectCategoryRing()")
    assert 'if (range !== "day") {' in ring
    assert "_ringRuns = null" in ring
    assert "vmRingStats = null" in ring
    assert "vmRingLegend = []" in ring
    assert "vmRingArcs = []" in ring
    assert "return" in ring.split('if (range !== "day") {', 1)[1].split("}", 1)[0]
    assert 'visible: root.range === "day" && root.hasData' in QML

    print("stats period layout static checks passed")


if __name__ == "__main__":
    main()
