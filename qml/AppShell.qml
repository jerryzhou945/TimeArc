import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    anchors.fill: parent

    property int selectedIndex: 0

    Rectangle {
        anchors.fill: parent
        color: "#0f1117"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            color: "#151a23"

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18

                Rectangle {
                    width: parent.width
                    height: 72
                    radius: 18
                    color: "#1b2230"

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        spacing: 4

                        Text {
                            text: "TimeArc"
                            color: "white"
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: "Track your time beautifully"
                            color: "#8b95a7"
                            font.pixelSize: 13
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: [
                            { title: "Dashboard", icon: "◉" },
                            { title: "Tasks", icon: "≡" },
                            { title: "Statistics", icon: "▣" },
                            { title: "Settings", icon: "⚙" }
                        ]

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            width: parent.width
                            height: 54
                            radius: 14
                            color: selectedIndex === index ? "#232c3d" : "transparent"
                            border.width: selectedIndex === index ? 1 : 0
                            border.color: "#2f3b52"

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                spacing: 14

                                Text {
                                    text: modelData.icon
                                    color: selectedIndex === index ? "#7cc7ff" : "#9aa4b2"
                                    font.pixelSize: 18
                                }

                                Text {
                                    text: modelData.title
                                    color: selectedIndex === index ? "white" : "#c1c8d4"
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
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0f1117"

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: "AppShell Loaded"
                    color: "white"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Your sidebar is working."
                    color: "#8b95a7"
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Selected tab: " + selectedIndex
                    color: "#7cc7ff"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
