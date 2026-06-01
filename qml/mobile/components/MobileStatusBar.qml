import QtQuick

Item {
    id: root

    required property var theme

    height: 30

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: "9:41"
        color: root.theme.textMuted
        font.pixelSize: 12
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 15
        height: 8
        radius: 2
        color: "transparent"
        border.color: root.theme.textMuted
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 1
            color: root.theme.green
        }
    }
}
