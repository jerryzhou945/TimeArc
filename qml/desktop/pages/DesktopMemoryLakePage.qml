import QtQuick
import QtQuick.Controls

Item {
    id: root

    anchors.fill: parent

    property bool nightMode: false
    property color themeTextPrimary: "#4E342E"
    property color themeTextSecondary: "#9C806C"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#D8C2AC"
    property color themeAccentColor: "#E8C6A3"
    property int hotSpringFrame: 0
    readonly property int hotSpringFrameInterval: 240
    readonly property var hotSpringFrames: [
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_01.png"),
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_02.png"),
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_03.png"),
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_04.png"),
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_05.png"),
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_06.png"),
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_07.png"),
        Qt.resolvedUrl("../../../resources/memorylake/hotspring_08.png")
    ]

    Timer {
        interval: root.hotSpringFrameInterval
        repeat: true
        running: true
        onTriggered: root.hotSpringFrame = (root.hotSpringFrame + 1) % root.hotSpringFrames.length
    }

    Rectangle {
        anchors.fill: parent
        radius: 30
        color: "transparent"
        border.width: 1
        border.color: nightMode ? "#6D7668" : "#D9CEB9"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 29
            opacity: nightMode ? 0.74 : 0.90
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: nightMode ? "#23302C" : "#FFF2C9" }
                GradientStop { position: 0.46; color: nightMode ? "#273A31" : "#DCD6B5" }
                GradientStop { position: 1.0; color: nightMode ? "#1A2A26" : "#A8D5BA" }
            }
            z: -1
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 29
        color: "transparent"
        opacity: nightMode ? 0.16 : 0.24
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#7ACB73" }
            GradientStop { position: 0.55; color: "#D4CFA9" }
            GradientStop { position: 1.0; color: "#FFC7D8" }
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 96, 720)
        spacing: 18

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "记忆湖"
            color: nightMode ? "#F6F2DD" : themeTextPrimary
            font.pixelSize: 40
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "温泉正在慢慢冒热气，替你保存今天的时间温度。"
            color: nightMode ? "#C9D5C9" : themeTextSecondary
            font.pixelSize: 16
        }

        Rectangle {
            width: parent.width
            height: Math.min(520, root.height - 260)
            radius: 34
            color: nightMode ? "#22352F" : "#FFF8E8"
            opacity: nightMode ? 0.88 : 0.78
            border.width: 1
            border.color: nightMode ? "#55695F" : "#EFE2C7"
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 33
                color: "transparent"
                opacity: 0.45
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#FFFFFF" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Image {
                id: hotSpringImage
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 560)
                height: parent.height - 42
                source: root.hotSpringFrames[root.hotSpringFrame]
                fillMode: Image.PreserveAspectFit
                asynchronous: false
                smooth: true
            }

            Rectangle {
                width: 248
                height: 46
                radius: 23
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                opacity: 0.84
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#75C46F" }
                    GradientStop { position: 0.55; color: "#D8D3A8" }
                    GradientStop { position: 1.0; color: "#FFC7D8" }
                }

                Text {
                    anchors.centerIn: parent
                    text: "温泉动效 · 8 帧循环"
                    color: "#FFFFFF"
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }
    }
}
