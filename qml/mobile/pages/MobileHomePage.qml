import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    color: "#07131F"

    property var dashboard: emptyDashboard()
    property var totalDashboard: emptyDashboard()
    readonly property var topApps: dashboard.topApps || []
    readonly property int totalSeconds: totalDashboard.totalSec || dashboard.totalSec || 0
    readonly property int activeDays: totalDashboard.activeDays || dashboard.activeDays || 0
    readonly property int totalHours: Math.floor(totalSeconds / 3600)

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
            totalDashboard = emptyDashboard()
            return
        }
        dashboard = mobileUsageService.getDashboardForRange("day")
        totalDashboard = mobileUsageService.getDashboardForRange("all")
    }

    function requestSync() {
        if (hasMobileUsageService())
            mobileUsageService.requestImmediateSync()
    }

    function openUsageAccess() {
        if (hasMobileUsageService())
            mobileUsageService.openUsageAccessSettings()
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

    function rankText(index) {
        var n = index + 1
        return n < 10 ? "0" + n : "" + n
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
            GradientStop { position: 0.00; color: "#08223A" }
            GradientStop { position: 0.45; color: "#0B2231" }
            GradientStop { position: 1.00; color: "#07131F" }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * 0.58
        color: "transparent"
        opacity: 0.35
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2A6B9A" }
            GradientStop { position: 1.0; color: "#00203300" }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentHeight: content.implicitHeight + 22

        Column {
            id: content
            width: flick.width
            spacing: 0

            MobileStatusBar {
                width: parent.width
                theme: root.theme
            }

            Item {
                width: parent.width
                height: Math.max(500, flick.height * 0.74)

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.topMargin: 12
                    height: 44

                    Text {
                        width: 44
                        height: parent.height
                        text: "☰"
                        color: "#F5FAFF"
                        font.pixelSize: 30
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: parent.width - 132
                        height: parent.height
                        text: "TimeArc"
                        color: "#BFD3E5"
                        opacity: 0.78
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 44
                        height: parent.height
                        text: "↻"
                        color: "#F5FAFF"
                        font.pixelSize: 25
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.requestSync()
                        }
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 92
                    width: parent.width - 44
                    spacing: 14

                    Rectangle {
                        width: 104
                        height: 104
                        radius: 52
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#F5FAFF"
                        border.color: "#DCEBFF"
                        border.width: 3
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#214B69" }
                                GradientStop { position: 1.0; color: "#0D1724" }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "T"
                            color: "#EAF8FF"
                            font.pixelSize: 48
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        width: parent.width
                        text: "TimeArc Mobile"
                        color: "#FFFFFF"
                        font.pixelSize: 31
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: "使用 TimeArc " + root.activeDays + " 天 · 累计 " + root.totalHours + " 小时"
                        color: "#D2DFEA"
                        opacity: 0.86
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Row {
                        width: parent.width
                        height: 58
                        spacing: 0

                        ProfileMetric {
                            width: parent.width / 3
                            value: root.dashboard.totalText || "0s"
                            label: "今日"
                        }

                        ProfileMetric {
                            width: parent.width / 3
                            value: "" + (root.totalDashboard.appCount || root.dashboard.appCount || 0)
                            label: "应用"
                        }

                        ProfileMetric {
                            width: parent.width / 3
                            value: root.totalDashboard.averageDailyText || "0s"
                            label: "日均"
                        }
                    }

                    Row {
                        width: parent.width
                        height: 48
                        spacing: 10

                        HeroAction {
                            width: (parent.width - 30) / 4
                            label: "最近"
                            value: "今日"
                        }
                        HeroAction {
                            width: (parent.width - 30) / 4
                            label: "同步"
                            value: root.hasMobileUsageService() ? "立即" : "预览"
                            onClicked: root.requestSync()
                        }
                        HeroAction {
                            width: (parent.width - 30) / 4
                            label: "权限"
                            value: root.hasMobileUsageService() && mobileUsageService.usageAccessGranted ? "已开" : "设置"
                            onClicked: root.openUsageAccess()
                        }
                        HeroAction {
                            width: (parent.width - 30) / 4
                            label: "本地"
                            value: "SQLite"
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    text: "下滑查看应用排行"
                    color: "#B7CAD8"
                    opacity: 0.72
                    font.pixelSize: 12
                }
            }

            Column {
                width: parent.width - 40
                x: 20
                spacing: 14

                Row {
                    width: parent.width
                    height: 36

                    Text {
                        width: parent.width - 94
                        text: "使用排行"
                        color: "#FFFFFF"
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 94
                        text: "今日"
                        color: "#B7CAD8"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    width: parent.width
                    visible: root.topApps.length === 0
                    text: "还没有安卓使用数据。开启 Usage Access 后，TimeArc 会在你打开 App 时读取系统使用时长并写入数据库。"
                    color: "#B7CAD8"
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    lineHeight: 1.35
                }

                Repeater {
                    model: root.topApps

                    RankRow {
                        width: parent.width
                        app: modelData
                        rank: root.rankText(index)
                        theme: root.theme
                        iconUrl: root.iconSource(modelData.appIconPath)
                    }
                }
            }
        }
    }

    component ProfileMetric: Column {
        property string value: ""
        property string label: ""

        spacing: 4

        Text {
            width: parent.width
            text: value
            color: "#FFFFFF"
            font.pixelSize: 20
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: label
            color: "#C3D4E3"
            opacity: 0.80
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }

    component HeroAction: Rectangle {
        id: action

        property string label: ""
        property string value: ""
        signal clicked()

        height: 46
        radius: 12
        color: "#3B5872AA"
        border.color: "#70B7D433"
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                width: action.width - 8
                text: label
                color: "#F4FAFF"
                font.pixelSize: 13
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                width: action.width - 8
                text: value
                color: "#D0E0EC"
                opacity: 0.78
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    component RankRow: Rectangle {
        required property var theme
        property var app: ({})
        property string rank: "01"
        property string iconUrl: ""

        height: 76
        radius: 18
        color: "#172334CC"
        border.color: "#FFFFFF14"
        border.width: 1

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                width: 48
                height: 48
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: "#243246"
                clip: true

                Image {
                    id: appImage
                    anchors.fill: parent
                    anchors.margins: 5
                    source: iconUrl
                    visible: iconUrl.length > 0 && status !== Image.Error
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appImage.visible
                    text: app.initial || "?"
                    color: "#DDF8FF"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width - 148
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    width: parent.width
                    text: app.displayName || app.packageName || "未知应用"
                    color: "#FFFFFF"
                    font.pixelSize: 16
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

            Column {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: app.durationText || "0s"
                    color: "#EAF8FF"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: rank
                    color: "#8FA4B7"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
