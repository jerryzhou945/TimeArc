import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Item {
    anchors.fill: parent

    signal importSoftware()
    signal startProject(string projectName)

    property color bgColor: "#FBF7F2"
    property color panelColor: "#F8F2EB"
    property color cardColor: "#FFFDF9"
    property color borderColor: "#E8DDD1"
    property color softBorder: "#EFE5D8"
    property color textPrimary: "#4E342E"
    property color textSecondary: "#9C806C"
    property color accentBrown: "#D8B38A"
    property color accentBrownDeep: "#A96F46"
    property color accentGreen: "#B9C98A"
    property color accentOrange: "#E5A85F"
    property color accentPurple: "#B9A4EF"

    property int projectItemHeight: 92
    property int projectCardTopPadding: 74
    property int projectCardBottomPadding: 24
    property int projectCardHeight: projectCardTopPadding + projectCardBottomPadding + projectModel.count * projectItemHeight

    property int softwareItemHeight: 86
    property int softwareCardTopPadding: 74
    property int softwareCardBottomPadding: 24
    property int softwareCardHeight: softwareCardTopPadding + softwareCardBottomPadding + softwareModel.count * softwareItemHeight

    property int listRowHeight: Math.max(softwareCardHeight, projectCardHeight)

    Settings {
        id: appSettings
        category: "DesktopHomePageData"
        property string savedProjects: ""
    }

    function timeStringToMinutes(timeStr) {
        var h = 0
        var m = 0

        var hMatch = timeStr.match(/(\d+)\s*小时/)
        var mMatch = timeStr.match(/(\d+)\s*分钟/)

        if (hMatch)
            h = parseInt(hMatch[1])
        if (mMatch)
            m = parseInt(mMatch[1])

        return h * 60 + m
    }

    function minutesToDisplay(minutes) {
        var h = Math.floor(minutes / 60)
        var m = minutes % 60
        return h + "h " + m + "m"
    }

    function tagMinutes(tagName) {
        var total = 0
        for (var i = 0; i < projectModel.count; i++) {
            var item = projectModel.get(i)
            if (item.tag === tagName)
                total += timeStringToMinutes(item.time)
        }
        return total
    }

    property int studyMinutes: tagMinutes("学习")
    property int sportMinutes: tagMinutes("运动")
    property int gameMinutes: tagMinutes("游戏")
    property int totalProjectMinutes: Math.max(1, studyMinutes + sportMinutes + gameMinutes)

    property real studySpan: 360 * studyMinutes / totalProjectMinutes
    property real sportSpan: 360 * sportMinutes / totalProjectMinutes
    property real gameSpan: 360 * gameMinutes / totalProjectMinutes

    function saveProjects() {
        var arr = []
        for (var i = 0; i < projectModel.count; i++) {
            var item = projectModel.get(i)
            arr.push({
                name: item.name,
                time: item.time,
                tag: item.tag
            })
        }
        appSettings.savedProjects = JSON.stringify(arr)
    }

    function loadProjects() {
        if (!appSettings.savedProjects || appSettings.savedProjects === "")
            return

        try {
            var arr = JSON.parse(appSettings.savedProjects)
            if (!arr || arr.length === 0)
                return

            projectModel.clear()
            for (var i = 0; i < arr.length; i++) {
                projectModel.append(arr[i])
            }
        } catch (e) {
            console.log("读取项目失败:", e)
        }
    }

    Component.onCompleted: {
        loadProjects()
    }

    ListModel {
        id: softwareModel
        ListElement { name: "微信"; time: "2小时 15分钟" }
        ListElement { name: "Chrome"; time: "1小时 42分钟" }
        ListElement { name: "VSCode"; time: "3小时 08分钟" }
    }

    ListModel {
        id: projectModel
        ListElement { name: "高数复习"; time: "1小时 20分钟"; tag: "学习" }
        ListElement { name: "健身"; time: "42分钟"; tag: "运动" }
        ListElement { name: "读书"; time: "35分钟"; tag: "学习" }
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

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

            Row {
                width: parent.width
                spacing: 20

                Column {
                    spacing: 6

                    Text {
                        text: "首页"
                        color: textPrimary
                        font.pixelSize: 42
                        font.bold: true
                    }

                    Text {
                        text: "今天也慢慢记录自己的时间轨迹。"
                        color: textSecondary
                        font.pixelSize: 16
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 390
                radius: 30
                color: panelColor
                border.width: 1
                border.color: borderColor

                Row {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 24

                    Column {
                        width: 240
                        spacing: 12

                        Text {
                            text: "项目分布"
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            text: "圆环按自定义项目的标签总时长比例展示。"
                            color: textSecondary
                            font.pixelSize: 15
                            wrapMode: Text.Wrap
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 70
                            radius: 18
                            color: cardColor
                            border.width: 1
                            border.color: softBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: accentPurple
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "学习  " + minutesToDisplay(studyMinutes)
                                    color: textPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 70
                            radius: 18
                            color: cardColor
                            border.width: 1
                            border.color: softBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: accentGreen
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "运动  " + minutesToDisplay(sportMinutes)
                                    color: textPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 70
                            radius: 18
                            color: cardColor
                            border.width: 1
                            border.color: softBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: accentOrange
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "游戏  " + minutesToDisplay(gameMinutes)
                                    color: textPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
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
                                var gap = 0.06

                                function drawArc(startAngle, spanAngle, color) {
                                    if (spanAngle <= 0)
                                        return
                                    ctx.beginPath()
                                    ctx.strokeStyle = color
                                    ctx.lineWidth = lineWidth
                                    ctx.lineCap = "round"
                                    ctx.arc(cx, cy, radius, startAngle, startAngle + spanAngle, false)
                                    ctx.stroke()
                                }

                                ctx.beginPath()
                                ctx.strokeStyle = "#EFE7DD"
                                ctx.lineWidth = lineWidth
                                ctx.arc(cx, cy, radius, 0, Math.PI * 2, false)
                                ctx.stroke()

                                var total = Math.PI * 2
                                var start = -Math.PI / 2

                                var studyAngle = total * studyMinutes / totalProjectMinutes
                                var sportAngle = total * sportMinutes / totalProjectMinutes
                                var gameAngle = total * gameMinutes / totalProjectMinutes

                                if (studyMinutes > 0) {
                                    drawArc(start, Math.max(0, studyAngle - gap), accentPurple)
                                    start += studyAngle
                                }
                                if (sportMinutes > 0) {
                                    drawArc(start, Math.max(0, sportAngle - gap), accentGreen)
                                    start += sportAngle
                                }
                                if (gameMinutes > 0) {
                                    drawArc(start, Math.max(0, gameAngle - gap), accentOrange)
                                }
                            }

                            Connections {
                                target: projectModel
                                function onCountChanged() { ringCanvas.requestPaint() }
                            }
                        }

                        Rectangle {
                            width: 162
                            height: 162
                            radius: 81
                            color: cardColor
                            anchors.centerIn: ringCanvas

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: minutesToDisplay(studyMinutes + sportMinutes + gameMinutes)
                                    color: textPrimary
                                    font.pixelSize: 30
                                    font.bold: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "项目累计"
                                    color: textSecondary
                                    font.pixelSize: 14
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: listRowHeight
                spacing: 18

                Rectangle {
                    width: (parent.width - 18) / 2
                    height: softwareCardHeight
                    radius: 30
                    color: panelColor
                    border.width: 1
                    border.color: borderColor

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        Text {
                            text: "软件使用时长"
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Repeater {
                            model: softwareModel

                            delegate: Rectangle {
                                width: parent.width
                                height: 72
                                radius: 20
                                color: cardColor
                                border.width: 1
                                border.color: softBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: accentOrange
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: model.name
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

                                    Item {
                                        width: 1
                                        height: 1
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.time
                                        color: accentBrownDeep
                                        font.pixelSize: 17
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 2
                    height: projectCardHeight
                    radius: 30
                    color: panelColor
                    border.width: 1
                    border.color: borderColor

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

                        Repeater {
                            model: projectModel

                            delegate: Rectangle {
                                width: parent.width
                                height: 78
                                radius: 20
                                color: cardColor
                                border.width: 1
                                border.color: softBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: model.tag === "学习" ? accentPurple :
                                               model.tag === "运动" ? accentGreen :
                                               accentOrange
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: model.name
                                            color: textPrimary
                                            font.pixelSize: 17
                                            font.bold: true
                                        }

                                        Text {
                                            text: "标签：" + model.tag
                                            color: textSecondary
                                            font.pixelSize: 13
                                        }
                                    }

                                    Item {
                                        width: 1
                                        height: 1
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.time
                                        color: accentBrownDeep
                                        font.pixelSize: 16
                                        font.bold: true
                                    }

                                    Rectangle {
                                        width: 84
                                        height: 40
                                        radius: 16
                                        color: "#E8C6A3"
                                        border.width: 1
                                        border.color: "#DBB18A"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "开始"
                                            color: "#6A4C3B"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: startProject(model.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 220
                radius: 30
                color: panelColor
                border.width: 1
                border.color: borderColor

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    Text {
                        text: "更多记录"
                        color: textPrimary
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Text {
                        text: "这里以后可以继续放每周趋势、项目统计、最近完成项目。"
                        color: textSecondary
                        font.pixelSize: 15
                    }
                }
            }
        }
    }

    Rectangle {
        id: addButton
        width: 68
        height: 68
        radius: 34
        color: accentBrown
        border.width: 1
        border.color: "#CDA57D"
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
            onClicked: addMenu.open()
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
        anchors.centerIn: parent
        width: 380
        height: 300
        padding: 20

        background: Rectangle {
            radius: 24
            color: "#FBF7F2"
            border.width: 1
            border.color: borderColor
        }

        Column {
            anchors.fill: parent
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
                    model: ["学习", "运动", "游戏"]
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
                        if (nameText.length > 0) {
                            projectModel.append({
                                "name": nameText,
                                "time": "0分钟",
                                "tag": tagBox.currentText
                            })
                            saveProjects()
                            ringCanvas.requestPaint()
                            projectNameField.text = ""
                            tagBox.currentIndex = 0
                            addProjectDialog.close()
                        }
                    }
                }
            }
        }
    }

    onImportSoftware: {
        console.log("导入想查看时间的软件")
    }

    onStartProject: function(projectName) {
        console.log("开始计时项目:", projectName)
    }
}
