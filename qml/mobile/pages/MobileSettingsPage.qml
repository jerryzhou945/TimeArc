import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    signal darkModeChanged(bool enabled)

    color: theme.bg

    property bool autoRecord: true
    property bool afk: true
    property bool quietBlue: true

    function usageStatusText() {
        if (typeof mobileUsageService === "undefined" || !mobileUsageService)
            return "服务未连接"
        return mobileUsageService.syncStatusText
    }

    function runAction(action) {
        if (typeof mobileUsageService === "undefined" || !mobileUsageService)
            return
        if (action === "usageAccess")
            mobileUsageService.openUsageAccessSettings()
        else if (action === "syncNow")
            mobileUsageService.requestImmediateSync()
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
                spacing: 16

                MobileSectionTitle {
                    width: parent.width
                    theme: root.theme
                    title: "设置"
                    subtitle: "本地数据与 Android 使用统计"
                }

                SettingsSection {
                    width: parent.width
                    title: "Android 使用记录"
                    theme: root.theme
                    rows: [
                        { "label": "Usage Access 权限", "value": root.usageStatusText(), "arrow": true, "action": "usageAccess" },
                        { "label": "立即同步使用时长", "value": "读取系统记录", "arrow": true, "action": "syncNow" },
                        { "label": "自动同步", "switchKey": "autoRecord" }
                    ]
                }

                SettingsSection {
                    width: parent.width
                    title: "桌面端记录"
                    theme: root.theme
                    rows: [
                        { "label": "AFK 空闲检测", "switchKey": "afk" },
                        { "label": "最小记录片段", "value": "1 分钟", "arrow": true }
                    ]
                }

                SettingsSection {
                    width: parent.width
                    title: "隐私"
                    theme: root.theme
                    rows: [
                        { "label": "标题记录", "value": "桌面端按应用管理", "arrow": true },
                        { "label": "本地优先", "value": "SQLite 数据库" }
                    ]
                }

                SettingsSection {
                    width: parent.width
                    title: "外观"
                    theme: root.theme
                    rows: [
                        { "label": "深色模式", "switchKey": "darkMode" },
                        { "label": "安静蓝主题", "switchKey": "quietBlue" }
                    ]
                }

                Text {
                    width: parent.width
                    text: "TimeArc · 本地版本 1.0.0"
                    color: root.theme.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    function checkedFor(key) {
        if (key === "autoRecord")
            return autoRecord
        if (key === "afk")
            return afk
        if (key === "quietBlue")
            return quietBlue
        if (key === "darkMode")
            return theme.isDark
        return false
    }

    function setChecked(key, value) {
        if (key === "autoRecord")
            autoRecord = value
        else if (key === "afk")
            afk = value
        else if (key === "quietBlue")
            quietBlue = value
        else if (key === "darkMode")
            darkModeChanged(value)
    }

    component SettingsSection: Column {
        id: section

        required property var theme
        property string title: ""
        property var rows: []

        spacing: 4

        Text {
            width: parent.width - 8
            x: 4
            text: section.title
            color: section.theme.textMuted
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.5
        }

        Rectangle {
            width: parent.width
            height: rowsColumn.implicitHeight
            radius: 18
            color: section.theme.card
            border.color: section.theme.border
            border.width: 1

            Column {
                id: rowsColumn
                width: parent.width - 32
                x: 16

                Repeater {
                    model: section.rows

                    Column {
                        width: rowsColumn.width

                        MobileSettingRow {
                            width: parent.width
                            theme: section.theme
                            label: modelData.label
                            value: modelData.value || ""
                            hasArrow: modelData.arrow === true
                            hasSwitch: !!modelData.switchKey
                            checked: root.checkedFor(modelData.switchKey || "")
                            onSwitchToggled: function(v) {
                                root.setChecked(modelData.switchKey, v)
                            }
                            onClicked: root.runAction(modelData.action || "")
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: section.theme.border
                            opacity: index < section.rows.length - 1 ? 0.5 : 0
                        }
                    }
                }
            }
        }
    }
}
