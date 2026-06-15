import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../components/TagPalette.js" as TagPalette
import "../components/I18n.js" as I18n

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool nightMode: false
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FBF8F4"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"
    property string languageMode: "zh"

    function tr(source) { return I18n.t(languageMode, source) }
    function sentence(key, params, fallback) { return I18n.sentence(languageMode, key, params, fallback) }

    property color textPrimary: themeTextPrimary
    property color textSecondary: themeTextSecondary
    property color panelColor: nightMode ? "#353C55" : "#FBF8F4"
    property color cardColor: nightMode ? "#3E465F" : "#FFFDF9"
    property color cardSoft: nightMode ? "#454D68" : "#F7F3EE"
    property color mint: nightMode ? "#7780B5" : "#CFE8D8"
    property color lightMint: nightMode ? "#596184" : "#DDF1E5"
    property color cream: nightMode ? "#555A78" : "#F4E8C8"
    property color blush: nightMode ? "#65536A" : "#EBC9CF"
    property color borderColor: nightMode ? "#626A90" : "#E8E0D8"
    property color softBorder: nightMode ? "#737BA4" : "#EFE7DE"
    property color shadowColor: nightMode ? "#05070D" : "#BFAE9D"
    property color primaryButton: nightMode ? "#8E93D8" : "#1F1A17"
    property color primaryButtonHover: nightMode ? "#9AA0E7" : "#332C27"

    function formatTime(totalSeconds) {
        var t = totalSeconds
        if (t === undefined || t === null)
            t = 0

        var h = Math.floor(t / 3600)
        var m = Math.floor((t % 3600) / 60)
        var s = t % 60

        function pad(n) {
            var text = n.toString()
            if (text.length < 2)
                text = "0" + text
            return text
        }

        return pad(h) + ":" + pad(m) + ":" + pad(s)
    }

    function secondsToDisplay(seconds) {
        var total = Math.max(0, Math.floor(seconds ? seconds : 0))
        if (total <= 0)
            return "0m"
        if (total < 60)
            return "<1m"

        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        if (h > 0)
            return h + "h " + m + "m"
        return m + "m"
    }

    function recentProjects(maxCount) {
        var list = projectManager ? projectManager.projects : []
        var copy = list ? list.slice() : []
        return copy.length > maxCount ? copy.slice(0, maxCount) : copy
    }

    // 调色板与图标统一委托到 TagPalette.js（单一来源，杜绝多页色表漂移）。
    function tagColor(tag) { return TagPalette.tagColor(tag) }
    function tagIcon(tag) { return TagPalette.tagIcon(tag) }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: panelColor
        opacity: nightMode ? 0.28 : 0.42
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 18

        SoftCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 500
            radius: 34
            padding: 30
            fillColor: cardColor
            fillOpacity: nightMode ? 0.76 : 0.88
            strokeColor: borderColor
            shadowColor: shadowColor
            shadowOpacity: nightMode ? 0.18 : 0.09

            ColumnLayout {
                anchors.fill: parent
                spacing: 22

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52
                        radius: 26
                        color: lightMint

                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                text: root.tr("手动计时")
                            color: textPrimary
                            font.pixelSize: 30
                            font.bold: true
                        }

                        Text {
                text: root.tr("结束后会自动回到首页，并把本次时长累计到项目中。")
                            color: textSecondary
                            font.pixelSize: 14
                        }
                    }

                    SoftPill {
                        title: "状态"
                        value: timerManager ? (timerManager.running ? "进行中" : "已暂停") : "未连接"
                        iconText: timerManager && timerManager.running ? "●" : "Ⅱ"
                        fillColor: timerManager && timerManager.running ? lightMint : cream
                        strokeColor: softBorder
                        accentColor: timerManager && timerManager.running ? mint : blush
                        titleColor: textSecondary
                        valueColor: textPrimary
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    SoftCard {
                        width: Math.min(parent.width, 720)
                        height: Math.min(parent.height, 332)
                        anchors.centerIn: parent
                        radius: 36
                        padding: 28
                        fillColor: nightMode ? "#454D68" : "#FBF8F4"
                        fillOpacity: nightMode ? 0.80 : 0.96
                        strokeColor: softBorder
                        shadowColor: shadowColor
                        shadowOpacity: nightMode ? 0.16 : 0.08

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 18

                            SoftPill {
                                Layout.alignment: Qt.AlignHCenter
                                compact: true
                                title: ""
                                value: timerManager ? (timerManager.currentProject && timerManager.currentProject.length > 0 ? timerManager.currentProject : "未选择项目") : "计时器未连接"
                                iconText: "T"
                                fillColor: nightMode ? "#535B7B" : "#FFFDF9"
                                strokeColor: softBorder
                                accentColor: mint
                                valueColor: textPrimary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: timerManager ? formatTime(timerManager.elapsedSeconds) : "00:00:00"
                                color: textPrimary
                                font.pixelSize: 88
                                font.family: "Segoe UI"
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: timerManager
                                      ? (timerManager.running ? "保持现在的节奏，慢慢推进。" : "已经暂停，可以随时继续。")
                                      : "计时器未连接"
                                color: textSecondary
                                font.pixelSize: 15
                                horizontalAlignment: Text.AlignHCenter
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                SoftButton {
                    text: timerManager && timerManager.running ? root.tr("暂停") : root.tr("继续")
                                    iconText: timerManager && timerManager.running ? "Ⅱ" : "▶"
                                    implicitWidth: 132
                                    implicitHeight: 52
                                    radius: 20
                                    fillColor: nightMode ? "#535B7B" : "#F4E8C8"
                                    hoverColor: nightMode ? "#60698E" : "#EFDCC3"
                                    strokeColor: softBorder
                                    strokeWidth: 1
                                    textColor: textPrimary
                                    fontSize: 16
                                    onClicked: {
                                        if (!timerManager)
                                            return

                                        if (timerManager.running)
                                            timerManager.pauseTimer()
                                        else
                                            timerManager.resumeTimer()
                                    }
                                }

                                SoftButton {
                    text: root.tr("结束")
                                    iconText: "✓"
                                    implicitWidth: 132
                                    implicitHeight: 52
                                    radius: 20
                                    fillColor: primaryButton
                                    hoverColor: primaryButtonHover
                                    textColor: "#FFFDF9"
                                    fontSize: 16
                                    onClicked: {
                                        if (timerManager)
                                            timerManager.stopAndCommit()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        SoftCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 172
            radius: 30
            padding: 20
            fillColor: cardColor
            fillOpacity: nightMode ? 0.74 : 0.86
            strokeColor: borderColor
            shadowColor: shadowColor
            shadowOpacity: nightMode ? 0.16 : 0.08

            ColumnLayout {
                anchors.fill: parent
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                text: root.tr("最近项目")
                        color: textPrimary
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Text {
                text: root.sentence("projectCountPlain", {count: recentProjects(4).length}, recentProjects(4).length + " 个")
                        color: textSecondary
                        font.pixelSize: 13
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: 12
                    clip: true
                    model: recentProjects(8)

                    delegate: Rectangle {
                        required property var modelData

                        width: 220
                        height: ListView.view.height
                        radius: 20
                        color: cardSoft
                        border.width: 1
                        border.color: softBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 19
                                color: tagColor(modelData.tag)

                                Text {
                                    anchors.centerIn: parent
                                    text: tagIcon(modelData.tag)
                                    color: textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: textPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                        text: (modelData.tag ? root.tr(modelData.tag) + " · " : "") + (modelData.time ? modelData.time : "0h 0m")
                                    color: textSecondary
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    footer: Item {
                        width: ListView.view ? ListView.view.width : 0
                        height: ListView.view ? ListView.view.height : 0

                        Text {
                            anchors.centerIn: parent
                            visible: recentProjects(8).length === 0
                    text: root.tr("还没有最近项目")
                            color: textSecondary
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("DesktopTimerPage loaded")
    }
}
