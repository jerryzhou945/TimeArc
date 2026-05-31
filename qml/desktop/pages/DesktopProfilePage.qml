import QtQuick
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    clip: true

    signal nightModeToggled(bool enabled)

    property bool nightMode: false
    property string languageMode: settingsRepository ? settingsRepository.getValue("language_mode", "zh") : "zh"
    property color themeTextPrimary: nightMode ? "#EAE8F8" : "#4E342E"
    property color themeTextSecondary: nightMode ? "#B8B4D4" : "#9C806C"
    property color themePanelColor: nightMode ? "#2C334A" : "#FFFDF9"
    property color themeBorderColor: nightMode ? "#6D7297" : "#D8C2AC"
    property color themeAccentColor: nightMode ? "#8E93D8" : "#CFE8D8"

    property bool chinese: languageMode !== "en"
    property color surfaceColor: nightMode ? "#343C55" : "#FFFEFC"
    property color rowColor: nightMode ? "#3F4661" : "#F1EAE1"
    property color selectedRowColor: nightMode ? "#505981" : "#D6EBDD"
    property color strongBorderColor: nightMode ? "#858BB2" : "#C9B9A8"
    property color subtleBorderColor: nightMode ? "#697197" : "#DDD0C3"
    property color shadowColor: nightMode ? "#05070D" : "#BFAE9D"

    function textFor(zh, en) {
        return chinese ? zh : en
    }

    function applyThemeMode(mode) {
        var enabled = mode === "dark"
        if (root.nightMode === enabled)
            return
        root.nightMode = enabled
        root.nightModeToggled(enabled)
    }

    function applyLanguage(mode) {
        root.languageMode = mode
        if (settingsRepository)
            settingsRepository.setValue("language_mode", mode)
    }

    component SectionPanel: Rectangle {
        id: panel
        property string title: ""
        property string subtitle: ""
        property int padding: 18
        property int contentHeight: 64
        default property alias content: contentHost.data

        height: implicitHeight
        implicitHeight: padding * 2 + headerBlock.implicitHeight + 14 + contentHeight
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.strongBorderColor
        clip: true

        Rectangle {
            x: 0
            y: 6
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: root.shadowColor
            opacity: root.nightMode ? 0.20 : 0.06
            z: -2
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: root.surfaceColor
            opacity: root.nightMode ? 0.64 : 0.74
            z: -1
        }

        Column {
            anchors.fill: parent
            anchors.margins: panel.padding
            spacing: 14

            Column {
                id: headerBlock
                width: parent.width
                spacing: 4

                Text {
                    width: parent.width
                    text: panel.title
                    color: root.themeTextPrimary
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: panel.subtitle
                    color: root.themeTextSecondary
                    font.pixelSize: 12
                    lineHeight: 1.25
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
            }

            Item {
                id: contentHost
                width: parent.width
                height: panel.contentHeight
            }
        }
    }

    component ChoiceControl: Rectangle {
        id: choice
        property string title: ""
        property string detail: ""
        property string marker: ""
        property bool selected: false
        signal picked()

        height: 62
        radius: 8
        color: selected ? root.selectedRowColor : root.rowColor
        opacity: selected ? 0.96 : (root.nightMode ? 0.66 : 0.94)
        border.width: 1
        border.color: selected ? root.themeAccentColor : root.subtleBorderColor

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: choice.selected ? root.themeAccentColor : "transparent"
                border.width: 1
                border.color: choice.selected ? root.themeAccentColor : root.strongBorderColor
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: choice.marker
                    color: choice.selected && !root.nightMode ? "#2D2724" : root.themeTextPrimary
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            Column {
                width: parent.width - 40
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    width: parent.width
                    text: choice.title
                    color: root.themeTextPrimary
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: choice.detail
                    color: root.themeTextSecondary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.picked()
        }
    }

    component SettingLine: Rectangle {
        id: setting
        property string title: ""
        property string detail: ""
        property string value: ""

        height: 54
        radius: 8
        color: root.rowColor
        opacity: root.nightMode ? 0.62 : 0.94
        border.width: 1
        border.color: root.subtleBorderColor

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: valueLabel.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: setting.title
                color: root.themeTextPrimary
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: setting.detail
                color: root.themeTextSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Text {
            id: valueLabel
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            text: setting.value
            color: root.themeTextPrimary
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    component MetricLine: Rectangle {
        id: metric
        property string title: ""
        property string value: ""
        property string detail: ""

        height: 58
        radius: 8
        color: root.rowColor
        opacity: root.nightMode ? 0.62 : 0.94
        border.width: 1
        border.color: root.subtleBorderColor

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Text {
                width: 98
                text: metric.title
                color: root.themeTextSecondary
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: 120
                text: metric.value
                color: root.themeTextPrimary
                font.pixelSize: 21
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width - 232
                text: metric.detail
                color: root.themeTextSecondary
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: root.nightMode ? "#2C334A" : "#FFFCF7"
            opacity: root.nightMode ? 0.34 : 0.78
            border.width: 2
            border.color: root.strongBorderColor
        }

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Row {
                width: parent.width
                height: 62
                spacing: 14

                Rectangle {
                    width: 42
                    height: 42
                    radius: 10
                    color: root.themeAccentColor
                    opacity: 0.94
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "S"
                        color: root.nightMode ? "#F8F7FF" : "#2D2724"
                        font.pixelSize: 17
                        font.bold: true
                    }
                }

                Column {
                    width: parent.width - 220
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        width: parent.width
                        text: root.textFor("设置", "Settings")
                        color: root.themeTextPrimary
                        font.pixelSize: 30
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        width: parent.width
                        text: root.textFor("外观、语言、个人资料与本地数据，一页完成。", "Appearance, language, profile, and local data in one page.")
                        color: root.themeTextSecondary
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Rectangle {
                    width: 142
                    height: 32
                    radius: 8
                    color: root.rowColor
                    opacity: root.nightMode ? 0.66 : 0.94
                    border.width: 1
                    border.color: root.subtleBorderColor
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.textFor("本地保存", "Saved locally")
                        color: root.themeTextPrimary
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            Flickable {
                width: parent.width
                height: parent.height - 78
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Column {
                    id: contentColumn
                    width: parent.width - 12
                    spacing: 14

                    SectionPanel {
                        width: parent.width
                        contentHeight: 62
                        title: root.textFor("外观", "Appearance")
                        subtitle: root.textFor("选择浅色或深色主题，设置会同步到桌面端全局主题。", "Choose light or dark theme. This syncs with the desktop shell theme.")

                        Row {
                            anchors.fill: parent
                            spacing: 12

                            ChoiceControl {
                                width: (parent.width - 12) / 2
                                title: root.textFor("浅色", "Light")
                                detail: root.textFor("柔和、明亮，适合白天使用", "Soft and bright for daytime work")
                                marker: "L"
                                selected: !root.nightMode
                                onPicked: root.applyThemeMode("light")
                            }

                            ChoiceControl {
                                width: (parent.width - 12) / 2
                                title: root.textFor("深色", "Dark")
                                detail: root.textFor("低亮度玻璃感，适合夜间使用", "Low-light glass style for evenings")
                                marker: "D"
                                selected: root.nightMode
                                onPicked: root.applyThemeMode("dark")
                            }
                        }
                    }

                    SectionPanel {
                        width: parent.width
                        contentHeight: 62
                        title: root.textFor("语言", "Language")
                        subtitle: root.textFor("选择设置页显示语言。后续页面接入翻译后会沿用这个偏好。", "Choose the settings page language. Other pages can reuse this preference later.")

                        Row {
                            anchors.fill: parent
                            spacing: 12

                            ChoiceControl {
                                width: (parent.width - 12) / 2
                                title: "中文"
                                detail: "TimeArc 当前默认语言"
                                marker: "中"
                                selected: root.languageMode !== "en"
                                onPicked: root.applyLanguage("zh")
                            }

                            ChoiceControl {
                                width: (parent.width - 12) / 2
                                title: "English"
                                detail: "Settings page display language"
                                marker: "EN"
                                selected: root.languageMode === "en"
                                onPicked: root.applyLanguage("en")
                            }
                        }
                    }

                    SectionPanel {
                        width: parent.width
                        contentHeight: 118
                        title: root.textFor("个人资料", "Profile")
                        subtitle: root.textFor("本地身份信息，不包含账号或云端同步。", "Local identity only. No account or cloud sync.")

                        Column {
                            anchors.fill: parent
                            spacing: 10

                            SettingLine {
                                width: parent.width
                                title: root.textFor("昵称", "Name")
                                detail: root.textFor("显示在我的页面", "Shown on the profile page")
                                value: "Chen"
                            }

                            SettingLine {
                                width: parent.width
                                title: root.textFor("身份", "Role")
                                detail: root.textFor("当前本机用户", "Current local user")
                                value: root.textFor("TimeArc 用户", "TimeArc user")
                            }
                        }
                    }

                    SectionPanel {
                        width: parent.width
                        contentHeight: 126
                        title: root.textFor("使用概览", "Usage Overview")
                        subtitle: root.textFor("手动计时数据仍来自本地项目统计。", "Manual timer data still comes from local project stats.")

                        Column {
                            anchors.fill: parent
                            spacing: 10

                            MetricLine {
                                width: parent.width
                                title: root.textFor("今日项目", "Today")
                                value: projectManager ? (projectManager.todayProjectMinutes + " m") : "0 m"
                                detail: root.textFor("今日累计手动计时", "Manual time tracked today")
                            }

                            MetricLine {
                                width: parent.width
                                title: root.textFor("本月项目", "This Month")
                                value: projectManager ? (projectManager.monthProjectMinutes + " m") : "0 m"
                                detail: root.textFor("本月累计手动计时", "Manual time tracked this month")
                            }
                        }
                    }

                    SectionPanel {
                        width: parent.width
                        contentHeight: 92
                        title: root.textFor("数据位置", "Data Location")
                        subtitle: root.textFor("只读信息：当前本机 TimeArc SQLite 数据库文件位置。", "Read-only: current local TimeArc SQLite database path.")

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: root.rowColor
                            opacity: root.nightMode ? 0.62 : 0.94
                            border.width: 1
                            border.color: root.subtleBorderColor

                            Text {
                                anchors.fill: parent
                                anchors.margins: 13
                                text: databaseManager ? databaseManager.getDatabasePath() : root.textFor("未连接到本地 SQLite 数据库", "Local SQLite database is not connected")
                                color: root.themeTextPrimary
                                font.pixelSize: 12
                                lineHeight: 1.25
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
            }
        }
    }
}
