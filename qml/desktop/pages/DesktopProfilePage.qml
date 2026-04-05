import QtQuick
import QtQuick.Controls

Item {
    anchors.fill: parent

    signal nightModeToggled(bool enabled)

    property bool nightMode: false
    property color themeTextPrimary: nightMode ? "#F3E7DA" : "#4E342E"
    property color themeTextSecondary: nightMode ? "#C8B7AA" : "#9C806C"
    property color themePanelColor: nightMode ? "#4A3D37" : "#FFFDF9"
    property color themeBorderColor: nightMode ? "#6B5A51" : "#DDC9B5"
    property color themeAccentColor: nightMode ? "#C9976B" : "#E8C6A3"

    Rectangle {
        anchors.fill: parent
        radius: 30
        color: "transparent"
        border.width: 2
        border.color: themeBorderColor

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 29
            color: themePanelColor
            opacity: nightMode ? 0.82 : 0.62
            z: -1
        }
    }

    Column {
        anchors.centerIn: parent
        width: 420
        spacing: 26

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "我的"
            color: themeTextPrimary
            font.pixelSize: 36
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 180
            radius: 26
            color: "transparent"
            border.width: 1
            border.color: themeBorderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 25
                color: themePanelColor
                opacity: nightMode ? 0.78 : 0.68
                z: -1
            }

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                Text {
                    text: "深色模式"
                    color: themeTextPrimary
                    font.pixelSize: 26
                    font.bold: true
                }

                Text {
                    text: nightMode
                          ? "当前已开启夜晚主题，背景和整体组件颜色会切换。"
                          : "当前为白天主题，点击右侧开关可切换到夜晚主题。"
                    color: themeTextSecondary
                    font.pixelSize: 15
                    wrapMode: Text.Wrap
                    width: parent.width
                }

                Row {
                    spacing: 18

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: nightMode ? "开启" : "关闭"
                        color: nightMode ? "#86D38E" : "#E06A6A"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Rectangle {
                        id: switchTrack
                        width: 86
                        height: 42
                        radius: 21
                        color: nightMode ? "#69C36F" : "#D96C6C"
                        border.width: 1
                        border.color: nightMode ? "#5CAA62" : "#C65A5A"

                        Behavior on color {
                            ColorAnimation { duration: 180 }
                        }

                        Rectangle {
                            id: switchKnob
                            width: 34
                            height: 34
                            radius: 17
                            y: 4
                            x: nightMode ? 48 : 4
                            color: "#FFFDF9"
                            border.width: 1
                            border.color: "#D8CFC7"

                            Behavior on x {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                nightMode = !nightMode
                                nightModeToggled(nightMode)
                            }
                        }
                    }
                }
            }
        }
    }
}
