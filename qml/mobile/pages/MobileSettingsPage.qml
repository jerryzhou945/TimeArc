import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    signal darkModeChanged(bool enabled)

    color: theme.bg

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
        color: root.theme.bg
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
            contentHeight: content.implicitHeight + 24

            Column {
                id: content
                width: flick.width - 40
                x: 20
                spacing: 14

                Rectangle {
                    width: parent.width
                    height: 156
                    radius: 24
                    color: root.theme.card
                    border.color: root.theme.borderSoft
                    border.width: 1
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 78
                        color: root.theme.accentSoft
                        opacity: root.theme.isDark ? 0.22 : 0.82
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        Rectangle {
                            width: 68
                            height: 68
                            radius: 34
                            color: root.theme.cardElevated
                            border.color: root.theme.border
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "T"
                                color: root.theme.accentText
                                font.pixelSize: 33
                                font.weight: Font.Bold
                            }
                        }

                        Column {
                            width: parent.width - 82
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                width: parent.width
                                text: "TimeArc Mobile"
                                color: root.theme.textPrimary
                                font.pixelSize: 23
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: "记录 " + (root.totalDashboard.activeDays || 0) + " 天 · 累计 " + (root.totalDashboard.totalText || "0s")
                                color: root.theme.textSecondary
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.usageStatusText()
                                color: root.theme.accentText
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
                        theme: root.theme
                        label: "权限"
                        value: root.usageAccessText()
                    }

                    StatusTile {
                        width: (parent.width - 20) / 3
                        theme: root.theme
                        label: "数据库"
                        value: "SQLite"
                    }

                    StatusTile {
                        width: (parent.width - 20) / 3
                        theme: root.theme
                        label: "应用"
                        value: "" + (root.totalDashboard.appCount || 0)
                    }
                }

                SettingsGroup {
                    width: parent.width
                    theme: root.theme
                    title: "安卓使用数据"
                    rows: [
                        { "label": "使用情况访问权限", "desc": "打开系统 Usage Access 授权页", "value": root.usageAccessText(), "action": "usageAccess" },
                        { "label": "立即同步", "desc": "读取系统记录并写入 TimeArc 数据库", "value": root.usageStatusText(), "action": "syncNow" },
                        { "label": "前台打开自动同步", "desc": "进入 TimeArc 时补读最近使用情况", "switchKey": "autoSync" }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    theme: root.theme
                    title: "呈现与隐私"
                    rows: [
                        { "label": "跨设备合并", "desc": "后续与桌面端累计计算后统一展示", "switchKey": "mergeDevices" },
                        { "label": "桌面标题脱敏", "desc": "安卓端为应用级，桌面端标题级可隐藏", "switchKey": "hideDesktopTitles" },
                        { "label": "数据精度", "desc": "安卓 UsageStats 提供应用级时长", "value": "应用级" }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    theme: root.theme
                    title: "外观"
                    rows: [
                        { "label": "白色模式", "desc": "切换为冷白背景与深色文字", "switchKey": "lightMode" },
                        { "label": "主页样式", "desc": "应用卡牌 + 下滑排行", "value": "卡牌" }
                    ]
                }

                Text {
                    width: parent.width
                    text: "TimeArc · Android UsageStats · 本地优先"
                    color: root.theme.textMuted
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
        if (key === "lightMode")
            return !theme.isDark
        return false
    }

    function setChecked(key, value) {
        if (key === "autoSync")
            autoSync = value
        else if (key === "mergeDevices")
            mergeDevices = value
        else if (key === "hideDesktopTitles")
            hideDesktopTitles = value
        else if (key === "lightMode")
            darkModeChanged(!value)
    }

    function runAction(action) {
        if (action === "usageAccess")
            openUsageAccess()
        else if (action === "syncNow")
            syncNow()
    }

    component StatusTile: Rectangle {
        required property var theme
        property string label: ""
        property string value: ""

        radius: 18
        color: theme.card
        border.color: theme.borderSoft
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                width: parent.width
                text: label
                color: theme.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: value
                color: theme.textPrimary
                font.family: theme.numberFontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    component SettingsGroup: Column {
        id: group

        required property var theme
        property string title: ""
        property var rows: []

        spacing: 8

        Text {
            width: parent.width
            text: group.title
            color: group.theme.textPrimary
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Rectangle {
            width: parent.width
            height: rowsColumn.implicitHeight
            radius: 20
            color: group.theme.card
            border.color: group.theme.borderSoft
            border.width: 1

            Column {
                id: rowsColumn
                width: parent.width

                Repeater {
                    model: group.rows

                    SettingRow {
                        required property var modelData

                        width: rowsColumn.width
                        theme: group.theme
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
        required property var theme
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
                    color: theme.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: desc
                    color: theme.textMuted
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
                color: hasArrow ? theme.textMuted : theme.textSecondary
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
