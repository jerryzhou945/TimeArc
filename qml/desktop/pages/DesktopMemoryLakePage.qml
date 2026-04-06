import QtQuick
import QtQuick.Controls

Item {
    anchors.fill: parent

    property bool nightMode: false
    property color themeTextPrimary: "#4E342E"
    property color themeTextSecondary: "#9C806C"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#DDC9B5"
    property color themeAccentColor: "#E8C6A3"

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
            opacity: nightMode ? 0.62 : 0.72
            z: -1
        }
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../../../resources/memorylake/memory_bg.png")
        fillMode: Image.PreserveAspectCrop
        opacity: nightMode ? 0.28 : 0.20
        asynchronous: true
    }

    Column {
        anchors.centerIn: parent
        spacing: 14

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "记忆湖"
            color: themeTextPrimary
            font.pixelSize: 42
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "这里会展示你的记忆卡片与沉淀内容。"
            color: themeTextSecondary
            font.pixelSize: 16
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Image {
                width: 120
                height: 120
                source: Qt.resolvedUrl("../../../resources/memorylake/memory_cat_1.png")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Image {
                width: 120
                height: 120
                source: Qt.resolvedUrl("../../../resources/memorylake/memory_tree.png")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Image {
                width: 120
                height: 120
                source: Qt.resolvedUrl("../../../resources/memorylake/memory_pond_rocks.png")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        Rectangle {
            width: 280
            height: 48
            radius: 16
            color: themeAccentColor
            border.width: 1
            border.color: nightMode ? "#757ED0" : "#D6B08B"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "功能开发中"
                color: nightMode ? "#F8F7FF" : "#6A4C3B"
                font.pixelSize: 16
                font.bold: true
            }
        }
    }
}
