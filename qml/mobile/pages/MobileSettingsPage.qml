import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    signal darkModeChanged(bool enabled)

    color: "#07131F"

    property bool autoSync: true
    property bool mergeDevices: true
    property bool hideDesktopTitles: true
    property var totalDashboard: emptyDashboard()

    function emptyDashboard() {
        return {
            "totalSec": 0,
            "totalText": "0s",
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
            totalDashboard = emptyDashboard()
            return
        }
        totalDashboard = mobileUsageService.getDashboardForRange("all")
    }

    function usageStatusText() {
        if (!hasMobileUsageService())
            return "预览模式"
        return mobileUsageService.syncStatusText
    }

    function usageAccessText() {
        if (!hasMobileUsageService())
            return "仅安卓设备可授权"
        return mobileUsageService.usageAccessGranted ? "已开启" : "需要授权"
    }

    function openUsageAccess() {
        if (hasMobileUsageService())
            mobileUsageService.openUsageAccessSettings()
    }

    function syncNow() {
        if (hasMobileUsageService())
            mobileUsageService.requestImmediateSync()
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

                Rectangle {
                    width: parent.width
                    height: 168
                    radius: 24
                    color: "#132538DD"
                    border.color: "#FFFFFF18"
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        Rectangle {
                            width: 72
                            height: 72
                            radius: 36
                            color: "#EAF8FF"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "T"
                                color: "#0B1C2B"
                                font.pixelSize: 36
                                font.weight: Font.Bold
                            }
                        }

                        Column {
                            width: parent.width - 86
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                width: parent.width
                                text: "TimeArc Mobile"
                                color: "#FFFFFF"
                                font.pixelSize: 24
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: "记录 " + (root.totalDashboard.activeDays || 0) + " 天 · 累计 " + (root.totalDashboard.totalText || "0s")
                                color: "#B8CAD8"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.usageStatusText()
                                color: "#8DE8F2"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 76
                    spacing: 10

                    StatusTile {
                        width: (parent.width - 20) / 3
                        label: "权限"
                        value: root.usageAccessText()
                    }

                    StatusTile {
                        width: (parent.width - 20) / 3
                        label: "数据库"
                        value: "SQLite"
                    }

                    StatusTile {
                        width: (parent.width - 20) / 3
                        label: "应用"
                        value: "" + (root.totalDashboard.appCount || 0)
                    }
                }

                SettingsGroup {
                    width: parent.width
                    title: "安卓使用数据"
                    rows: [
                        { "label": "使用情况访问权限", "desc": "打开系统 Usage Access 授权页", "value": root.usageAccessText(), "action": "usageAccess" },
                        { "label": "立即同步", "desc": "读取系统记录并写入 TimeArc 数据库", "value": root.usageStatusText(), "action": "syncNow" },
                        { "label": "前台打开自动同步", "desc": "进入 TimeArc 时补读最近使用情况", "switchKey": "autoSync" }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    title: "呈现与隐私"
                    rows: [
                        { "label": "跨设备合并", "desc": "后续与桌面端累计计算后统一展示", "switchKey": "mergeDevices" },
                        { "label": "桌面标题脱敏", "desc": "安卓端为应用级，桌面端标题级可隐藏", "switchKey": "hideDesktopTitles" },
                        { "label": "数据精度", "desc": "安卓 UsageStats 提供应用级时长", "value": "应用级" }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    title: "外观"
                    rows: [
                        { "label": "深色模式", "desc": "移动端沉浸背景与高对比文字", "switchKey": "darkMode" },
                        { "label": "主页样式", "desc": "个人页 + 使用排行", "value": "移动端" }
                    ]
                }

                Text {
                    width: parent.width
                    text: "TimeArc · Android UsageStats · 本地优先"
                    color: "#8FA4B7"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 4
                }
            }
        }
    }

    function checkedFor(key) {
        if (key === "autoSync")
            return autoSync
        if (key === "mergeDevices")
            return mergeDevices
        if (key === "hideDesktopTitles")
            return hideDesktopTitles
        if (key === "darkMode")
            return theme.isDark
        return false
    }

    function setChecked(key, value) {
        if (key === "autoSync")
            autoSync = value
        else if (key === "mergeDevices")
            mergeDevices = value
        else if (key === "hideDesktopTitles")
            hideDesktopTitles = value
        else if (key === "darkMode")
            darkModeChanged(value)
    }

    function runAction(action) {
        if (action === "usageAccess")
            openUsageAccess()
        else if (action === "syncNow")
            syncNow()
    }

    component StatusTile: Rectangle {
        property string label: ""
        property string value: ""

        radius: 18
        color: "#142235DD"
        border.color: "#FFFFFF12"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                width: parent.width
                text: label
                color: "#8FA4B7"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: value
                color: "#FFFFFF"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    component SettingsGroup: Column {
        id: group

        property string title: ""
        property var rows: []

        spacing: 8

        Text {
            width: parent.width
            text: group.title
            color: "#FFFFFF"
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Rectangle {
            width: parent.width
            height: rowsColumn.implicitHeight
            radius: 20
            color: "#101B29DD"
            border.color: "#FFFFFF14"
            border.width: 1

            Column {
                id: rowsColumn
                width: parent.width

                Repeater {
                    model: group.rows

                    SettingRow {
                        width: rowsColumn.width
                        label: modelData.label
                        desc: modelData.desc
                        value: modelData.value || ""
                        switchKey: modelData.switchKey || ""
                        checked: root.checkedFor(modelData.switchKey || "")
                        hasArrow: !!modelData.action
                        onClicked: root.runAction(modelData.action || "")
                        onSwitchToggled: function(v) {
                            root.setChecked(modelData.switchKey || "", v)
                        }
                    }
                }
            }
        }
    }

    component SettingRow: Item {
        property string label: ""
        property string desc: ""
        property string value: ""
        property string switchKey: ""
        property bool checked: false
        property bool hasArrow: false

        signal clicked()
        signal switchToggled(bool value)

        height: 66

        Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Column {
                width: parent.width - (switchKey.length > 0 ? 70 : 94)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    width: parent.width
                    text: label
                    color: "#FFFFFF"
                    font.pixelSize: 14
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

            MobileSwitch {
                visible: switchKey.length > 0
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                checked: parent.parent.checked
                onToggled: function(v) {
                    parent.parent.switchToggled(v)
                }
            }

            Text {
                visible: switchKey.length === 0
                width: 82
                anchors.verticalCenter: parent.verticalCenter
                text: hasArrow ? "›" : value
                color: hasArrow ? "#8FA4B7" : "#D7E6F0"
                font.pixelSize: hasArrow ? 24 : 12
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: switchKey.length === 0 || hasArrow
            onClicked: parent.clicked()
        }
    }
}
