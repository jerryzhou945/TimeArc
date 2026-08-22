from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = (ROOT / "qml/desktop/pages/DesktopStatsPage.qml").read_text(encoding="utf-8")


def section(start, end):
    return QML.split(start, 1)[1].split(end, 1)[0]


def main():
    day = section("// ====== 日视图", "// ====== 周视图")
    dial = section("component StatsApplicationClock", "component StatsDayTimeline")

    assert "StatsApplicationClock" in day
    assert "for (var tick = 0; tick < 60; tick++)" in dial
    assert "model: 12" in dial
    assert "modelData.showIcon" in dial
    assert "modelData.lane" in dial

    assert "// ====== 周/月/年共用聚合视图 ======" in QML
    aggregate = section("// ====== 周/月/年共用聚合视图 ======", "StatsAppLibrary {")
    assert 'visible: root.range !== "day" && root.hasData' in aggregate
    expected = [
        "StatsAggregateSummary",
        "StatsBarChart",
        "StatsCategoryDistribution",
        "StatsRankingList",
    ]
    positions = [aggregate.index(name) for name in expected]
    assert positions == sorted(positions)
    assert 'barCount: root.vmTrendBars.length' in aggregate
    assert 'rows: root.vmCategories' in aggregate
    assert 'rows: root.vmRanking' in aggregate
    for old_component in ("StatsHeatmap", "StatsLineChart", "StatsYearRhythm", "StatsInsightCard"):
        assert old_component not in aggregate

    assert "component StatsAggregateSummary" in QML
    assert "component StatsCategoryDistribution" in QML
    assert "component StatsMetricStrip" in QML
    assert "StatsMetricStrip {" in QML
    ranking = section("component StatsRankingList", "component StatsInsightCard")
    assert "slice(0, 5)" in ranking
    assert 'modelData.percent + "%"' in ranking
    library = section("component StatsAppLibrary", "component StatsAggregateSummary")
    assert 'text: root.tr("最近记录")' in library
    assert "root.recentRecordText(modelData.lastUsedUnixSec)" in library
    print("stats period layout static checks passed")


if __name__ == "__main__":
    main()
