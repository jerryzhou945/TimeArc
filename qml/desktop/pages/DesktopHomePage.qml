import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Item {
    anchors.fill: parent

    signal importSoftware()
    signal startProject(string projectName)

    property int projectItemHeight: 92
    property int projectCardTopPadding: 70
    property int projectCardBottomPadding: 24
    property int projectCardHeight: projectCardTopPadding + projectCardBottomPadding + projectModel.count * projectItemHeight

    property int softwareItemHeight: 86
    property int softwareCardTopPadding: 70
    property int softwareCardBottomPadding: 24
    property int softwareCardHeight: softwareCardTopPadding + softwareCardBottomPadding + softwareModel.count * softwareItemHeight

    property int listRowHeight: Math.max(softwareCardHeight, projectCardHeight)

    Settings {
        id: appSettings
        category: "HomePageData"
        property string savedProjects: ""
    }

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
        color: "#f7f1e8"
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
            spacing: 20

            Rectangle {
                width: parent.width
                height: headerSection.implicitHeight
                        + overviewSection.height
                        + listSection.height
                        + 100
                radius: 28
                color: "#fbf6ef"
                border.width: 1
                border.color: "#eadfce"

                Column {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 20

                    Row {
                        id: headerSection
                        width: parent.width
                        spacing: 16

                        Column {
                            spacing: 6

                            Text {
                                text: "首页"
                                color: "#5f4631"
                                font.pixelSize: 34
                                font.bold: true
                            }

                            Text {
                                text: "今天也慢慢记录自己的时间轨迹。"
                                color: "#9a7d63"
                                font.pixelSize: 15
                            }
                        }

                        Item {
                            width: parent.width - 420
                            height: 1
                        }

                        Rectangle {
                            width: 200
                            height: 48
                            radius: 16
                            color: "#f4e8d8"
                            border.width: 1
                            border.color: "#e2d2bc"

                            Text {
                                anchors.centerIn: parent
                                text: "今日总时长：7小时 40分钟"
                                color: "#7a573d"
                                font.pixelSize: 15
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        id: overviewSection
                        width: parent.width
                        height: 180
                        radius: 22
                        color: "#f8efe2"
                        border.width: 1
                        border.color: "#e2d2bc"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 0

                            Column {
                                id: overviewHeader
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "今日概览"
                                    color: "#5f4631"
                                    font.pixelSize: 20
                                    font.bold: true
                                }

                                Text {
                                    text: "软件使用 + 自定义项目"
                                    color: "#9a7d63"
                                    font.pixelSize: 14
                                }
                            }

                            Item {
                                width: parent.width
                                height: parent.height - overviewHeader.height - 60

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 120
                                    height: 120
                                    radius: 60
                                    color: "#fffaf4"
                                    border.width: 8
                                    border.color: "#d8b38a"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "7h 40m"
                                            color: "#7a573d"
                                            font.pixelSize: 24
                                            font.bold: true
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        Text {
                                            text: "今日累计"
                                            color: "#a08369"
                                            font.pixelSize: 13
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        id: listSection
                        width: parent.width
                        height: listRowHeight
                        spacing: 18

                        Rectangle {
                            width: (parent.width - 18) / 2
                            height: softwareCardHeight
                            radius: 22
                            color: "#f8efe2"
                            border.width: 1
                            border.color: "#e2d2bc"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                Text {
                                    text: "软件使用时长"
                                    color: "#5f4631"
                                    font.pixelSize: 22
                                    font.bold: true
                                }

                                Repeater {
                                    model: softwareModel

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 72
                                        radius: 18
                                        color: "#fffaf4"
                                        border.width: 1
                                        border.color: "#eadfce"

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 16
                                            spacing: 12

                                            Rectangle {
                                                width: 12
                                                height: 12
                                                radius: 6
                                                color: "#d39b6a"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: model.name
                                                    color: "#5f4631"
                                                    font.pixelSize: 16
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: "自动记录"
                                                    color: "#a08369"
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
                                                color: "#7a573d"
                                                font.pixelSize: 15
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
                            radius: 22
                            color: "#f8efe2"
                            border.width: 1
                            border.color: "#e2d2bc"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                Text {
                                    text: "自定义项目"
                                    color: "#5f4631"
                                    font.pixelSize: 22
                                    font.bold: true
                                }

                                Repeater {
                                    model: projectModel

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 78
                                        radius: 18
                                        color: "#fffaf4"
                                        border.width: 1
                                        border.color: "#eadfce"

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 16
                                            spacing: 12

                                            Rectangle {
                                                width: 12
                                                height: 12
                                                radius: 6
                                                color: "#c67d53"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: model.name
                                                    color: "#5f4631"
                                                    font.pixelSize: 16
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: "标签：" + model.tag
                                                    color: "#a08369"
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
                                                color: "#7a573d"
                                                font.pixelSize: 15
                                                font.bold: true
                                            }

                                            Rectangle {
                                                width: 70
                                                height: 36
                                                radius: 12
                                                color: "#e9c9a8"
                                                border.width: 1
                                                border.color: "#d8b38a"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "开始"
                                                    color: "#6b4a34"
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
                }
            }

            Rectangle {
                width: parent.width
                height: 260
                radius: 28
                color: "#fbf6ef"
                border.width: 1
                border.color: "#eadfce"

                Column {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 16

                    Text {
                        text: "更多记录"
                        color: "#5f4631"
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Text {
                        text: "这里以后可以继续放每周趋势、标签统计、最近完成项目。"
                        color: "#9a7d63"
                        font.pixelSize: 15
                    }

                    Text {
                        text: "现在这个区域主要用来测试页面滚动。"
                        color: "#9a7d63"
                        font.pixelSize: 15
                    }
                }
            }
        }
    }

    Rectangle {
        id: reminderPanel
        width: 260
        height: 220
        radius: 22
        color: "#f8efe2"
        border.width: 1
        border.color: "#e2d2bc"
        z: 20

        anchors.top: parent.top
        anchors.topMargin: 110

        property bool expanded: false

        x: expanded ? parent.width - width - 18 : parent.width - 36

        Behavior on x {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            Text {
                text: "温馨提醒"
                color: "#5f4631"
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                text: "• 可以添加自定义项目开始计时"
                color: "#8e745d"
                font.pixelSize: 14
            }

            Text {
                text: "• 也可以导入想观察时长的软件"
                color: "#8e745d"
                font.pixelSize: 14
            }

            Text {
                text: "• 结束计时后会自动回到首页"
                color: "#8e745d"
                font.pixelSize: 14
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: reminderPanel.expanded = true
            onExited: reminderPanel.expanded = false
        }
    }

    Rectangle {
        id: addButton
        width: 64
        height: 64
        radius: 32
        color: "#d8b38a"
        border.width: 1
        border.color: "#c89a6e"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 28
        z: 30

        Text {
            anchors.centerIn: parent
            text: "+"
            color: "#fffaf4"
            font.pixelSize: 30
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
        width: 360
        height: 280
        padding: 20

        background: Rectangle {
            radius: 20
            color: "#fbf6ef"
            border.width: 1
            border.color: "#e2d2bc"
        }

        Column {
            anchors.fill: parent
            spacing: 16

            Text {
                text: "添加自定义项目"
                color: "#5f4631"
                font.pixelSize: 24
                font.bold: true
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "项目名称"
                    color: "#7a573d"
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
                    color: "#7a573d"
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
                height: 10
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
