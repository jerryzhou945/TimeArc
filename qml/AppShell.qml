import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
                            text: "时迹 TimeArc"
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
                            { title: "仪表盘", icon: "◉" },
                            { title: "任务", icon: "≡" },
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

            Column {
                anchors.centerIn: parent
                spacing: 18

                Text {
                    text: "欢迎来到时迹"
                    color: "#5f4631"
                    font.pixelSize: 34
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "左侧导航已经可以点击了。"
                    color: "#8e745d"
                    font.pixelSize: 17
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 220
                    height: 56
                    radius: 18
                    color: "#f2e5d3"
                    border.width: 1
                    border.color: "#dcc7ad"
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "当前页面：" + ["仪表盘", "任务", "统计", "设置"][selectedIndex]
                        color: "#7a573d"
                        font.pixelSize: 16
                        font.bold: true
                    }
                }
            }
        }
    }
}
