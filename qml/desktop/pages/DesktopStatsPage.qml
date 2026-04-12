import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent
    clip: true

    // ===== 从 AppShell 传入主题 =====
    property bool nightMode: false
    property color themeTextPrimary: "#4E342E"
    property color themeTextSecondary: "#9C806C"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#DDC9B5"
    property color themeAccentColor: "#E8C6A3"

    property color textPrimary: themeTextPrimary
    property color textSecondary: themeTextSecondary
    property color borderColor: themeBorderColor
    property color accentColor: themeAccentColor

    // 白底/奶茶底，更容易看清
    property color panelGlass: nightMode ? "#505675" : "#FFFDF9"
    property real panelOpacity: nightMode ? 0.52 : 0.50

    property color cardGlass: nightMode ? "#59607F" : "#FFFDF9"
    property real cardOpacity: nightMode ? 0.48 : 0.44

    property color softBorder: nightMode ? "#757CA6" : "#E6D6C5"
    property color progressBg: nightMode ? "#6B7398" : "#E9DED1"
    property color strongText: nightMode ? "#D9D8FF" : "#A96F46"

    // 0=今日 1=本月 2=本年 3=全部
    property int selectedRange: 3

    function rangeKey() {
        if (selectedRange === 0) return "day"
        if (selectedRange === 1) return "month"
        if (selectedRange === 2) return "year"
        return "all"
    }

    function rangeText() {
        if (selectedRange === 0) return "今日"
        if (selectedRange === 1) return "本月"
        if (selectedRange === 2) return "本年"
        return "全部"
    }

    function minutesToDisplay(minutes) {
        var total = Math.max(0, Math.floor(minutes))
        var h = Math.floor(total / 60)
        var m = total % 60
        return h + "h " + m + "m"
    }

    function projectMinutesForCurrentRange() {
        if (!projectManager)
            return 0

        if (selectedRange === 0)
            return projectManager.todayProjectMinutes
        if (selectedRange === 1)
            return projectManager.monthProjectMinutes
        if (selectedRange === 2)
            return projectManager.yearProjectMinutes
        return projectManager.allProjectMinutes
    }

    function tagColor(tag) {
        if (tag === "学习") return "#B7A6F0"
        if (tag === "工作") return "#D7B79A"
        if (tag === "运动") return "#B4C986"
        if (tag === "娱乐") return "#DFA65F"
        if (tag === "阅读") return "#A9BFE6"
        if (tag === "社交") return "#C7ADD9"
        if (tag === "生活") return "#E2B6C3"
        return "#B7AEA6"
    }

    function projectColor(tag) {
        return tagColor(tag)
    }

    function currentProjects() {
        if (!projectManager)
            return []

        var raw = projectManager.projectsForRange(rangeKey())
        var filtered = []

        for (var i = 0; i < raw.length; i++) {
            var sec = raw[i].seconds ? raw[i].seconds : 0
            if (sec > 0)
                filtered.push(raw[i])
        }

        filtered.sort(function(a, b) {
            var aSec = a.seconds ? a.seconds : 0
            var bSec = b.seconds ? b.seconds : 0
            return bSec - aSec
        })

        return filtered
    }

    function maxProjectSeconds() {
        var list = currentProjects()
        if (!list || list.length === 0)
            return 1
        return list[0].seconds ? list[0].seconds : 1
    }

    // ===== 软件使用时长：先占位，后面接 Windows 自动统计 =====
    property var softwareStatsDay: [
        { name: "微信", minutes: 45, note: "自动记录" },
        { name: "Chrome", minutes: 38, note: "自动记录" },
        { name: "VS Code", minutes: 72, note: "自动记录" },
        { name: "QQ音乐", minutes: 21, note: "自动记录" }
    ]

    property var softwareStatsMonth: [
        { name: "微信", minutes: 420, note: "自动记录" },
        { name: "Chrome", minutes: 580, note: "自动记录" },
        { name: "VS Code", minutes: 910, note: "自动记录" },
        { name: "QQ音乐", minutes: 260, note: "自动记录" },
        { name: "Steam", minutes: 190, note: "自动记录" }
    ]

    property var softwareStatsYear: [
        { name: "微信", minutes: 2100, note: "自动记录" },
        { name: "Chrome", minutes: 3460, note: "自动记录" },
        { name: "VS Code", minutes: 4880, note: "自动记录" },
        { name: "QQ音乐", minutes: 1620, note: "自动记录" },
        { name: "Steam", minutes: 1330, note: "自动记录" }
    ]

    property var softwareStatsAll: [
        { name: "微信", minutes: 2350, note: "自动记录" },
        { name: "Chrome", minutes: 3910, note: "自动记录" },
        { name: "VS Code", minutes: 5320, note: "自动记录" },
        { name: "QQ音乐", minutes: 1740, note: "自动记录" },
        { name: "Steam", minutes: 1490, note: "自动记录" }
    ]

    function currentSoftwareStats() {
        if (selectedRange === 0) return softwareStatsDay
        if (selectedRange === 1) return softwareStatsMonth
        if (selectedRange === 2) return softwareStatsYear
        return softwareStatsAll
    }

    function totalSoftwareMinutes() {
        var list = currentSoftwareStats()
        var total = 0
        for (var i = 0; i < list.length; i++)
            total += list[i].minutes
        return total
    }

    function maxSoftwareMinutes() {
        var list = currentSoftwareStats()
        if (!list || list.length === 0)
            return 1

        var sorted = list.slice()
        sorted.sort(function(a, b) { return b.minutes - a.minutes })
        return sorted[0].minutes > 0 ? sorted[0].minutes : 1
    }

    function currentSoftwareStatsSorted() {
        var list = currentSoftwareStats().slice()
        list.sort(function(a, b) {
            return b.minutes - a.minutes
        })
        return list
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 6
        clip: true

        Column {
            id: pageColumn
            width: root.width - 24
            spacing: 18

            // ===== 顶部标题 =====
            Rectangle {
                width: parent.width
                height: 112
                radius: 28
                color: "transparent"
                border.width: 2
                border.color: borderColor
                clip: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 27
                    color: panelGlass
                    opacity: panelOpacity
                    z: -1
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "时间统计"
                        color: textPrimary
                        font.pixelSize: 34
                        font.bold: true
                    }

                    Text {
                        text: "查看软件使用时长与自定义项目时长"
                        color: textSecondary
                        font.pixelSize: 15
                    }
                }

                Rectangle {
                    width: 110
                    height: 42
                    radius: 16
                    color: nightMode ? "#626A95" : "#EFE1D0"
                    opacity: 0.94
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: rangeText()
                        color: textPrimary
                        font.pixelSize: 15
                        font.bold: true
                    }
                }
            }

            // ===== 时间范围切换 =====
            Rectangle {
                width: parent.width
                height: 76
                radius: 24
                color: "transparent"
                border.width: 2
                border.color: borderColor
                clip: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 23
                    color: panelGlass
                    opacity: panelOpacity
                    z: -1
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    Repeater {
                        model: ["今日", "本月", "本年", "全部"]

                        delegate: Rectangle {
                            required property int index
                            required property string modelData

                            width: 100
                            height: 42
                            radius: 14
                            color: root.selectedRange === index
                                   ? (nightMode ? "#8E93D8" : "#E8C6A3")
                                   : (nightMode ? "#5B6185" : "#F4ECE2")
                            opacity: root.selectedRange === index ? 0.96 : 0.86
                            border.width: 1
                            border.color: root.selectedRange === index
                                          ? (nightMode ? "#757ED0" : "#DBB18A")
                                          : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.selectedRange === index
                                       ? (nightMode ? "#F8F7FF" : "#6A4C3B")
                                       : textPrimary
                                font.pixelSize: 14
                                font.bold: root.selectedRange === index
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedRange = index
                            }
                        }
                    }
                }
            }

            // ===== 概览 =====
            Row {
                width: parent.width
                spacing: 18

                Rectangle {
                    width: (parent.width - 36) / 3
                    height: 132
                    radius: 24
                    color: "transparent"
                    border.width: 2
                    border.color: borderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 23
                        color: panelGlass
                        opacity: panelOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: "总时长"
                            color: textSecondary
                            font.pixelSize: 15
                        }

                        Text {
                            text: minutesToDisplay(totalSoftwareMinutes() + projectMinutesForCurrentRange())
                            color: textPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: rangeText() + "视图"
                            color: strongText
                            font.pixelSize: 13
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 36) / 3
                    height: 132
                    radius: 24
                    color: "transparent"
                    border.width: 2
                    border.color: borderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 23
                        color: panelGlass
                        opacity: panelOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: "软件使用"
                            color: textSecondary
                            font.pixelSize: 15
                        }

                        Text {
                            text: minutesToDisplay(totalSoftwareMinutes())
                            color: textPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: "自动记录"
                            color: strongText
                            font.pixelSize: 13
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 36) / 3
                    height: 132
                    radius: 24
                    color: "transparent"
                    border.width: 2
                    border.color: borderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 23
                        color: panelGlass
                        opacity: panelOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: "自定义项目"
                            color: textSecondary
                            font.pixelSize: 15
                        }

                        Text {
                            text: minutesToDisplay(projectMinutesForCurrentRange())
                            color: textPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: "手动计时"
                            color: strongText
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // ===== 左右双栏 =====
            Row {
                width: parent.width
                spacing: 18

                // 软件
                Rectangle {
                    width: (parent.width - 18) / 2
                    height: 490
                    radius: 30
                    color: "transparent"
                    border.width: 2
                    border.color: borderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 29
                        color: panelGlass
                        opacity: panelOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        Text {
                            text: rangeText() + "软件使用时长"
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            text: "按使用量查看各软件时长"
                            color: textSecondary
                            font.pixelSize: 14
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 76
                            clip: true
                            spacing: 12
                            model: currentSoftwareStatsSorted()

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 82
                                radius: 20
                                color: "transparent"
                                border.width: 1
                                border.color: softBorder
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 19
                                    color: cardGlass
                                    opacity: cardOpacity
                                    z: -1
                                }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    Row {
                                        width: parent.width

                                        Text {
                                            text: modelData.name
                                            color: textPrimary
                                            font.pixelSize: 17
                                            font.bold: true
                                            width: parent.width * 0.55
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: minutesToDisplay(modelData.minutes)
                                            color: strongText
                                            font.pixelSize: 15
                                            font.bold: true
                                            anchors.right: parent.right
                                        }
                                    }

                                    Text {
                                        text: modelData.note
                                        color: textSecondary
                                        font.pixelSize: 12
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: progressBg
                                        opacity: 0.92
                                        clip: true

                                        Rectangle {
                                            width: parent.width * modelData.minutes / maxSoftwareMinutes()
                                            height: parent.height
                                            radius: 4
                                            color: accentColor
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 手动项目
                Rectangle {
                    width: (parent.width - 18) / 2
                    height: 540
                    radius: 30
                    color: "transparent"
                    border.width: 2
                    border.color: borderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 29
                        color: panelGlass
                        opacity: panelOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        Text {
                            text: rangeText() + "自定义项目时长"
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            text: "来自你的手动计时记录"
                            color: textSecondary
                            font.pixelSize: 14
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 76
                            clip: true
                            spacing: 12
                            model: currentProjects()

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 112
                                radius: 20
                                color: "transparent"
                                border.width: 1
                                border.color: softBorder
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 19
                                    color: cardGlass
                                    opacity: cardOpacity
                                    z: -1
                                }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    Text {
                                        text: modelData.name ? modelData.name : "未命名项目"
                                        color: textPrimary
                                        font.pixelSize: 17
                                        font.bold: true
                                        width: parent.width
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 10

                                        Text {
                                            text: modelData.time ? modelData.time : "0h 0m"
                                            color: strongText
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: progressBg
                                        opacity: 0.92
                                        clip: true

                                        Rectangle {
                                            width: parent.width * ((modelData.seconds ? modelData.seconds : 0) / Math.max(1, maxProjectSeconds()))
                                            height: parent.height
                                            radius: 4
                                            color: projectColor(modelData.tag)
                                        }
                                    }
                                }
                            }

                            footer: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: currentProjects().length === 0 ? 120 : 0

                                Text {
                                    anchors.centerIn: parent
                                    visible: currentProjects().length === 0
                                    text: "这个时间范围里还没有项目记录"
                                    color: textSecondary
                                    font.pixelSize: 15
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 8
            }
        }
    }
}
