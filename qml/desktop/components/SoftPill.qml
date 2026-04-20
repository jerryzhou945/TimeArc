import QtQuick

Rectangle {
    id: root

    property string title: ""
    property string value: ""
    property string iconText: ""
    property color fillColor: "#FBF8F4"
    property color strokeColor: "#E8E0D8"
    property color titleColor: "#7C746D"
    property color valueColor: "#2D2724"
    property color accentColor: "#CFE8D8"
    property bool compact: false

    implicitWidth: contentRow.implicitWidth + (compact ? 22 : 28)
    implicitHeight: compact ? 38 : 48
    radius: height / 2
    color: fillColor
    border.width: 1
    border.color: strokeColor

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: compact ? 8 : 10

        Rectangle {
            visible: root.iconText.length > 0
            width: compact ? 22 : 26
            height: width
            radius: width / 2
            color: root.accentColor
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: root.iconText
                color: root.valueColor
                font.pixelSize: compact ? 11 : 13
                font.bold: true
            }
        }

        Column {
            visible: root.title.length > 0
            spacing: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.title
                color: root.titleColor
                font.pixelSize: compact ? 10 : 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                text: root.value
                color: root.valueColor
                font.pixelSize: compact ? 12 : 14
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Text {
            visible: root.title.length === 0
            text: root.value
            color: root.valueColor
            font.pixelSize: compact ? 12 : 14
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
