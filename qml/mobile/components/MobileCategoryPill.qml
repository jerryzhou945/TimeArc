import QtQuick

Rectangle {
    id: root

    property var theme
    property string text: ""
    property string iconText: ""
    property bool selected: false

    signal clicked()

    implicitWidth: Math.max(72, content.implicitWidth + 26)
    implicitHeight: 38
    radius: height / 2
    color: selected ? (theme ? theme.accentGreen : "#8FBEA3") : (theme ? theme.panelGlass : "#FFFDF9")
    border.width: 1
    border.color: selected ? "transparent" : (theme ? theme.softStroke : "#EEE6D8")

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Text {
            visible: root.iconText.length > 0
            text: root.iconText
            color: selected ? "#FFFFFF" : (theme ? theme.accentGreenDeep : "#4D8D73")
            font.pixelSize: 12
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: selected ? "#FFFFFF" : (theme ? theme.textSecondary : "#6E8076")
            font.pixelSize: theme ? theme.fontCaption : 12
            font.bold: selected
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
