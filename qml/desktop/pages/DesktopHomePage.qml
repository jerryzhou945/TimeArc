import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../components/AppVisual.js" as AppVisual
import "../components/TagPalette.js" as TagPalette
import "../components/I18n.js" as I18n

Item {
    id: root
    anchors.fill: parent
    clip: true

    signal startProject(string projectName, string tagName)

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
    property color pageSurface: nightMode ? "#30364D" : "#F7F3EE"
    property color panelGlass: nightMode ? "#353C55" : "#FBF8F4"
    property color cardGlass: nightMode ? "#3E465F" : "#FFFDF9"
    property color softMint: nightMode ? "#596184" : "#DDF1E5"
    property color mint: nightMode ? "#7780B5" : "#CFE8D8"
    property color cream: nightMode ? "#4B526F" : "#F4E8C8"
    property color almond: nightMode ? "#555A78" : "#EFDCC3"
    property color blush: nightMode ? "#65536A" : "#EBC9CF"
    property color lavender: nightMode ? "#60668C" : "#D9D0F2"
    property color borderColor: nightMode ? "#626A90" : "#E8E0D8"
    property color softBorder: nightMode ? "#737BA4" : "#EFE7DE"
    property color shadowColor: nightMode ? "#05070D" : "#BFAE9D"
    property color buttonDark: nightMode ? "#8E93D8" : "#1F1A17"
    property color buttonDarkHover: nightMode ? "#9AA0E7" : "#332C27"
    property color accentText: nightMode ? "#DADDFD" : "#2F7A5B"
    property bool showSideRail: width >= 1320

    property string deleteTargetProjectName: ""
    property var fixedTags: ["学习", "工作", "运动", "娱乐", "阅读", "社交", "生活", "其他"]
    property string selectedTag: fixedTags[0]
    property int projectRefreshKey: 0
    property var todaySoftwareStats: []

    onNightModeChanged: Qt.callLater(function() { ringCanvas.requestPaint() })

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: refreshTodaySoftwareStats()
    }

    Connections {
        target: usageStatManager

        function onUsageStatsChanged() {
            todaySoftwareStats = usageStatManager ? usageStatManager.activeSoftwareForRange("day") : []
            ringCanvas.requestPaint()
        }
    }

    Connections {
        target: projectManager

        function onProjectsChanged() {
            projectRefreshKey += 1
            ringCanvas.requestPaint()
        }
    }

    // 调色板与图标统一委托到 TagPalette.js（单一来源，杜绝多页色表漂移）。
    function tagColor(tag) { return TagPalette.tagColor(tag) }
    function tagIcon(tag) { return TagPalette.tagIcon(tag) }

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

    // 共享实现见 qml/desktop/components/AppVisual.js（首页与记忆湖共用，杜绝漂移）。
    function appColor(appId, appName, path) {
        return AppVisual.appColor(appId, appName, path)
    }

    function appIconSource(appId, path) {
        return AppVisual.appIconSource(appId, path)
    }

    function appIconLabel(appId, appName) {
        return AppVisual.appIconLabel(appId, appName)
    }

    function modelAppColor(row) {
        return AppVisual.modelAppColor(row)
    }

    function modelIconSource(row) {
        return AppVisual.modelIconSource(row)
    }

    function modelIconLabel(row) {
        return AppVisual.modelIconLabel(row)
    }

    function modelDisplayName(row) {
        return AppVisual.modelDisplayNameForLanguage(row, languageMode)
    }

    function refreshTodaySoftwareStats() {
        if (!usageStatManager) {
            todaySoftwareStats = []
            return
        }

        usageStatManager.refresh()
        todaySoftwareStats = usageStatManager.activeSoftwareForRange("day")
        ringCanvas.requestPaint()
    }

    function currentTodayProjects() {
        projectRefreshKey
        return projectManager ? projectManager.projectsForRange("day") : []
    }

    function tagSummariesAll() {
        projectRefreshKey
        return projectManager ? projectManager.tagSummariesForRange("all") : []
    }

    function projectsForSelectedTag() {
        projectRefreshKey
        return projectManager ? projectManager.projectsForTag(selectedTag, "all") : []
    }

    function tagMinutesToday(tag) {
        projectRefreshKey
        return projectManager ? projectManager.tagMinutesFor(tag, "day") : 0
    }

    function todaySecondsForProject(projectName, tagName) {
        var list = currentTodayProjects()
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === projectName && list[i].tag === tagName)
                return list[i].seconds ? list[i].seconds : 0
        }
        return 0
    }

    function softwareUsageSecondsToday() {
        var list = todaySoftwareStats ? todaySoftwareStats : []
        var total = 0
        for (var i = 0; i < list.length; i++)
            total += list[i].seconds ? list[i].seconds : 0
        return total
    }

    function manualUsageSecondsToday() {
        projectRefreshKey
        return projectManager ? projectManager.todayProjectMinutes * 60 : 0
    }

    function totalTodaySeconds() {
        return softwareUsageSecondsToday() + manualUsageSecondsToday()
    }

    function activeProjectName() {
        if (timerManager && timerManager.currentProject && timerManager.currentProject.length > 0)
            return timerManager.currentProject
        return "暂无进行中"
    }

    function currentSoftwareName() {
        if (!usageStatManager)
            return "等待记录"
        var current = usageStatManager.currentSoftware()
        if (!current)
            return "等待记录"
        var adapterName = modelDisplayName(current)
        if (adapterName.length > 0)
            return adapterName
        if (current.name && current.name.length > 0)
            return current.name
        if (current.appName && current.appName.length > 0)
            return current.appName
        return "等待记录"
    }

    function allTodayDistributionStats() {
        var result = []
        var softwareSeconds = softwareUsageSecondsToday()

        for (var i = 0; i < fixedTags.length; i++) {
            var tag = fixedTags[i]
            var minutes = tagMinutesToday(tag)
            result.push({
                tag: tag,
            label: root.tr(tag),
                seconds: minutes * 60,
                minutes: minutes,
                color: tagColor(tag),
                source: "project"
            })
        }

        result.push({
            tag: "自动软件",
            label: root.tr("自动软件"),
            seconds: softwareSeconds,
            minutes: softwareSeconds / 60,
            color: "#CFE8D8",
            source: "software"
        })

        return result
    }

    function topThreeTodayTagStats() {
        var list = allTodayDistributionStats().slice()
        list.sort(function(a, b) {
            return b.seconds - a.seconds
        })

        var filtered = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].seconds > 0)
                filtered.push(list[i])
        }

        return filtered.length > 3 ? filtered.slice(0, 3) : filtered
    }

    function topTodaySoftwareStats(maxCount) {
        var list = todaySoftwareStats ? todaySoftwareStats.slice() : []
        list.sort(function(a, b) {
            return (b.seconds ? b.seconds : 0) - (a.seconds ? a.seconds : 0)
        })
        return list.length > maxCount ? list.slice(0, maxCount) : list
    }

    function topTodayProjectStats(maxCount) {
        var list = currentTodayProjects().slice()
        var filtered = []
        for (var i = 0; i < list.length; i++) {
            if ((list[i].seconds ? list[i].seconds : 0) > 0)
                filtered.push(list[i])
        }
        filtered.sort(function(a, b) {
            return (b.seconds ? b.seconds : 0) - (a.seconds ? a.seconds : 0)
        })
        return filtered.length > maxCount ? filtered.slice(0, maxCount) : filtered
    }

    function recentProjects(maxCount) {
        projectRefreshKey
        var list = projectManager ? projectManager.projects : []
        var copy = list ? list.slice() : []
        return copy.length > maxCount ? copy.slice(0, maxCount) : copy
    }

    function maxSoftwareSeconds() {
        var list = topTodaySoftwareStats(12)
        if (!list || list.length === 0)
            return 1
        return Math.max(1, list[0].seconds ? list[0].seconds : 1)
    }

    function maxSelectedProjectSeconds() {
        var list = projectsForSelectedTag()
        var maxValue = 1
        for (var i = 0; i < list.length; i++)
            maxValue = Math.max(maxValue, todaySecondsForProject(list[i].name, list[i].tag))
        return maxValue
    }

    function summaryPills() {
        return [
            { title: root.tr("今日自动记录"), value: secondsToDisplay(softwareUsageSecondsToday()), icon: "A", color: mint },
            { title: root.tr("今日手动计时"), value: secondsToDisplay(manualUsageSecondsToday()), icon: "M", color: cream },
            { title: root.tr("当前项目"), value: activeProjectName(), icon: "▶", color: blush },
            { title: root.tr("活跃应用"), value: root.sentence("appCount", {count: (todaySoftwareStats ? todaySoftwareStats.length : 0)}, (todaySoftwareStats ? todaySoftwareStats.length : 0) + " 个"), icon: "●", color: lavender }
        ]
    }

    function progressRatio(seconds, targetSeconds) {
        return Math.min(1, Math.max(0, seconds / Math.max(1, targetSeconds)))
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: pageSurface
        opacity: nightMode ? 0.20 : 0.42
    }

    Flickable {
        id: flickArea
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 28
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: pageColumn
            width: flickArea.width
            spacing: 20

            Rectangle {
                width: parent.width
                height: 286
                radius: 34
                color: "transparent"
                border.width: 1
                border.color: nightMode ? "#697195" : "#D8E7DC"
                clip: false

                Rectangle {
                    x: 0
                    y: 10
                    width: parent.width
                    height: parent.height
                    radius: parent.radius
                    color: shadowColor
                    opacity: nightMode ? 0.18 : 0.10
                    z: -2
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 33
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: nightMode ? "#495170" : "#CFE8D8" }
                        GradientStop { position: 0.52; color: nightMode ? "#414762" : "#E8EFD8" }
                        GradientStop { position: 1.0; color: nightMode ? "#383E57" : "#F4E8C8" }
                    }
                    opacity: nightMode ? 0.90 : 0.96
                    z: -1
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 24

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        SoftPill {
                            compact: true
                            title: ""
                            value: "TimeArc Today"
                            iconText: "T"
                            fillColor: nightMode ? "#555D7E" : "#FBF8F4"
                            strokeColor: nightMode ? "#71789E" : "#E8E0D8"
                            accentColor: nightMode ? "#8E93D8" : "#DDF1E5"
                            valueColor: textPrimary
                            titleColor: textSecondary
                        }

                        Text {
                            Layout.fillWidth: true
                    text: root.tr("把今天的时间轻轻收好")
                            color: textPrimary
                            font.pixelSize: 42
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                    text: nightMode ? root.tr("今晚也保持温柔的节奏，自动记录与手动计时都在这里汇合。") : root.tr("欢迎回来。自动记录、手动项目和今日节奏，都在这里安静地展开。")
                            color: textSecondary
                            font.pixelSize: 16
                            wrapMode: Text.WordWrap
                            lineHeight: 1.18
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > 720 ? 4 : 2
                            columnSpacing: 10
                            rowSpacing: 10

                            Repeater {
                                model: summaryPills()

                                delegate: SoftPill {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    title: modelData.title
                                    value: modelData.value
                                    iconText: modelData.icon
                                    fillColor: nightMode ? "#4A526F" : "#FFFDF9"
                                    strokeColor: nightMode ? "#6E769C" : "#E8E0D8"
                                    accentColor: modelData.color
                                    titleColor: textSecondary
                                    valueColor: textPrimary
                                }
                            }
                        }
                    }

                    SoftCard {
                        Layout.preferredWidth: 260
                        Layout.fillHeight: true
                        radius: 30
                        padding: 18
                        fillColor: nightMode ? "#3E465F" : "#FFFDF9"
                        fillOpacity: nightMode ? 0.72 : 0.70
                        strokeColor: nightMode ? "#6E769C" : "#E8E0D8"
                        shadowColor: shadowColor
                        shadowOpacity: 0.04

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                    text: root.tr("今日概览")
                                        color: textPrimary
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    Text {
                    text: root.tr("自动 + 手动")
                                        color: textSecondary
                                        font.pixelSize: 12
                                    }
                                }

                                Text {
                                    text: secondsToDisplay(totalTodaySeconds())
                                    color: accentText
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Canvas {
                                    id: ringCanvas
                                    width: 156
                                    height: 156
                                    anchors.centerIn: parent
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()

                                        var cx = width / 2
                                        var cy = height / 2
                                        var radius = 56
                                        var lineWidth = 18

                                        ctx.beginPath()
                                        ctx.strokeStyle = nightMode ? "#626A90" : "#EFE7DE"
                                        ctx.lineWidth = lineWidth
                                        ctx.arc(cx, cy, radius, 0, Math.PI * 2, false)
                                        ctx.stroke()

                                        var stats = allTodayDistributionStats()
                                        var totalSeconds = 0
                                        for (var i = 0; i < stats.length; i++)
                                            totalSeconds += stats[i].seconds
                                        if (totalSeconds <= 0)
                                            return

                                        var start = -Math.PI / 2
                                        var full = Math.PI * 2
                                        for (var j = 0; j < stats.length; j++) {
                                            if (stats[j].seconds <= 0)
                                                continue

                                            var angle = full * stats[j].seconds / totalSeconds
                                            ctx.beginPath()
                                            ctx.strokeStyle = stats[j].color
                                            ctx.lineWidth = lineWidth
                                            ctx.lineCap = "round"
                                            ctx.arc(cx, cy, radius, start, start + angle, false)
                                            ctx.stroke()
                                            start += angle
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        text: secondsToDisplay(totalTodaySeconds())
                                        color: textPrimary
                                        font.pixelSize: 23
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                    text: root.tr("今日累计")
                                        color: textSecondary
                                        font.pixelSize: 12
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Repeater {
                                model: topThreeTodayTagStats()

                                delegate: RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 9
                                        height: 9
                                        radius: 5
                                        color: modelData.color
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: textSecondary
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: secondsToDisplay(modelData.seconds)
                                        color: textPrimary
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                id: coreRow
                width: parent.width
                height: showSideRail ? 826 : 624
                spacing: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 384
                        spacing: 18

                        SoftCard {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 384
                            radius: 30
                            padding: 20
                            fillColor: cardGlass
                            fillOpacity: nightMode ? 0.70 : 0.82
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
                    text: root.tr("今日自动记录")
                                            color: textPrimary
                                            font.pixelSize: 24
                                            font.bold: true
                                        }

                                        Text {
                                            text: currentSoftwareName()
                                            color: textSecondary
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }
                                    }

                                    SoftPill {
                                        compact: true
                                        title: ""
                                        value: secondsToDisplay(softwareUsageSecondsToday())
                                        iconText: "A"
                                        fillColor: softMint
                                        strokeColor: "transparent"
                                        accentColor: mint
                                        valueColor: textPrimary
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 10
                                    model: topTodaySoftwareStats(5)

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: ListView.view.width
                                        height: 58
                                        radius: 18
                                        color: nightMode ? "#454D68" : "#FBF8F4"
                                        border.width: 1
                                        border.color: softBorder

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 34
                                                Layout.preferredHeight: 34
                                                radius: 17
                                                color: modelAppColor(modelData)

                                                Image {
                                                    id: homeRankIconImage
                                                    anchors.centerIn: parent
                                                    width: 24
                                                    height: 24
                                                    source: modelIconSource(modelData)
                                                    sourceSize.width: 48
                                                    sourceSize.height: 48
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                    mipmap: true
                                                    visible: source != "" && status === Image.Ready
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: modelIconSource(modelData) === "" || homeRankIconImage.status !== Image.Ready
                                                    text: modelIconLabel(modelData)
                                                    color: nightMode ? "#FFFFFF" : "#2D2724"
                                                    font.pixelSize: 17
                                                    font.bold: true
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 5

                                                RowLayout {
                                                    Layout.fillWidth: true

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelDisplayName(modelData) || "Unknown app"
                                                        color: textPrimary
                                                        font.pixelSize: 14
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        text: modelData.time ? modelData.time : secondsToDisplay(modelData.seconds)
                                                        color: accentText
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 6
                                                    radius: 3
                                                    color: nightMode ? "#596184" : "#EFE7DE"
                                                    clip: true

                                                    Rectangle {
                                                        width: parent.width * ((modelData.seconds ? modelData.seconds : 0) / Math.max(1, maxSoftwareSeconds()))
                                                        height: parent.height
                                                        radius: 3
                                                        color: modelAppColor(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    footer: Item {
                                        width: ListView.view ? ListView.view.width : 0
                                        height: topTodaySoftwareStats(5).length === 0 ? 96 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            visible: topTodaySoftwareStats(5).length === 0
                        text: root.tr("今天还没有自动记录")
                                            color: textSecondary
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }
                        }

                        SoftCard {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 384
                            radius: 30
                            padding: 20
                            fillColor: cardGlass
                            fillOpacity: nightMode ? 0.70 : 0.82
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
                    text: root.tr("手动项目计时")
                                            color: textPrimary
                                            font.pixelSize: 24
                                            font.bold: true
                                        }

                                        Text {
                    text: root.sentence("selectedTagProjects", {tag: root.tr(selectedTag)}, selectedTag + "里的项目")
                                            color: textSecondary
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }
                                    }

                                    SoftButton {
                    text: root.tr("新建")
                                        iconText: "+"
                                        implicitWidth: 84
                                        fillColor: buttonDark
                                        hoverColor: buttonDarkHover
                                        textColor: "#FFFDF9"
                                        onClicked: {
                                            tagBox.currentIndex = fixedTags.indexOf(selectedTag)
                                            addProjectDialog.open()
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 88
                                    spacing: 8

                                    Repeater {
                                        model: tagSummariesAll()

                                        delegate: Rectangle {
                                            required property var modelData

                                            width: Math.max(76, (parent.width - 24) / 4)
                                            height: 38
                                            radius: 19
                                            color: selectedTag === modelData.tag ? tagColor(modelData.tag) : (nightMode ? "#454D68" : "#FBF8F4")
                                            border.width: 1
                                            border.color: selectedTag === modelData.tag ? "transparent" : softBorder

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 7

                                                Text {
                                                    text: tagIcon(modelData.tag)
                                                    color: textPrimary
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                        text: root.tr(modelData.tag)
                                                    color: textPrimary
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: selectedTag = modelData.tag
                                            }
                                        }
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 10
                                    model: projectsForSelectedTag()

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: ListView.view.width
                                        height: 70
                                        radius: 20
                                        color: nightMode ? "#454D68" : "#FBF8F4"
                                        border.width: 1
                                        border.color: softBorder

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 18
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

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Text {
                    text: root.sentence("todayDuration", {time: secondsToDisplay(todaySecondsForProject(modelData.name, modelData.tag))}, "今日 " + secondsToDisplay(todaySecondsForProject(modelData.name, modelData.tag)))
                                                        color: accentText
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }

                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 5
                                                        radius: 3
                                                        color: nightMode ? "#596184" : "#EFE7DE"
                                                        clip: true

                                                        Rectangle {
                                                            width: parent.width * (todaySecondsForProject(modelData.name, modelData.tag) / Math.max(1, maxSelectedProjectSeconds()))
                                                            height: parent.height
                                                            radius: 3
                                                            color: tagColor(modelData.tag)
                                                        }
                                                    }
                                                }
                                            }

                                            SoftButton {
                    text: root.tr("开始")
                                                implicitWidth: 74
                                                implicitHeight: 38
                                                radius: 15
                                                fontSize: 13
                                                fillColor: nightMode ? "#8E93D8" : "#1F1A17"
                                                hoverColor: nightMode ? "#9AA0E7" : "#332C27"
                                                textColor: "#FFFDF9"
                                                onClicked: startProject(modelData.name, modelData.tag)
                                            }
                                        }
                                    }

                                    footer: Item {
                                        width: ListView.view ? ListView.view.width : 0
                                        height: projectsForSelectedTag().length === 0 ? 92 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            visible: projectsForSelectedTag().length === 0
                        text: root.tr("这个标签里还没有项目")
                                            color: textSecondary
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SoftCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 222
                        radius: 30
                        padding: 20
                        fillColor: cardGlass
                        fillOpacity: nightMode ? 0.70 : 0.82
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
                    text: root.tr("本周趋势预览")
                                        color: textPrimary
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                    text: root.tr("用今日分布先预览节奏，保持数据来源不变")
                                        color: textSecondary
                                        font.pixelSize: 13
                                    }
                                }

                                Text {
                                    text: secondsToDisplay(totalTodaySeconds())
                                    color: accentText
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                Repeater {
                                    model: allTodayDistributionStats()

                                    delegate: ColumnLayout {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 8

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Rectangle {
                                                width: Math.min(28, parent.width * 0.42)
                                                height: parent.height
                                                radius: 14
                                                color: nightMode ? "#596184" : "#EFE7DE"
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                            }

                                            Rectangle {
                                                width: Math.min(28, parent.width * 0.42)
                                                height: Math.max(8, parent.height * progressRatio(modelData.seconds, Math.max(1, totalTodaySeconds())))
                                                radius: 14
                                                color: modelData.color
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            color: textSecondary
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: sideRail
                    Layout.preferredWidth: showSideRail ? 318 : 0
                    Layout.maximumWidth: showSideRail ? 318 : 0
                    Layout.fillHeight: true
                    spacing: 18
                    visible: showSideRail

                    SoftCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 184
                        radius: 30
                        padding: 20
                        fillColor: nightMode ? "#3E465F" : "#FFFDF9"
                        fillOpacity: nightMode ? 0.74 : 0.86
                        strokeColor: borderColor
                        shadowColor: shadowColor
                        shadowOpacity: nightMode ? 0.16 : 0.08

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 12

                            Text {
                    text: root.tr("今日总结")
                                color: textPrimary
                                font.pixelSize: 22
                                font.bold: true
                            }

                            Text {
                                Layout.fillWidth: true
                    text: totalTodaySeconds() > 0 ? root.sentence("todayTrack", {time: secondsToDisplay(totalTodaySeconds())}, "已经留下 " + secondsToDisplay(totalTodaySeconds()) + " 的时间轨迹。") : root.tr("今天还很安静，可以从一个小项目开始。")
                                color: textSecondary
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                lineHeight: 1.18
                            }

                            SoftPill {
                                Layout.fillWidth: true
                title: root.tr("当前应用")
                                value: currentSoftwareName()
                                iconText: "●"
                                fillColor: nightMode ? "#4A526F" : "#F7F3EE"
                                strokeColor: softBorder
                                accentColor: mint
                                titleColor: textSecondary
                                valueColor: textPrimary
                            }
                        }
                    }

                    SoftCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 196
                        radius: 30
                        padding: 20
                        fillColor: nightMode ? "#3E465F" : "#FFFDF9"
                        fillOpacity: nightMode ? 0.74 : 0.86
                        strokeColor: borderColor
                        shadowColor: shadowColor
                        shadowOpacity: nightMode ? 0.16 : 0.08

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: "Lake progress"
                                    color: textPrimary
                                    font.pixelSize: 22
                                    font.bold: true
                                }

                                Text {
                                    text: Math.round(progressRatio(totalTodaySeconds(), 8 * 3600) * 100) + "%"
                                    color: accentText
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                radius: 6
                                color: nightMode ? "#596184" : "#EFE7DE"
                                clip: true

                                Rectangle {
                                    width: parent.width * progressRatio(totalTodaySeconds(), 8 * 3600)
                                    height: parent.height
                                    radius: 6
                                    color: mint
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                    text: root.tr("以 8 小时为满格，展示今天的积累感。")
                                color: textSecondary
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SoftPill {
                                    Layout.fillWidth: true
                                    compact: true
                title: root.tr("手动")
                                    value: secondsToDisplay(manualUsageSecondsToday())
                                    iconText: "M"
                                    fillColor: nightMode ? "#4A526F" : "#FBF8F4"
                                    strokeColor: softBorder
                                    accentColor: cream
                                    titleColor: textSecondary
                                    valueColor: textPrimary
                                }

                                SoftPill {
                                    Layout.fillWidth: true
                                    compact: true
                title: root.tr("自动")
                                    value: secondsToDisplay(softwareUsageSecondsToday())
                                    iconText: "A"
                                    fillColor: nightMode ? "#4A526F" : "#FBF8F4"
                                    strokeColor: softBorder
                                    accentColor: mint
                                    titleColor: textSecondary
                                    valueColor: textPrimary
                                }
                            }
                        }
                    }

                    SoftCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 392
                        radius: 30
                        padding: 20
                        fillColor: nightMode ? "#3E465F" : "#FFFDF9"
                        fillOpacity: nightMode ? 0.74 : 0.86
                        strokeColor: borderColor
                        shadowColor: shadowColor
                        shadowOpacity: nightMode ? 0.16 : 0.08

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14

                            Text {
                    text: root.tr("最近项目")
                                color: textPrimary
                                font.pixelSize: 22
                                font.bold: true
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 10
                                model: recentProjects(5)

                                delegate: Rectangle {
                                    required property var modelData

                                    width: ListView.view.width
                                    height: 58
                                    radius: 18
                                    color: nightMode ? "#454D68" : "#F7F3EE"
                                    border.width: 1
                                    border.color: softBorder

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10

                                        Rectangle {
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 30
                                            radius: 15
                                            color: tagColor(modelData.tag)

                                            Text {
                                                anchors.centerIn: parent
                                                text: tagIcon(modelData.tag)
                                                color: textPrimary
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelDisplayName(modelData)
                                                color: textPrimary
                                                font.pixelSize: 13
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.time ? modelData.time : "0h 0m"
                                                color: textSecondary
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                footer: Item {
                                    width: ListView.view ? ListView.view.width : 0
                                    height: recentProjects(5).length === 0 ? 80 : 0

                                    Text {
                                        anchors.centerIn: parent
                                        visible: recentProjects(5).length === 0
                        text: root.tr("还没有项目")
                                        color: textSecondary
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteProjectDialog
        modal: true
        width: 380
        height: 220
        padding: 20
        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)

        background: Rectangle {
            radius: 24
            color: nightMode ? "#4A506F" : "#FBF8F4"
            border.width: 1
            border.color: borderColor
        }

        contentItem: Column {
            width: deleteProjectDialog.availableWidth
            spacing: 16

            Text {
            text: root.tr("删除自定义项目")
                color: textPrimary
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
            text: root.sentence("deleteProjectConfirm", {name: deleteTargetProjectName}, "确定归档项目“" + deleteTargetProjectName + "”吗？归档后项目会从列表隐藏，历史计时和统计仍会保留。")
                color: textSecondary
                font.pixelSize: 14
            }

            Item {
                width: 1
                height: 8
            }

            Row {
                spacing: 12

                Button {
            text: root.tr("取消")
                    onClicked: deleteProjectDialog.close()
                }

                Button {
            text: root.tr("确认删除")
                    onClicked: {
                        if (projectManager && deleteTargetProjectName.length > 0)
                            projectManager.removeProject(deleteTargetProjectName)
                        deleteTargetProjectName = ""
                        deleteProjectDialog.close()
                    }
                }
            }
        }
    }

    Rectangle {
        id: addButton
        width: 66
        height: 66
        radius: 33
        color: buttonDark
        border.width: 1
        border.color: nightMode ? "#9AA0E7" : "#2D2724"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 26
        anchors.bottomMargin: 26
        z: 30

        Rectangle {
            x: 0
            y: 7
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: shadowColor
            opacity: nightMode ? 0.20 : 0.14
            z: -1
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            color: "#FFFDF9"
            font.pixelSize: 32
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: addMenu.popup(addButton.x, addButton.y - addMenu.height)
        }
    }

    Menu {
        id: addMenu

        MenuItem {
            text: root.tr("添加自定义项目")
            onTriggered: {
                tagBox.currentIndex = fixedTags.indexOf(selectedTag)
                addProjectDialog.open()
            }
        }

    }

    Dialog {
        id: addProjectDialog
        modal: true
        width: 380
        height: 300
        padding: 20
        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)

        background: Rectangle {
            radius: 24
            color: nightMode ? "#4A506F" : "#FBF8F4"
            border.width: 1
            border.color: borderColor
        }

        contentItem: Column {
            width: addProjectDialog.availableWidth
            spacing: 16

            Text {
            text: root.tr("添加自定义项目")
                color: textPrimary
                font.pixelSize: 26
                font.bold: true
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
            text: root.tr("项目名称")
                    color: accentText
                    font.pixelSize: 14
                }

                TextField {
                    id: projectNameField
                    width: parent.width
            placeholderText: root.tr("例如：学英语")
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
            text: root.tr("选择标签")
                    color: accentText
                    font.pixelSize: 14
                }

                ComboBox {
                    id: tagBox
                    width: parent.width
                    model: fixedTags
                    currentIndex: 0
                }
            }

            Item {
                width: 1
                height: 12
            }

            Row {
                spacing: 12

                Button {
            text: root.tr("取消")
                    onClicked: addProjectDialog.close()
                }

                Button {
            text: root.tr("确认添加")
                    onClicked: {
                        var nameText = projectNameField.text.trim()
                        if (nameText.length > 0 && projectManager) {
                            projectManager.addProject(nameText, tagBox.currentText)
                            selectedTag = tagBox.currentText
                            projectNameField.text = ""
                            tagBox.currentIndex = fixedTags.indexOf(selectedTag)
                            ringCanvas.requestPaint()
                            addProjectDialog.close()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        ringCanvas.requestPaint()
        refreshTodaySoftwareStats()
    }
}
