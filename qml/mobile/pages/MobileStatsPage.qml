import QtQuick
import "../components"

Item {
    id: root

    required property var theme
    property bool wallpaperActive: false
    property var rangeKeys: ["week", "month", "year", "all"]
    property var rangeMeta: ({
        "week": { "label": "本周", "note": "从周一开始" },
        "month": { "label": "本月", "note": "从本月一日开始" },
        "year": { "label": "今年", "note": "从一月一日开始" },
        "all": { "label": "总计", "note": "从第一条记录开始" }
    })
    property var dashboards: ({})
    property string selectedRange: "week"
    property bool detailOpen: false

    function emptyDashboard(key) {
        return {
            "rangeKey": key,
            "rangeLabel": rangeMeta[key].label,
            "rangeText": "",
            "totalText": "0s",
            "activeDays": 0,
            "topApps": [],
            "empty": true
        }
    }

    function hasService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function loadOverview() {
        var next = {}
        for (var i = 0; i < rangeKeys.length; ++i) {
            var key = rangeKeys[i]
            next[key] = hasService()
                    ? mobileUsageService.getDashboardForRange(key)
                    : emptyDashboard(key)
        }
        dashboards = next
    }

    function dashboardFor(key) {
        return dashboards[key] || emptyDashboard(key)
    }

    function openRange(key) {
        selectedRange = key
        detailOpen = true
        flick.contentY = 0
    }

    function closeRange() {
        detailOpen = false
        flick.contentY = 0
    }

    Component.onCompleted: loadOverview()

    Connections {
        target: root.hasService() ? mobileUsageService : null
        function onDataChanged() { root.loadOverview() }
        function onStatusChanged() { root.loadOverview() }
    }

    Column {
        anchors.fill: parent

        MobileStatusBar {
            width: parent.width
            theme: root.theme
        }

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - y
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: content.implicitHeight + 28

            Column {
                id: content
                width: flick.width - 32
                x: 16
                spacing: 16

                Row {
                    width: parent.width
                    height: 50

                    Rectangle {
                        visible: root.detailOpen
                        width: 44
                        height: 44
                        radius: 22
                        color: root.theme.panelColor(
                                   root.wallpaperActive, true)

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: root.theme.textPrimary
                            font.pixelSize: 30
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.closeRange()
                        }
                    }

                    Column {
                        width: parent.width - (root.detailOpen ? 44 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.detailOpen
                                  ? root.rangeMeta[root.selectedRange].label
                                  : "统计"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 27
                            font.weight: Font.Bold
                            horizontalAlignment: root.detailOpen
                                                 ? Text.AlignHCenter
                                                 : Text.AlignLeft
                        }

                        Text {
                            width: parent.width
                            text: root.detailOpen
                                  ? root.dashboardFor(
                                        root.selectedRange).rangeText
                                  : "按时间范围回看，不评价时间的好坏"
                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                            horizontalAlignment: root.detailOpen
                                                 ? Text.AlignHCenter
                                                 : Text.AlignLeft
                        }
                    }
                }

                Column {
                    visible: !root.detailOpen
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: root.rangeKeys

                        MobileGlassPanel {
                            id: rangeBlock
                            required property string modelData
                            width: parent.width
                            height: modelData === "all" ? 128 : 112
                            theme: root.theme
                            wallpaperActive: root.wallpaperActive
                            strong: modelData === "week"

                            readonly property var dashboard:
                                root.dashboardFor(modelData)
                            readonly property var leadApp:
                                (dashboard.topApps || []).length > 0
                                ? dashboard.topApps[0] : ({})

                            Row {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 13

                                MobileAppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    theme: root.theme
                                    app: rangeBlock.leadApp
                                    iconSize: modelData === "week" ? 58 : 50
                                    cornerRadius: 13
                                }

                                Column {
                                    width: parent.width - 112
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5

                                    Row {
                                        width: parent.width
                                        height: 23

                                        Text {
                                            width: parent.width - totalLabel.width - 8
                                            text: root.rangeMeta[modelData].label
                                            color: root.theme.textPrimary
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: 18
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            id: totalLabel
                                            text: rangeBlock.dashboard.totalText || "0s"
                                            color: root.theme.textPrimary
                                            font.family: root.theme.numberFontFamily
                                            font.pixelSize: 17
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: rangeBlock.dashboard.empty
                                              ? "暂无记录"
                                              : ((rangeBlock.leadApp.displayName
                                                  || "未知应用")
                                                 + " 使用最多")
                                        color: root.theme.textSecondary
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.rangeMeta[modelData].note
                                              + " · 记录 "
                                              + (rangeBlock.dashboard.activeDays || 0)
                                              + " 天"
                                        color: root.theme.textMuted
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    width: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "›"
                                    color: root.theme.textPrimary
                                    font.pixelSize: 30
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.openRange(modelData)
                            }
                        }
                    }
                }

                Column {
                    visible: root.detailOpen
                    width: parent.width
                    spacing: 12

                    MobileGlassPanel {
                        width: parent.width
                        height: 114
                        theme: root.theme
                        wallpaperActive: root.wallpaperActive
                        strong: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 7

                            Text {
                                width: parent.width
                                text: root.dashboardFor(
                                          root.selectedRange).totalText || "0s"
                                color: root.theme.textPrimary
                                font.family: root.theme.numberFontFamily
                                font.pixelSize: 35
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                text: "记录 "
                                      + (root.dashboardFor(
                                             root.selectedRange).activeDays || 0)
                                      + " 天 · "
                                      + ((root.dashboardFor(
                                              root.selectedRange).topApps || []).length)
                                      + " 个应用"
                                color: root.theme.textSecondary
                                font.family: root.theme.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "应用使用排行"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        topPadding: 4
                    }

                    Text {
                        width: parent.width
                        visible: (root.dashboardFor(
                                      root.selectedRange).topApps || []).length === 0
                        text: "这个时间范围还没有记录。开启使用情况访问并同步后，再回来看看。"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 14
                        lineHeight: 1.45
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.dashboardFor(
                                   root.selectedRange).topApps || []

                        MobileGlassPanel {
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 90
                            theme: root.theme
                            wallpaperActive: root.wallpaperActive

                            MobileUsageRankRow {
                                anchors.fill: parent
                                anchors.margins: 10
                                theme: root.theme
                                app: modelData
                                rank: index + 1
                                wallpaperActive: root.wallpaperActive
                            }
                        }
                    }
                }
            }
        }
    }
}
