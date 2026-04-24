import QtQuick

Item {
    id: root

    property var theme
    property string title: ""
    property string timeRange: ""
    property string duration: ""
    property string iconText: ""
    property url iconSource: ""
    property color iconColor: theme ? theme.accentGreenSoft : "#CFE3D2"
    property real progress: 0.0

    implicitHeight: 54

    Row {
        anchors.fill: parent
        spacing: 12

        Text {
            width: 42
            text: root.timeRange
            color: root.theme ? root.theme.textMuted : "#93A297"
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }

        Rectangle {
            width: 34
            height: 34
            radius: 12
            color: root.iconColor
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: root.iconSource
                visible: root.iconSource.toString().length > 0
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.centerIn: parent
                text: root.iconText
                visible: root.iconSource.toString().length === 0
                color: root.theme ? root.theme.accentGreenDeep : "#4D8D73"
                font.pixelSize: 13
                font.bold: true
            }
        }

        Column {
            width: parent.width - 42 - 34 - 12 - 12 - 54
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                width: parent.width
                text: root.title
                color: root.theme ? root.theme.textPrimary : "#123A35"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: root.theme ? "#EAE1D2" : "#EAE1D2"

                Rectangle {
                    width: Math.max(8, parent.width * Math.max(0, Math.min(1, root.progress)))
                    height: parent.height
                    radius: parent.radius
                    color: root.theme ? root.theme.accentGreen : "#8FBEA3"
                    opacity: 0.72
                }
            }
        }

        Text {
            width: 54
            text: root.duration
            color: root.theme ? root.theme.accentGreenDeep : "#4D8D73"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }
    }
}
