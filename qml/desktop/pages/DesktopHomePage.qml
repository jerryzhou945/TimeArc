import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    anchors.fill: parent

    signal importSoftware()
    signal startProject(string projectName)

    property color textPrimary: "#4E342E"
    property color textSecondary: "#9C806C"
    property color accentBrown: "#D8B38A"
    property color accentBrownDeep: "#A96F46"
    property color accentGreen: "#B9C98A"
    property color accentOrange: "#E5A85F"
    property color accentPurple: "#B9A4EF"

    property color panelColor: "#FFFDF9"
    property color cardColor: "#FFFDF9"
    property color borderColor: "#DDC9B5"
    property color softBorder: "#E6D6C5"

    function minutesToDisplay(minutes) {
        var h = Math.floor(minutes / 60)
        var m = minutes % 60
        return h + "h " + m + "m"
    }

    property int studyMinutes: projectManager ? projectManager.studyMinutes : 0
    property int sportMinutes: projectManager ? projectManager.sportMinutes : 0
    property int gameMinutes: projectManager ? projectManager.gameMinutes : 0
    property int totalProjectMinutes: projectManager ? Math.max(1, projectManager.totalProjectMinutes) : 1

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

            Rectangle {
                width: parent.width
                height: 390
                radius: 30
                color: "transparent"
                border.width: 2
                border.color: borderColor

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 29
                    color: panelColor
                    opacity: 0.44
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
                            color: "transparent"
                            border.width: 1
                            border.color: softBorder

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 17
                                color: cardColor
                                opacity: 0.68
                                z: -1
                            }

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
                            color: "transparent"
                            border.width: 1
                            border.color: softBorder

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 17
                                color: cardColor
                                opacity: 0.68
                                z: -1
                            }

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
                            color: "transparent"
                            border.width: 1
                            border.color: softBorder

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 17
                                color: cardColor
                                opacity: 0.68
                                z: -1
                            }

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
                                color: "#FFFDF9"
                                opacity: 0.86
                                z: -1
                            }

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
                height: 420
                spacing: 18

                Rectangle {
                    width: (parent.width - 18) / 2
                    height: parent.height
                    radius: 30
                    color: "transparent"
                    border.width: 2
                    border.color: borderColor

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 29
                        color: panelColor
                        opacity: 0.42
                        z: -1
                    }

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
                            model: [
                                { name: "微信", time: "2小时 15分钟" },
                                { name: "Chrome", time: "1小时 42分钟" },
                                { name: "VSCode", time: "3小时 08分钟" }
                            ]

                            delegate: Rectangle {
                                required property var modelData

                                width: parent.width
                                height: 72
                                radius: 20
                                color: "transparent"
                                border.width: 1
                                border.color: softBorder

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 19
                                    color: cardColor
                                    opacity: 0.68
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
                                        color: accentOrange
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

                Rectangle {
                    width: (parent.width - 18) / 2
                    height: parent.height
                    radius: 30
                    color: "transparent"
                    border.width: 2
                    border.color: borderColor

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 29
                        color: panelColor
                        opacity: 0.42
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

                        ListView {
                            width: parent.width
                            height: parent.height - 60
                            clip: true
                            spacing: 14
                            model: projectManager ? projectManager.projects : []

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 78
                                radius: 20
                                color: "transparent"
                                border.width: 1
                                border.color: softBorder

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 19
                                    color: cardColor
                                    opacity: 0.68
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
                                        color: modelData.tag === "学习" ? accentPurple :
                                               modelData.tag === "运动" ? accentGreen :
                                               accentOrange
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: modelData.name
                                            color: textPrimary
                                            font.pixelSize: 17
                                            font.bold: true
                                        }

                                        Text {
                                            text: "标签: " + modelData.tag
                                            color: textSecondary
                                            font.pixelSize: 13
                                        }
                                    }

                                    Item { width: 1; height: 1 }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.time
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
                                            onClicked: startProject(modelData.name)
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
                color: "transparent"
                border.width: 2
                border.color: borderColor

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 29
                    color: panelColor
                    opacity: 0.42
                    z: -1
                }

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
            color: "#FBF7F2"
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
