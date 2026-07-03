import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    color: "#07131F"

    property int selectedSegment: 1
    property var periods: [
        { "label": "今天", "range": "day" },
        { "label": "7天", "range": "week" },
        { "label": "30天", "range": "month" },
        { "label": "今年", "range": "year" },
        { "label": "总计", "range": "all" }
    ]
    property var dashboard: emptyDashboard()
    readonly property var topApps: dashboard.topApps || []

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

    function reloadDashboard() {
        if (!hasMobileUsageService()) {
            dashboard = emptyDashboard()
            return
        }
        dashboard = mobileUsageService.getDashboardForRange(periods[selectedSegment].range)
    }

    function iconSource(path) {
        var value = (path || "").toString().trim()
        if (value.length === 0)
            return ""
        if (value.indexOf("file://") === 0 || value.indexOf("qrc:/") === 0 || value.indexOf("image://") === 0)
            return value
        value = value.replace(/\\/g, "/")
        if (value.charAt(0) === "/")
            return "file://" + value
        return "file:///" + value
    }

    Component.onCompleted: reloadDashboard()

    Connections {
        target: root.hasMobileUsageService() ? mobileUsageService : null

        function onDataChanged() {
            root.reloadDashboard()
        }

        function onStatusChanged() {
            root.reloadDashboard()
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#0B263A" }
            GradientStop { position: 0.36; color: "#0A1827" }
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
                    text: "统计"
                    color: "#FFFFFF"
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: "Android UsageStats 写入数据库后的聚合视图"
                    color: "#B8CAD8"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Flickable {
                    width: parent.width
                    height: 42
                    contentWidth: periodRow.implicitWidth
                    interactive: contentWidth > width
                    clip: true

                    Row {
                        id: periodRow
                        height: parent.height
                        spacing: 8

                        Repeater {
                            model: root.periods

                            RangeTab {
                                label: modelData.label
                                active: index === root.selectedSegment
                                onClicked: {
                                    root.selectedSegment = index
                                    root.reloadDashboard()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 178
                    radius: 22
                    color: "#122133DD"
                    border.color: "#FFFFFF18"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            width: parent.width
                            text: root.periods[root.selectedSegment].label + "使用时间"
                            color: "#B8CAD8"
                            font.pixelSize: 13
                        }

                        Text {
                            width: parent.width
                            text: root.dashboard.totalText || "0s"
                            color: "#FFFFFF"
                            font.pixelSize: 42
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.dashboard.empty ? (root.dashboard.syncStatusText || "等待数据同步") : "已按应用合并排行，避免跨天重复显示"
                            color: root.dashboard.empty ? "#B8CAD8" : "#8DE8F2"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 92
                    spacing: 10

                    StatTile {
                        width: (parent.width - 20) / 3
                        label: "记录天数"
                        value: "" + (root.dashboard.activeDays || 0)
                    }

                    StatTile {
                        width: (parent.width - 20) / 3
                        label: "应用数"
                        value: "" + (root.dashboard.appCount || 0)
                    }

                    StatTile {
                        width: (parent.width - 20) / 3
                        label: "日均"
                        value: root.dashboard.averageDailyText || "0s"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: appListColumn.implicitHeight + 28
                    radius: 20
                    color: "#101B29DD"
                    border.color: "#FFFFFF14"
                    border.width: 1

                    Column {
                        id: appListColumn
                        width: parent.width - 28
                        x: 14
                        y: 14
                        spacing: 10

                        Row {
                            width: parent.width
                            height: 24

                            Text {
                                width: parent.width - 90
                                text: "应用排行"
                                color: "#FFFFFF"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: 90
                                text: root.periods[root.selectedSegment].label
                                color: "#8FA4B7"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Text {
                            width: parent.width
                            visible: root.topApps.length === 0
                            text: "暂无安卓使用时长。授权后回到 TimeArc，系统数据会同步到本地 SQLite。"
                            color: "#B8CAD8"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: root.topApps

                            AppStatRow {
                                width: parent.width
                                app: modelData
                                iconUrl: root.iconSource(modelData.appIconPath)
                            }
                        }
                    }
                }
            }
        }
    }

    component RangeTab: Rectangle {
        id: tab

        property string label: ""
        property bool active: false
        signal clicked()

        width: Math.max(58, label.length * 20)
        height: 34
        radius: 17
        color: active ? "#EAF8FF" : "#FFFFFF12"
        border.color: active ? "#EAF8FF" : "#FFFFFF18"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: tab.label
            color: tab.active ? "#0B1C2B" : "#D7E6F0"
            font.pixelSize: 13
            font.weight: tab.active ? Font.DemiBold : Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            onClicked: tab.clicked()
        }
    }

    component StatTile: Rectangle {
        property string label: ""
        property string value: ""

        radius: 18
        color: "#152335DD"
        border.color: "#FFFFFF12"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

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
                font.pixelSize: 20
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    component AppStatRow: Item {
        property var app: ({})
        property string iconUrl: ""

        height: 58

        Row {
            anchors.fill: parent
            spacing: 10

            Rectangle {
                width: 38
                height: 38
                radius: 10
                color: "#243246"
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Image {
                    id: appIcon
                    anchors.fill: parent
                    anchors.margins: 4
                    source: iconUrl
                    visible: iconUrl.length > 0 && status !== Image.Error
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: app.initial || "?"
                    color: "#DDF8FF"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width - 110
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: app.displayName || app.packageName || "未知应用"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 3
                    color: "#314052"

                    Rectangle {
                        width: parent.width * Math.max(0.04, Math.min(1, (app.sharePct || 0) / 100))
                        height: parent.height
                        radius: parent.radius
                        color: "#8DE8F2"
                    }
                }
            }

            Text {
                width: 62
                anchors.verticalCenter: parent.verticalCenter
                text: app.durationText || "0s"
                color: "#EAF8FF"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }
}
