import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent
    clip: true

    signal importSoftware()
    signal startProject(string projectName)

    // =========================
    // 从 AppShell 传入的主题属性
    // =========================
    property bool nightMode: false
    property color themeTextPrimary: "#4E342E"
    property color themeTextSecondary: "#9C806C"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#DDC9B5"
    property color themeAccentColor: "#E8C6A3"

    // =========================
    // 基础颜色
    // =========================
    property color textPrimary: themeTextPrimary
    property color textSecondary: themeTextSecondary

    property color accentBrown: themeAccentColor
    property color accentBrownDeep: nightMode ? "#D9D8FF" : "#A96F46"

    property color panelGlass: nightMode ? "#505675" : "#FFFDF9"
    property real panelOpacity: nightMode ? 0.52 : 0.48

    property color cardGlass: nightMode ? "#59607F" : "#FFFDF9"
    property real cardOpacity: nightMode ? 0.48 : 0.42

    property color borderColor: themeBorderColor
    property color softBorder: nightMode ? "#757CA6" : "#E6D6C5"

    // 删除弹窗当前目标项目
    property string deleteTargetProjectName: ""

    // =========================
    // 固定标签
    // =========================
    property var fixedTags: ["学习", "工作", "运动", "娱乐", "阅读", "社交", "生活", "其他"]

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

    function tagIcon(tag) {
        if (tag === "学习") return "✦"
        if (tag === "工作") return "▣"
        if (tag === "运动") return "●"
        if (tag === "娱乐") return "★"
        if (tag === "阅读") return "✎"
        if (tag === "社交") return "♥"
        if (tag === "生活") return "☀"
        return "•"
    }

    function minutesToDisplay(minutes) {
        var total = Math.max(0, Math.floor(minutes))
        var h = Math.floor(total / 60)
        var m = total % 60
        return h + "h " + m + "m"
    }

    function secondsToDisplay(seconds) {
        var totalMinutes = Math.floor(Math.max(0, seconds) / 60)
        return minutesToDisplay(totalMinutes)
    }

    // =========================
    // 今日项目数据
    // =========================
    property var todayProjects: projectManager ? projectManager.projectsForRange("day") : []

    // 右侧列表显示全部项目
    property var allProjects: projectManager ? projectManager.projects : []

    function todaySecondsForProject(projectName) {
        var list = todayProjects
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === projectName)
                return list[i].seconds ? list[i].seconds : 0
        }
        return 0
    }

    function tagMinutesToday(tag) {
        return projectManager ? projectManager.tagMinutesFor(tag, "day") : 0
    }

    function allTagStatsToday() {
        var result = []

        for (var i = 0; i < fixedTags.length; i++) {
            var tag = fixedTags[i]
            var minutes = tagMinutesToday(tag)
            result.push({
                tag: tag,
                minutes: minutes,
                color: tagColor(tag)
            })
        }

        return result
    }

    function topThreeTagStatsToday() {
        var list = allTagStatsToday().slice()

        list.sort(function(a, b) {
            return b.minutes - a.minutes
        })

        var filtered = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].minutes > 0)
                filtered.push(list[i])
        }

        if (filtered.length > 3)
            return filtered.slice(0, 3)

        return filtered
    }

    function totalAllTagsTodayMinutes() {
        var list = allTagStatsToday()
        var total = 0

        for (var i = 0; i < list.length; i++)
            total += list[i].minutes

        return Math.max(1, total)
    }

    property var todayTagStats: allTagStatsToday()
    property var topThreeTodayTagStats: topThreeTagStatsToday()

    Flickable {
        id: flickArea
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: pageColumn
            width: flickArea.width
            spacing: 18

            // =========================
            // 顶部标题
            // =========================
            Column {
                spacing: 6

                Text {
                    text: "首页"
                    color: textPrimary
                    font.pixelSize: 42
                    font.bold: true
                }

                Text {
                    text: nightMode
                          ? "今晚也慢慢记录今天的时间轨迹。"
                          : "今天也慢慢记录今天的时间轨迹。"
                    color: textSecondary
                    font.pixelSize: 16
                }
            }

            // =========================
            // 今日项目分布 + 圆环
            // =========================
            Rectangle {
                width: parent.width
                height: 390
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

                Row {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 24

                    Column {
                        width: 240
                        spacing: 12

                        Text {
                            text: "今日项目分布"
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            text: "圆环按今天的主要标签时长比例展示。"
                            color: textSecondary
                            font.pixelSize: 15
                            wrapMode: Text.Wrap
                            width: parent.width
                        }

                        Repeater {
                            model: topThreeTodayTagStats

                            delegate: Rectangle {
                                required property var modelData

                                width: parent.width
                                height: 70
                                radius: 18
                                color: "transparent"
                                border.width: 1
                                border.color: softBorder

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 17
                                    color: cardGlass
                                    opacity: cardOpacity
                                    z: -1
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: modelData.color
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.tag + "  " + minutesToDisplay(modelData.minutes)
                                        color: textPrimary
                                        font.pixelSize: 15
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        Text {
                            visible: topThreeTodayTagStats.length === 0
                            text: "今天还没有标签记录"
                            color: textSecondary
                            font.pixelSize: 14
                        }
                    }

                    Item {
                        width: parent.width - 280
                        height: parent.height

                        Canvas {
                            id: ringCanvas
                            width: 270
                            height: 270
                            anchors.centerIn: parent
                            antialiasing: true

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()

                                var cx = width / 2
                                var cy = height / 2
                                var radius = 100
                                var lineWidth = 26

                                function drawArc(startAngle, spanAngle, colorValue) {
                                    if (spanAngle <= 0)
                                        return
                                    ctx.beginPath()
                                    ctx.strokeStyle = colorValue
                                    ctx.lineWidth = lineWidth
                                    ctx.lineCap = "round"
                                    ctx.arc(cx, cy, radius, startAngle, startAngle + spanAngle, false)
                                    ctx.stroke()
                                }

                                ctx.beginPath()
                                ctx.strokeStyle = nightMode ? "#686F98" : "#EFE7DD"
                                ctx.lineWidth = lineWidth
                                ctx.arc(cx, cy, radius, 0, Math.PI * 2, false)
                                ctx.stroke()

                                var stats = allTagStatsToday()
                                var totalMinutes = 0

                                for (var i = 0; i < stats.length; i++)
                                    totalMinutes += stats[i].minutes

                                if (totalMinutes <= 0)
                                    return

                                var start = -Math.PI / 2
                                var full = Math.PI * 2

                                for (var j = 0; j < stats.length; j++) {
                                    if (stats[j].minutes <= 0)
                                        continue

                                    var angle = full * stats[j].minutes / totalMinutes
                                    drawArc(start, angle, stats[j].color)
                                    start += angle
                                }
                            }
                        }

                        Rectangle {
                            width: 162
                            height: 162
                            radius: 81
                            color: "transparent"
                            anchors.centerIn: ringCanvas

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 80
                                color: cardGlass
                                opacity: 0.60
                                z: -1
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: minutesToDisplay(totalAllTagsTodayMinutes())
                                    color: textPrimary
                                    font.pixelSize: 30
                                    font.bold: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "今日项目累计"
                                    color: textSecondary
                                    font.pixelSize: 14
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }

            // =========================
            // 今日软件 + 全部自定义项目
            // =========================
            Row {
                width: parent.width
                height: 440
                spacing: 18

                // 左侧：今日软件
                Rectangle {
                    width: (parent.width - 18) / 2
                    height: parent.height
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
                            text: "今日软件使用"
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Repeater {
                            model: [
                                { name: "微信", time: "2h 15m" },
                                { name: "Chrome", time: "1h 42m" },
                                { name: "VSCode", time: "3h 08m" }
                            ]

                            delegate: Rectangle {
                                required property var modelData

                                width: parent.width
                                height: 72
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

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: tagColor("娱乐")
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: modelData.name
                                            color: textPrimary
                                            font.pixelSize: 18
                                            font.bold: true
                                        }

                                        Text {
                                            text: "自动记录"
                                            color: textSecondary
                                            font.pixelSize: 13
                                        }
                                    }

                                    Item { width: 1; height: 1 }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.time
                                        color: accentBrownDeep
                                        font.pixelSize: 17
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // 右侧：全部自定义项目
                Rectangle {
                    width: (parent.width - 18) / 2
                    height: parent.height
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
                            text: "自定义项目"
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            text: "显示全部项目，今日时长单独标注"
                            color: textSecondary
                            font.pixelSize: 14
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 76
                            clip: true
                            spacing: 14
                            model: allProjects

                            delegate: Rectangle {
                                id: projectCard
                                required property var modelData

                                width: ListView.view.width
                                height: 102
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

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: tagColor(modelData.tag)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: tagIcon(modelData.tag)
                                            color: "#FFF8F2"
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }

                                    Column {
                                        width: parent.width - 150
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: modelData.name
                                            color: textPrimary
                                            font.pixelSize: 17
                                            font.bold: true
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Text {
                                            text: "标签: " + modelData.tag
                                            color: textSecondary
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: "今日: " + secondsToDisplay(todaySecondsForProject(modelData.name))
                                                  + "    累计: " + (modelData.time ? modelData.time : "0h 0m")
                                            color: accentBrownDeep
                                            font.pixelSize: 13
                                            font.bold: true
                                            width: parent.width
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Item { width: 1; height: 1 }

                                    Rectangle {
                                        width: 84
                                        height: 40
                                        radius: 16
                                        color: nightMode ? "#8E93D8" : "#E8C6A3"
                                        opacity: 0.92
                                        border.width: 1
                                        border.color: nightMode ? "#757ED0" : "#DBB18A"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "开始"
                                            color: nightMode ? "#F8F7FF" : "#6A4C3B"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: startProject(modelData.name)
                                        }
                                    }
                                }

                                Menu {
                                    id: projectMenu

                                    MenuItem {
                                        text: "删除项目"
                                        onTriggered: {
                                            deleteTargetProjectName = modelData.name
                                            deleteProjectDialog.open()
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    propagateComposedEvents: true
                                    onPressed: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            deleteTargetProjectName = modelData.name
                                            projectMenu.popup()
                                            mouse.accepted = true
                                        } else {
                                            mouse.accepted = false
                                        }
                                    }
                                }
                            }

                            footer: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: allProjects.length === 0 ? 120 : 0

                                Text {
                                    anchors.centerIn: parent
                                    visible: allProjects.length === 0
                                    text: "还没有自定义项目，点击右下角 + 添加"
                                    color: textSecondary
                                    font.pixelSize: 15
                                }
                            }
                        }
                    }
                }
            }

            // =========================
            // 更多记录
            // =========================
            Rectangle {
                width: parent.width
                height: 220
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
                    anchors.margins: 24
                    spacing: 14

                    Text {
                        text: "今日记录"
                        color: textPrimary
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Text {
                        text: "这里以后可以继续放今日趋势、今日完成项目、今日最常用软件。"
                        color: textSecondary
                        font.pixelSize: 15
                    }
                }
            }
        }
    }

    // =========================
    // 删除确认弹窗
    // =========================
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
            color: nightMode ? "#4A506F" : "#FBF7F2"
            border.width: 1
            border.color: borderColor
        }

        contentItem: Column {
            width: deleteProjectDialog.availableWidth
            spacing: 16

            Text {
                text: "删除自定义项目"
                color: textPrimary
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "确定删除项目“" + deleteTargetProjectName + "”吗？删除后，对应的统计记录也会一起移除。"
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
                    text: "取消"
                    onClicked: deleteProjectDialog.close()
                }

                Button {
                    text: "确认删除"
                    onClicked: {
                        if (projectManager && deleteTargetProjectName.length > 0) {
                            projectManager.removeProject(deleteTargetProjectName)
                        }
                        deleteTargetProjectName = ""
                        deleteProjectDialog.close()
                    }
                }
            }
        }
    }

    // =========================
    // 右下角添加按钮
    // =========================
    Rectangle {
        id: addButton
        width: 68
        height: 68
        radius: 34
        color: nightMode ? "#8E93D8" : accentBrown
        border.width: 1
        border.color: nightMode ? "#757ED0" : "#CDA57D"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 28
        z: 30

        Text {
            anchors.centerIn: parent
            text: "+"
            color: "#FFFDF9"
            font.pixelSize: 34
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
            text: "添加自定义项目"
            onTriggered: addProjectDialog.open()
        }

        MenuItem {
            text: "导入想查看时间的软件"
            onTriggered: importSoftware()
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
            color: nightMode ? "#4A506F" : "#FBF7F2"
            border.width: 1
            border.color: borderColor
        }

        contentItem: Column {
            width: addProjectDialog.availableWidth
            spacing: 16

            Text {
                text: "添加自定义项目"
                color: textPrimary
                font.pixelSize: 26
                font.bold: true
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "项目名称"
                    color: accentBrownDeep
                    font.pixelSize: 14
                }

                TextField {
                    id: projectNameField
                    width: parent.width
                    placeholderText: "例如：学英语"
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "选择标签"
                    color: accentBrownDeep
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
                    text: "取消"
                    onClicked: addProjectDialog.close()
                }

                Button {
                    text: "确认添加"
                    onClicked: {
                        var nameText = projectNameField.text.trim()
                        if (nameText.length > 0 && projectManager) {
                            projectManager.addProject(nameText, tagBox.currentText)
                            projectNameField.text = ""
                            tagBox.currentIndex = 0
                            ringCanvas.requestPaint()
                            addProjectDialog.close()
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: projectManager

        function onProjectsChanged() {
            ringCanvas.requestPaint()
        }
    }

    Component.onCompleted: ringCanvas.requestPaint()

    onImportSoftware: {
        console.log("导入想查看时间的软件")
    }
}
