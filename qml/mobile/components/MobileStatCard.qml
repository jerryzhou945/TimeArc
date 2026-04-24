import QtQuick

MobileSoftCard {
    id: root

    property string title: ""
    property string value: ""
    property string iconText: ""
    property color accentColor: theme ? theme.accentGreenSoft : "#CFE3D2"

    padding: 12
    radius: 18
    shadowOpacity: 0.07

    Row {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            width: 34
            height: 34
            radius: 12
            color: root.accentColor
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: root.iconText
                color: root.theme ? root.theme.accentGreenDeep : "#4D8D73"
                font.pixelSize: 13
                font.bold: true
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - 44

            Text {
                width: parent.width
                text: root.title
                color: root.theme ? root.theme.textMuted : "#93A297"
                font.pixelSize: root.theme ? root.theme.fontCaption : 12
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.value
                color: root.theme ? root.theme.textPrimary : "#123A35"
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideRight
            }
        }
    }
}
