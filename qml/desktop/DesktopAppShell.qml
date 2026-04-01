import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import time_arc

Item {
    anchors.fill: parent

    property int selectedIndex: 0
    property bool sidebarCollapsed: false

    property var navItems: [
        { title: "首页", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/home.svg" },
        { title: "聊天", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/chat.svg" },
        { title: "日历", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/calendar.svg" },
        { title: "统计", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/stats.svg" },
        { title: "我的", icon: "file:///F:/TimeArc/time-arc/qml/assets/icons/user.svg" }
    ]

    Rectangle {
        anchors.fill: parent
        color: "#F6F1EA"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        Rectangle {
            id: sidebar
            Layout.preferredWidth: sidebarCollapsed ? 92 : 240
            Layout.fillHeight: true
            radius: 30
            color: "#FBF7F2"
            border.width: 1
            border.color: "#E8DDD1"

            Behavior on Layout.preferredWidth {
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
                            color: selectedIndex === index ? "#EFE1D0" : "transparent"
                            border.width: selectedIndex === index ? 1 : 0
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
                                    opacity: selectedIndex === index ? 1.0 : 0.72
                                }

                                Text {
                                    visible: !sidebarCollapsed
                                    text: modelData.title
                                    color: selectedIndex === index ? "#5E4030" : "#8E7562"
                                    font.pixelSize: 17
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: selectedIndex = index
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 1
                }

                Rectangle {
                    visible: !sidebarCollapsed
                    width: parent.width
                    height: 116
                    radius: 22
                    color: "#FFFDF9"
                    border.width: 1
                    border.color: "#ECE2D6"

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
            color: "#FBF7F2"
            border.width: 1
            border.color: "#E8DDD1"

            Loader {
                anchors.fill: parent
                anchors.margins: 22
                sourceComponent: {
                    if (selectedIndex === 0) return homePageComponent
                    if (selectedIndex === 1) return chatPageComponent
                    if (selectedIndex === 2) return calendarPageComponent
                    if (selectedIndex === 3) return statsPageComponent
                    return profilePageComponent
                }
            }

            Component {
                id: homePageComponent
                DesktopHomePage { }
            }

            Component {
                id: chatPageComponent

                Rectangle {
                    color: "#FBF7F2"

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: "聊天页"
                            color: "#6B4D3C"
                            font.pixelSize: 28
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "这里之后可以放聊天记录、AI 对话和提醒。"
                            color: "#9C806C"
                            font.pixelSize: 15
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Component {
                id: calendarPageComponent

                Rectangle {
                    color: "#FBF7F2"

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: "日历页"
                            color: "#6B4D3C"
                            font.pixelSize: 28
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "这里之后可以放每日记录、时间块和回顾。"
                            color: "#9C806C"
                            font.pixelSize: 15
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Component {
                id: statsPageComponent

                Rectangle {
                    color: "#FBF7F2"

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: "统计页"
                            color: "#6B4D3C"
                            font.pixelSize: 28
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "这里之后可以放周报、月报和标签统计。"
                            color: "#9C806C"
                            font.pixelSize: 15
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Component {
                id: profilePageComponent

                Rectangle {
                    color: "#FBF7F2"

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: "我的页"
                            color: "#6B4D3C"
                            font.pixelSize: 28
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "这里之后可以放个人资料、偏好设置和成就。"
                            color: "#9C806C"
                            font.pixelSize: 15
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }
}
