import QtQuick
import "PlatformCursor.js" as Cursor

Rectangle {
    id: root

    property string text: ""
    property string iconText: ""
    property color fillColor: "#1F1A17"
    property color hoverColor: "#332C27"
    property color strokeColor: "transparent"
    property int strokeWidth: 0
    property color textColor: "#FFFDF9"
    property int fontSize: 14
    property bool bold: true
    property bool enabledButton: true

    signal clicked()

    implicitWidth: Math.max(96, buttonRow.implicitWidth + 30)
    implicitHeight: 44
    radius: 16
    color: enabledButton && mouseArea.containsMouse ? hoverColor : fillColor
    border.width: strokeWidth
    border.color: strokeColor
    opacity: enabledButton ? 1.0 : 0.52

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    Row {
        id: buttonRow
        anchors.centerIn: parent
        spacing: root.iconText.length > 0 ? 8 : 0

        Text {
            visible: root.iconText.length > 0
            text: root.iconText
            color: root.textColor
            font.pixelSize: root.fontSize
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root.textColor
            font.pixelSize: root.fontSize
            font.bold: root.bold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledButton
        cursorShape: Cursor.button()
        onClicked: root.clicked()
    }
}
