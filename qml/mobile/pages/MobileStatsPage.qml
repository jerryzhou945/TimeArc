import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    color: theme.bg

    property int selectedSegment: 0
    property var segments: [
        { "label": "今天", "range": "day" },
        { "label": "7天", "range": "7d" },
        { "label": "30天", "range": "30d" }
    ]
    property var dashboard: ({ "totalText": "0s", "topApps": [], "empty": true })
    property var topApps: dashboard.topApps || []

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

    function reloadDashboard() {
        if (typeof mobileUsageService === "undefined" || !mobileUsageService) {
            dashboard = {
                "totalText": "0s",
                "topApps": [],
                "empty": true,
                "syncStatusText": "移动端数据服务未连接"
            }
            return
        }
        dashboard = mobileUsageService.getDashboardForRange(segments[selectedSegment].range)
    }

    Component.onCompleted: reloadDashboard()

    Connections {
        target: typeof mobileUsageService === "undefined" ? null : mobileUsageService

        function onDataChanged() {
            root.reloadDashboard()
        }

        function onStatusChanged() {
            root.reloadDashboard()
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
            contentHeight: content.implicitHeight + 20

            Column {
                id: content
                width: flick.width - 40
                x: 20
                spacing: 16

                MobileSectionTitle {
                    width: parent.width
                    theme: root.theme
                    title: "统计"
                    subtitle: "Android 使用时长"
                }

                Rectangle {
                    width: parent.width
                    height: summaryColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Column {
                        id: summaryColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        Text {
                            text: root.segments[root.selectedSegment].label + "记录"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Text {
                            width: parent.width
                            text: root.dashboard.totalText || "0s"
                            color: root.theme.textPrimary
                            font.pixelSize: 36
                            font.weight: Font.Bold
                            font.letterSpacing: 0
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.dashboard.syncStatusText || "等待 Android 使用数据同步"
                            color: root.dashboard.empty ? root.theme.textMuted : root.theme.green
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 12
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 2

                        Repeater {
                            model: root.segments

                            Rectangle {
                                width: parent.width / root.segments.length
                                height: parent.height
                                radius: 10
                                color: index === root.selectedSegment ? root.theme.cardElevated : "transparent"
                                border.color: index === root.selectedSegment ? root.theme.border : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: index === root.selectedSegment ? root.theme.textPrimary : root.theme.textMuted
                                    font.pixelSize: 13
                                    font.weight: index === root.selectedSegment ? Font.Medium : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.selectedSegment = index
                                        root.reloadDashboard()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: sourceColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Column {
                        id: sourceColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            text: "数据来源"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Row {
                            width: parent.width

                            Text {
                                width: parent.width - sourceValue.width
                                text: "Android UsageStats"
                                color: root.theme.textSecondary
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                id: sourceValue
                                text: root.dashboard.empty ? "等待同步" : "已入库"
                                color: root.theme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: root.theme.border

                            Rectangle {
                                width: parent.width * (root.dashboard.empty ? 0 : 1)
                                height: parent.height
                                radius: 3
                                color: root.theme.accent
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: topAppsColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Column {
                        id: topAppsColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 0

                        Text {
                            width: parent.width
                            text: "常用应用"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Text {
                            width: parent.width
                            visible: root.topApps.length === 0
                            text: "还没有 Android 使用数据。授权后打开手机端，TimeArc 会读取系统 UsageStats 并写入数据库。"
                            color: root.theme.textSecondary
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                            topPadding: 12
                            bottomPadding: 4
                        }

                        Repeater {
                            model: root.topApps

                            Item {
                                width: parent.width
                                height: 44

                                Row {
                                    anchors.fill: parent
                                    spacing: 12

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28
                                        height: 28
                                        radius: 8
                                        color: root.theme.cardElevated
                                        border.color: root.theme.border
                                        border.width: 1
                                        clip: true

                                        Image {
                                            id: appIcon
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            source: root.iconSource(modelData.appIconPath)
                                            visible: source !== "" && status !== Image.Error
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            asynchronous: true
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: appIcon.source === "" || appIcon.status === Image.Error
                                            text: modelData.initial
                                            color: root.theme.accent
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 112
                                        text: modelData.displayName || modelData.packageName
                                        color: root.theme.textSecondary
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 54
                                        text: modelData.durationText
                                        color: root.theme.textPrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: root.theme.border
                                    opacity: index < root.topApps.length - 1 ? 0.5 : 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
