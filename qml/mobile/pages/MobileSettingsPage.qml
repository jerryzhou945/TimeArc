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
                    subtitle: "本地数据与显示"
                }

                SettingsSection {
                    width: parent.width
                    title: "记录"
                    theme: root.theme
                    rows: [
                        { "label": "自动记录", "switchKey": "autoRecord" },
                        { "label": "AFK 空闲检测", "switchKey": "afk" },
                        { "label": "最小记录片段", "value": "1 分钟", "arrow": true }
                    ]
                }

                SettingsSection {
                    width: parent.width
                    title: "隐私"
                    theme: root.theme
                    rows: [
                        { "label": "标题记录", "value": "可按应用关闭", "arrow": true },
                        { "label": "本地优先", "value": "数据保存在本机" }
                    ]
                }

                SettingsSection {
                    width: parent.width
                    title: "应用管理"
                    theme: root.theme
                    rows: [
                        { "label": "应用分类与颜色", "arrow": true },
                        { "label": "排除统计的应用", "arrow": true }
                    ]
                }

                SettingsSection {
                    width: parent.width
                    title: "数据"
                    theme: root.theme
                    rows: [
                        { "label": "导出备份", "arrow": true },
                        { "label": "恢复备份", "arrow": true },
                        { "label": "清理历史记录", "arrow": true }
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
