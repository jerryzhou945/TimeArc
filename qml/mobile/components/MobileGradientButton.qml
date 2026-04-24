import QtQuick

Rectangle {
    id: root

    property var theme
    property string text: ""
    property string iconText: ""
    property int fontSize: theme ? theme.fontBody : 14
    property bool bold: true
    property bool enabledButton: true
    property color fromColor: theme ? theme.accentGreen : "#8FBEA3"
    property color toColor: theme ? theme.accentYellow : "#E7D98F"
    property color textColor: theme ? theme.onAccent : "#FFFFFF"

    signal clicked()

    implicitHeight: 48
    implicitWidth: Math.max(116, labelRow.implicitWidth + 34)
    radius: height / 2
    opacity: enabledButton ? 1.0 : 0.48

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.fromColor }
        GradientStop { position: 1.0; color: root.toColor }
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 6
        radius: parent.radius
        color: root.theme ? root.theme.shadow : "#A89372"
        opacity: 0.14
        z: -1
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: root.iconText.length > 0 ? 8 : 0

        Text {
            visible: root.iconText.length > 0
            text: root.iconText
            color: root.textColor
            font.pixelSize: root.fontSize + 1
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
        anchors.fill: parent
        enabled: root.enabledButton
        onClicked: root.clicked()
    }
}
