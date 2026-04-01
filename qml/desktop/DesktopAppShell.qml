import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import time_arc

Item {
    anchors.fill: parent

    property int selectedIndex: 0

    Rectangle {
        anchors.fill: parent
        color: "#f7f1e8"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: "#efe4d3"

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18

                Rectangle {
                    width: parent.width
                    height: 84
                    radius: 22
                    color: "#f8efe2"
                    border.width: 1
                    border.color: "#e2d2bc"

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        spacing: 6

                        Text {
                            text: "记忆湖 TimeArc"
                            color: "#5f4631"
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: "用温柔的方式记录时间"
                            color: "#9a7d63"
                            font.pixelSize: 13
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: [
                            { title: "首页", icon: "◉" },
                            { title: "统计", icon: "▣" },
                            { title: "设置", icon: "⚙" }
                        ]

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            width: parent.width
                            height: 56
                            radius: 16
                            color: selectedIndex === index ? "#e8d7c0" : "transparent"
                            border.width: selectedIndex === index ? 1 : 0
                            border.color: "#d6c1a7"

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                spacing: 14

                                Text {
                                    text: modelData.icon
                                    color: selectedIndex === index ? "#a66a3f" : "#9f8a76"
                                    font.pixelSize: 18
                                }

                                Text {
                                    text: modelData.title
                                    color: selectedIndex === index ? "#5c4330" : "#7d6753"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: selectedIndex = index
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Rectangle {
                    width: parent.width
                    height: 120
                    radius: 20
                    color: "#f8efe2"
                    border.width: 1
                    border.color: "#e2d2bc"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Text {
                            text: "今日时光"
                            color: "#5f4631"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            text: "3小时 24分钟"
                            color: "#b06f42"
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: "慢一点，也是在前进。"
                            color: "#9a7d63"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#f7f1e8"

            Loader {
                anchors.fill: parent
                anchors.margins: 24
                sourceComponent: selectedIndex === 0 ? homePageComponent : placeholderComponent
            }

            Component {
                id: homePageComponent
                DesktopHomePage { }
            }

            Component {
                id: placeholderComponent

                Rectangle {
                    color: "#f7f1e8"

                    Text {
                        anchors.centerIn: parent
                        text: "这个页面还在制作中"
                        color: "#8e745d"
                        font.pixelSize: 24
                    }
                }
            }
        }
    }
}
