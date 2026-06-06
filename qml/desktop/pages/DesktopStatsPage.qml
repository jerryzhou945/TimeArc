import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../components/AppVisual.js" as AppVisual
import "../components/TagPalette.js" as TagPalette

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

    property color textPrimary: themeTextPrimary
    property color textSecondary: themeTextSecondary
    property color panelColor: nightMode ? "#353C55" : "#FBF8F4"
    property color cardColor: nightMode ? "#3E465F" : "#FFFDF9"
    property color cardSoft: nightMode ? "#454D68" : "#F7F3EE"
    property color mint: nightMode ? "#7780B5" : "#CFE8D8"
    property color lightMint: nightMode ? "#596184" : "#DDF1E5"
    property color cream: nightMode ? "#555A78" : "#F4E8C8"
    property color almond: nightMode ? "#5A5268" : "#EFDCC3"
    property color blush: nightMode ? "#65536A" : "#EBC9CF"
    property color lavender: nightMode ? "#60668C" : "#D9D0F2"
    property color borderColor: nightMode ? "#626A90" : "#E8E0D8"
    property color softBorder: nightMode ? "#737BA4" : "#EFE7DE"
    property color progressBg: nightMode ? "#596184" : "#EFE7DE"
    property color shadowColor: nightMode ? "#05070D" : "#BFAE9D"
    property color strongText: nightMode ? "#DADDFD" : "#2F7A5B"

    // 0=今日 1=本月 2=本年 3=全部
    property int selectedRange: 3
    property var softwareStats: []
    property int projectRefreshKey: 0

    onSelectedRangeChanged: refreshSoftwareStats()

    Connections {
        target: usageStatManager

        function onUsageStatsChanged() {
            root.softwareStats = usageStatManager ? usageStatManager.activeSoftwareForRange(root.rangeKey()) : []
        }
    }

    Connections {
        target: projectManager

        function onProjectsChanged() {
            projectRefreshKey += 1
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: refreshSoftwareStats()
    }

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
        var total = Math.max(0, Math.floor(minutes ? minutes : 0))
        var h = Math.floor(total / 60)
        var m = total % 60
        return h + "h " + m + "m"
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

    function projectMinutesForCurrentRange() {
        projectRefreshKey
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

    function refreshSoftwareStats() {
        if (!usageStatManager) {
            softwareStats = []
            return
        }

        usageStatManager.refresh()
        softwareStats = usageStatManager.activeSoftwareForRange(rangeKey())
    }

    function currentSoftwareStats() {
        return softwareStats ? softwareStats : []
    }

    function totalSoftwareSeconds() {
        var list = currentSoftwareStats()
        var totalSeconds = 0
        for (var i = 0; i < list.length; i++)
            totalSeconds += list[i].seconds ? list[i].seconds : 0
        return totalSeconds
    }

    function totalCombinedSeconds() {
        return totalSoftwareSeconds() + projectMinutesForCurrentRange() * 60
    }

    function currentProjects() {
        projectRefreshKey
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

    function currentSoftwareStatsSorted() {
        var list = currentSoftwareStats().slice()
        list.sort(function(a, b) {
            return (b.seconds ? b.seconds : 0) - (a.seconds ? a.seconds : 0)
        })
        return list
    }

    function topSoftware(maxCount) {
        var list = currentSoftwareStatsSorted()
        return list.length > maxCount ? list.slice(0, maxCount) : list
    }

    function topProjects(maxCount) {
        var list = currentProjects()
        return list.length > maxCount ? list.slice(0, maxCount) : list
    }

    function maxSoftwareSeconds() {
        var list = currentSoftwareStatsSorted()
        if (!list || list.length === 0)
            return 1
        return list[0].seconds > 0 ? list[0].seconds : 1
    }

    function maxProjectSeconds() {
        var list = currentProjects()
        if (!list || list.length === 0)
            return 1
        return list[0].seconds ? list[0].seconds : 1
    }

    // 调色板统一委托到 TagPalette.js（单一来源，杜绝多页色表漂移）。
    function tagColor(tag) { return TagPalette.tagColor(tag) }

    function containsAny(text, words) {
        for (var i = 0; i < words.length; i++) {
            if (text.indexOf(words[i]) >= 0)
                return true
        }
        return false
    }

    function hashedColor(text) {
        var palette = ["#CFE8D8", "#D9D0F2", "#EFDCC3", "#EBC9CF", "#BFD7EA", "#DDF1E5", "#E7D4EA", "#D8D1CA"]
        var hash = 0
        for (var i = 0; i < text.length; i++)
            hash = ((hash * 31) + text.charCodeAt(i)) & 0x7fffffff
        return palette[hash % palette.length]
    }

    function appColor(appId, appName, path) {
        return AppVisual.appColor(appId, appName, path)
    }

    function appIconSource(appId, path) {
        return AppVisual.appIconSource(appId, path)
    }

    function appIconLabel(appId, appName) {
        return AppVisual.appIconLabel(appId, appName)
    }

    function summaryStats() {
        return [
            { title: "总时长", value: secondsToDisplay(totalCombinedSeconds()), note: rangeText() + "视图", icon: "Σ", color: mint },
            { title: "软件使用", value: secondsToDisplay(totalSoftwareSeconds()), note: "自动记录", icon: "A", color: lightMint },
            { title: "自定义项目", value: minutesToDisplay(projectMinutesForCurrentRange()), note: "手动计时", icon: "M", color: cream }
        ]
    }

    function distributionStats() {
        return [
            { label: "软件使用", seconds: totalSoftwareSeconds(), color: mint },
            { label: "手动项目", seconds: projectMinutesForCurrentRange() * 60, color: lavender }
        ]
    }

    function ratio(seconds) {
        return Math.min(1, Math.max(0, seconds / Math.max(1, totalCombinedSeconds())))
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: panelColor
        opacity: nightMode ? 0.28 : 0.42
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 4
        clip: true

        Column {
            id: pageColumn
            width: root.width - 16
            spacing: 18

            Rectangle {
                width: parent.width
                height: 150
                radius: 34
                color: "transparent"
                border.width: 1
                border.color: nightMode ? "#697195" : "#D8E7DC"

                Rectangle {
                    x: 0
                    y: 10
                    width: parent.width
                    height: parent.height
                    radius: parent.radius
                    color: shadowColor
                    opacity: nightMode ? 0.16 : 0.08
                    z: -2
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 33
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: nightMode ? "#495170" : "#CFE8D8" }
                        GradientStop { position: 1.0; color: nightMode ? "#383E57" : "#F4E8C8" }
                    }
                    opacity: nightMode ? 0.88 : 0.96
                    z: -1
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 20

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        SoftPill {
                            compact: true
                            title: ""
                            value: rangeText() + " dashboard"
                            iconText: "S"
                            fillColor: nightMode ? "#535B7B" : "#FFFDF9"
                            strokeColor: nightMode ? "#737BA4" : "#E8E0D8"
                            accentColor: mint
                            valueColor: textPrimary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "时间统计"
                            color: textPrimary
                            font.pixelSize: 36
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "查看软件使用时长与自定义项目时长"
                            color: textSecondary
                            font.pixelSize: 15
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 410
                        Layout.preferredHeight: 52
                        radius: 22
                        color: nightMode ? "#454D68" : "#FFFDF9"
                        border.width: 1
                        border.color: nightMode ? "#737BA4" : "#E8E0D8"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Repeater {
                                model: ["今日", "本月", "本年", "全部"]

                                delegate: Rectangle {
                                    required property int index
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 17
                                    color: root.selectedRange === index ? (nightMode ? "#8E93D8" : "#1F1A17") : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: root.selectedRange === index ? "#FFFDF9" : textSecondary
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
                }
            }

            GridLayout {
                width: parent.width
                columns: 3
                columnSpacing: 18
                rowSpacing: 18

                Repeater {
                    model: summaryStats()

                    delegate: SoftCard {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 132
                        radius: 28
                        padding: 18
                        fillColor: cardColor
                        fillOpacity: nightMode ? 0.74 : 0.86
                        strokeColor: borderColor
                        shadowColor: shadowColor
                        shadowOpacity: nightMode ? 0.15 : 0.07

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 9

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 17
                                    color: modelData.color

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        color: textPrimary
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: textSecondary
                                    font.pixelSize: 14
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.value
                                color: textPrimary
                                font.pixelSize: 28
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.note
                                color: strongText
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }
                }
            }

            SoftCard {
                width: parent.width
                height: 250
                radius: 30
                padding: 22
                fillColor: cardColor
                fillOpacity: nightMode ? 0.74 : 0.86
                strokeColor: borderColor
                shadowColor: shadowColor
                shadowOpacity: nightMode ? 0.16 : 0.08

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: rangeText() + "时间分布"
                                color: textPrimary
                                font.pixelSize: 24
                                font.bold: true
                            }

                            Text {
                                text: "自动记录与手动项目的占比"
                                color: textSecondary
                                font.pixelSize: 13
                            }
                        }

                        SoftPill {
                            compact: true
                            title: ""
                            value: secondsToDisplay(totalCombinedSeconds())
                            iconText: "Σ"
                            fillColor: lightMint
                            strokeColor: softBorder
                            accentColor: mint
                            valueColor: textPrimary
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 17
                        color: progressBg
                        clip: true

                        Row {
                            anchors.fill: parent

                            Repeater {
                                model: distributionStats()

                                delegate: Rectangle {
                                    required property var modelData

                                    width: Math.max(modelData.seconds > 0 ? 10 : 0, parent.width * ratio(modelData.seconds))
                                    height: parent.height
                                    color: modelData.color
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        Repeater {
                            model: distributionStats()

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 22
                                color: cardSoft
                                border.width: 1
                                border.color: softBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                        radius: 21
                                        color: modelData.color
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            color: textPrimary
                                            font.pixelSize: 16
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: secondsToDisplay(modelData.seconds)
                                            color: textSecondary
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: Math.round(ratio(modelData.seconds) * 100) + "%"
                                        color: strongText
                                        font.pixelSize: 18
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 18

                SoftCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 520
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

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: "Top apps"
                                    color: textPrimary
                                    font.pixelSize: 24
                                    font.bold: true
                                }

                                Text {
                                    text: rangeText() + "软件使用排行"
                                    color: textSecondary
                                    font.pixelSize: 13
                                }
                            }

                            Text {
                                text: topSoftware(99).length + " 个"
                                color: textSecondary
                                font.pixelSize: 13
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 12
                            model: topSoftware(8)

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 76
                                radius: 22
                                color: cardSoft
                                border.width: 1
                                border.color: softBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                        radius: 21
                                        color: appColor(modelData.groupKey ? modelData.groupKey : modelData.appId, modelData.name, modelData.path)

                                        Image {
                                            anchors.centerIn: parent
                                            width: 30
                                            height: 30
                                            source: appIconSource(modelData.groupKey ? modelData.groupKey : modelData.appId, modelData.path)
                                            sourceSize.width: 64
                                            sourceSize.height: 64
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            smooth: true
                                            mipmap: true
                                            visible: source != ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: appIconSource(modelData.groupKey ? modelData.groupKey : modelData.appId, modelData.path) === ""
                                            text: appIconLabel(modelData.groupKey ? modelData.groupKey : modelData.appId, modelData.name)
                                            color: nightMode ? "#FFFFFF" : "#2D2724"
                                            font.pixelSize: 20
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name ? modelData.name : (modelData.appName ? modelData.appName : "Unknown app")
                                                color: textPrimary
                                                font.pixelSize: 15
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: modelData.time ? modelData.time : secondsToDisplay(modelData.seconds)
                                                color: strongText
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 7
                                            radius: 4
                                            color: progressBg
                                            clip: true

                                            Rectangle {
                                                width: parent.width * ((modelData.seconds ? modelData.seconds : 0) / Math.max(1, maxSoftwareSeconds()))
                                                height: parent.height
                                                radius: 4
                                                color: appColor(modelData.groupKey ? modelData.groupKey : modelData.appId, modelData.name, modelData.path)
                                            }
                                        }
                                    }
                                }
                            }

                            footer: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: topSoftware(8).length === 0 ? 120 : 0

                                Text {
                                    anchors.centerIn: parent
                                    visible: topSoftware(8).length === 0
                                    text: "当前范围还没有软件记录"
                                    color: textSecondary
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                }

                SoftCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 520
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

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: "Top projects"
                                    color: textPrimary
                                    font.pixelSize: 24
                                    font.bold: true
                                }

                                Text {
                                    text: rangeText() + "自定义项目排行"
                                    color: textSecondary
                                    font.pixelSize: 13
                                }
                            }

                            Text {
                                text: topProjects(99).length + " 个"
                                color: textSecondary
                                font.pixelSize: 13
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 12
                            model: topProjects(8)

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 82
                                radius: 22
                                color: cardSoft
                                border.width: 1
                                border.color: softBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                        radius: 21
                                        color: tagColor(modelData.tag)

                                        Text {
                                            anchors.centerIn: parent
                                            text: index + 1
                                            color: textPrimary
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name ? modelData.name : "未命名项目"
                                                color: textPrimary
                                                font.pixelSize: 15
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: modelData.time ? modelData.time : secondsToDisplay(modelData.seconds)
                                                color: strongText
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.tag ? modelData.tag : "未分类"
                                            color: textSecondary
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 7
                                            radius: 4
                                            color: progressBg
                                            clip: true

                                            Rectangle {
                                                width: parent.width * ((modelData.seconds ? modelData.seconds : 0) / Math.max(1, maxProjectSeconds()))
                                                height: parent.height
                                                radius: 4
                                                color: tagColor(modelData.tag)
                                            }
                                        }
                                    }
                                }
                            }

                            footer: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: topProjects(8).length === 0 ? 120 : 0

                                Text {
                                    anchors.centerIn: parent
                                    visible: topProjects(8).length === 0
                                    text: "当前范围还没有项目记录"
                                    color: textSecondary
                                    font.pixelSize: 14
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

    Component.onCompleted: refreshSoftwareStats()
}
