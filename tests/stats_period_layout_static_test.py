from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = (ROOT / "qml/desktop/pages/DesktopStatsPage.qml").read_text(encoding="utf-8")


def section(start, end):
    return QML.split(start, 1)[1].split(end, 1)[0]


def main():
    day = section("// ====== 日视图", "// ====== 周视图")
    dial = section("component StatsApplicationClock", "component StatsDayTimeline")
    summary = section("component StatsAggregateSummary", "component StatsCategoryDistribution")

    assert 'readonly property bool statsLayoutStacked: root.width < 900' in QML

    assert "StatsApplicationClock" in day
    assert "DailyUsageShare" in day
    assert "StatsDayTimeline" not in day
    assert "StatsRankingList" not in day
    assert "root.statsLayoutStacked" in day
    assert "root.sideCollapsed" not in day
    assert "for (var tick = 0; tick < 60; tick++)" in dial
    assert "model: 12" in dial
    assert "modelData.showIcon" in dial
    assert "modelData.lane" in dial
    assert 'property string lockedId: ""' in dial
    assert "readonly property string activeId:" in dial
    assert "acceptedButtons: Qt.LeftButton" in dial
    assert "onClicked: function (mouse)" in dial
    assert "dialCard.lockedId = hitId === dialCard.lockedId ? \"\" : hitId" in dial

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
    print("stats period layout static checks passed")


if __name__ == "__main__":
    main()
