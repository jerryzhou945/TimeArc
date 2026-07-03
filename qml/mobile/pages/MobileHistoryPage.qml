import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    color: "#07131F"

    property var monthDashboard: emptyDashboard()
    property var yearDashboard: emptyDashboard()
    readonly property var monthTopApps: monthDashboard.topApps || []

    function emptyDashboard() {
        return {
            "totalSec": 0,
            "totalText": "0s",
            "averageDailyText": "0s",
            "activeDays": 0,
            "appCount": 0,
            "topApps": [],
            "empty": true,
            "syncStatusText": "等待 Android 使用数据同步"
        }
    }

    function hasMobileUsageService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function reloadDashboards() {
        if (!hasMobileUsageService()) {
            monthDashboard = emptyDashboard()
            yearDashboard = emptyDashboard()
            return
        }
        monthDashboard = mobileUsageService.getDashboardForRange("month")
        yearDashboard = mobileUsageService.getDashboardForRange("year")
    }

    function monthName() {
        var now = new Date()
        return (now.getMonth() + 1) + "月"
    }

    Component.onCompleted: reloadDashboards()

    Connections {
        target: root.hasMobileUsageService() ? mobileUsageService : null

        function onDataChanged() {
            root.reloadDashboards()
        }

        function onStatusChanged() {
            root.reloadDashboards()
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#0B263A" }
            GradientStop { position: 0.42; color: "#0A1928" }
            GradientStop { position: 1.00; color: "#07131F" }
        }
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
            contentHeight: content.implicitHeight + 24

            Column {
                id: content
                width: flick.width - 40
                x: 20
                spacing: 14

                Text {
                    width: parent.width
                    text: "记忆湖"
                    color: "#FFFFFF"
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: "先沿用桌面端月度报告的组织方式，把安卓端使用时长变成可回看的时间报告。"
                    color: "#B8CAD8"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                ReportHero {
                    width: parent.width
                    title: root.monthName() + "月度报告"
                    subtitle: "应用排行、活跃天数、日均使用时长"
                    total: root.monthDashboard.totalText || "0s"
                    detail: "记录 " + (root.monthDashboard.activeDays || 0) + " 天 · " + (root.monthDashboard.appCount || 0) + " 个应用"
                    badge: "本月"
                }

                Row {
                    width: parent.width
                    height: 104
                    spacing: 10

                    MiniReport {
                        width: (parent.width - 10) / 2
                        label: "年度报告"
                        value: root.yearDashboard.totalText || "0s"
                        desc: "按年累计"
                    }

                    MiniReport {
                        width: (parent.width - 10) / 2
                        label: "本月日均"
                        value: root.monthDashboard.averageDailyText || "0s"
                        desc: "活跃日平均"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: lakeList.implicitHeight + 28
                    radius: 20
                    color: "#101B29DD"
                    border.color: "#FFFFFF14"
                    border.width: 1

                    Column {
                        id: lakeList
                        width: parent.width - 28
                        x: 14
                        y: 14
                        spacing: 10

                        Row {
                            width: parent.width
                            height: 24

                            Text {
                                width: parent.width - 90
                                text: "报告片段"
                                color: "#FFFFFF"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: 90
                                text: "预览"
                                color: "#8FA4B7"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        ReportRow {
                            width: parent.width
                            token: "月"
                            title: root.monthName() + "应用使用排行"
                            desc: root.monthTopApps.length > 0
                                  ? "Top 1 · " + (root.monthTopApps[0].displayName || root.monthTopApps[0].packageName)
                                  : "等待安卓数据同步"
                        }

                        ReportRow {
                            width: parent.width
                            token: "天"
                            title: "活跃天数"
                            desc: "本月记录 " + (root.monthDashboard.activeDays || 0) + " 天，平均 " + (root.monthDashboard.averageDailyText || "0s")
                        }

                        ReportRow {
                            width: parent.width
                            token: "年"
                            title: "年度时间线"
                            desc: "累计 " + (root.yearDashboard.totalText || "0s") + "，后续可接桌面端年度报告"
                        }
                    }
                }
            }
        }
    }

    component ReportHero: Rectangle {
        property string title: ""
        property string subtitle: ""
        property string total: ""
        property string detail: ""
        property string badge: ""

        height: 190
        radius: 24
        color: "#14273ADD"
        border.color: "#FFFFFF18"
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.65
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2E7196" }
                GradientStop { position: 1.0; color: "#14273A00" }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            Text {
                text: badge
                color: "#DDF8FF"
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                text: title
                color: "#FFFFFF"
                font.pixelSize: 27
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: subtitle
                color: "#C8D8E5"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: 8 }

            Text {
                width: parent.width
                text: total + " · " + detail
                color: "#FFFFFF"
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }
    }

    component MiniReport: Rectangle {
        property string label: ""
        property string value: ""
        property string desc: ""

        radius: 18
        color: "#152335DD"
        border.color: "#FFFFFF12"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 9

            Text {
                width: parent.width
                text: label
                color: "#8FA4B7"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: value
                color: "#FFFFFF"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: desc
                color: "#B8CAD8"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    component ReportRow: Item {
        property string token: ""
        property string title: ""
        property string desc: ""

        height: 66

        Row {
            anchors.fill: parent
            spacing: 12

            Rectangle {
                width: 42
                height: 42
                radius: 14
                color: "#EAF8FF"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: token
                    color: "#0B1C2B"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
            }

            Column {
                width: parent.width - 78
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    width: parent.width
                    text: title
                    color: "#FFFFFF"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: desc
                    color: "#8FA4B7"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Text {
                width: 24
                height: parent.height
                text: "›"
                color: "#8FA4B7"
                font.pixelSize: 26
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
