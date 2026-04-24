import QtQuick

MobileSoftCard {
    id: root

    property string projectName: ""
    property string tag: ""
    property string timeText: "今日 0m"
    property string iconText: theme ? theme.tagIcon(tag) : "•"

    signal startRequested(string name, string tag)
    signal openRequested(string name, string tag)

    height: 86
    padding: 14
    shadowOpacity: 0.08

    Row {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            width: 42
            height: 42
            radius: 15
            color: root.theme ? root.theme.tagColor(root.tag) : "#CFE3D2"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: root.iconText
                color: root.theme ? root.theme.textPrimary : "#123A35"
                font.pixelSize: 15
                font.bold: true
            }
        }

        Column {
            width: parent.width - 42 - 12 - 92
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: root.projectName
                color: root.theme ? root.theme.textPrimary : "#123A35"
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.timeText
                color: root.theme ? root.theme.textSecondary : "#6E8076"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        MobileGradientButton {
            theme: root.theme
            width: 76
            height: 42
            text: "开始"
            fontSize: 14
            fromColor: root.theme ? root.theme.accentGreen : "#8FBEA3"
            toColor: root.theme ? root.theme.projectButtonEnd : "#BDD58B"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.startRequested(root.projectName, root.tag)
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 92
        onClicked: root.openRequested(root.projectName, root.tag)
    }
}
