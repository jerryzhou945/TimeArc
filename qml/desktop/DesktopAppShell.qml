import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import time_arc

Item {
    anchors.fill: parent

    property int selectedIndex: 0
    property bool sidebarCollapsed: false
    property bool showingTimerPage: false

    property string appBackgroundSource: "file:///F:/TimeArc/time-arc/qml/assets/background.png"

    property var navItems: [
        { title: "首页", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/home.svg" },
        { title: "聊天", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/chat.svg" },
        { title: "记忆湖", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/home.svg" },
        { title: "日历", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/calendar.svg" },
        { title: "统计", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/stats.svg" },
        { title: "我的", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/user.svg" }
    ]

    property string currentPageSource: {
        if (showingTimerPage)
            return Qt.resolvedUrl("pages/DesktopTimerPage.qml")

        if (selectedIndex === 0)
            return Qt.resolvedUrl("pages/DesktopHomePage.qml")
        if (selectedIndex === 1)
            return Qt.resolvedUrl("pages/DesktopChatPage.qml")

        return ""
    }

    Item {
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: appBackgroundSource
            fillMode: Image.PreserveAspectCrop
            opacity: 0.48
            smooth: false
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F6F1EA" }
                GradientStop { position: 1.0; color: "#F3EEE5" }
            }
            opacity: 0.20
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        Rectangle {
            id: sidebar
            width: sidebarCollapsed ? 92 : 240
            Layout.preferredWidth: width
            Layout.fillHeight: true
            radius: 30
            color: "transparent"
            border.width: 2
            border.color: "#D8C2AC"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: "#FFFDF9"
                opacity: 0.68
                z: -1
            }

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Row {
                    width: parent.width
                    height: 60
                    spacing: 12

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: "#E8C6A3"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "T"
                            color: "#6A4C3B"
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }

                    Text {
                        visible: !sidebarCollapsed
                        text: "TimeArc"
                        color: "#4E342E"
                        font.pixelSize: 24
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 16
                    color: "#F4ECE2"
                    border.width: 1
                    border.color: "#E6D7C7"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 15
                        color: "#FFFFFF"
                        opacity: 0.18
                        z: -1
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: sidebarCollapsed ? "»" : "«"
                            color: "#8A654C"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            visible: !sidebarCollapsed
                            text: "收起侧栏"
                            color: "#6B4D3C"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebarCollapsed = !sidebarCollapsed
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: navItems

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            width: parent.width
                            height: 58
                            radius: 18
                            color: selectedIndex === index && !showingTimerPage ? "#EFE1D0" : "transparent"
                            border.width: selectedIndex === index && !showingTimerPage ? 1 : 0
                            border.color: "#DFCBB5"

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: sidebarCollapsed ? undefined : parent.left
                                anchors.leftMargin: sidebarCollapsed ? 0 : 18
                                anchors.horizontalCenter: sidebarCollapsed ? parent.horizontalCenter : undefined
                                spacing: 14

                                Image {
                                    source: modelData.icon
                                    width: 22
                                    height: 22
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: selectedIndex === index && !showingTimerPage ? 1.0 : 0.72
                                }

                                Text {
                                    visible: !sidebarCollapsed
                                    text: modelData.title
                                    color: selectedIndex === index && !showingTimerPage ? "#5E4030" : "#8E7562"
                                    font.pixelSize: 17
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    showingTimerPage = false
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    Layout.fillHeight: true
                }

                Rectangle {
                    visible: !sidebarCollapsed
                    width: parent.width
                    height: 116
                    radius: 22
                    color: "#FFFDF9"
                    border.width: 1
                    border.color: "#ECE2D6"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 21
                        color: "#FFFFFF"
                        opacity: 0.14
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Text {
                            text: "记忆湖陪伴"
                            color: "#5E4030"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: "第 12 天"
                            color: "#A96F46"
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: "慢慢积累，也很好。"
                            color: "#9C806C"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        Rectangle {
            id: contentPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 34
            color: "transparent"
            border.width: 2
            border.color: "#D8C2AC"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 33
                color: "#FFFDF9"
                opacity: 0.46
                z: -1
            }

            Loader {
                id: pageLoader
                anchors.fill: parent
                anchors.margins: 22
                source: currentPageSource

                property var _homeStartProjectConnection: null
                property var _homeImportConnection: null

                onLoaded: {
                    console.log("Loader loaded:", source)

                    if (!item)
                        return

                    if (showingTimerPage)
                        return

                    if (selectedIndex === 0 && item.startProject) {
                        item.startProject.connect(function(projectName) {
                            console.log("startProject signal received:", projectName)
                            if (timerManager) {
                                timerManager.startProject(projectName)
                                showingTimerPage = true
                            }
                        })
                    }

                    if (selectedIndex === 0 && item.importSoftware) {
                        item.importSoftware.connect(function() {
                            console.log("导入想查看时间的软件")
                        })
                    }
                }

                onStatusChanged: {
                    console.log("Loader status:", status, "source:", source)
                }
            }

            Item {
                anchors.fill: parent
                visible: selectedIndex === 3 && !showingTimerPage

                Text {
                    anchors.centerIn: parent
                    text: "日历页"
                    color: "#6B4D3C"
                    font.pixelSize: 28
                    font.bold: true
                }
            }

            Item {
                anchors.fill: parent
                visible: selectedIndex === 4 && !showingTimerPage

                Text {
                    anchors.centerIn: parent
                    text: "统计页"
                    color: "#6B4D3C"
                    font.pixelSize: 28
                    font.bold: true
                }
            }

            Item {
                anchors.fill: parent
                visible: selectedIndex === 5 && !showingTimerPage

                Text {
                    anchors.centerIn: parent
                    text: "我的页"
                    color: "#6B4D3C"
                    font.pixelSize: 28
                    font.bold: true
                }
            }
        }
    }

    Connections {
        target: timerManager

        function onTimerStopped(projectName, elapsedSeconds) {
            if (projectManager)
                projectManager.addElapsedTime(projectName, elapsedSeconds)

            showingTimerPage = false
            selectedIndex = 0
        }
    }
}
