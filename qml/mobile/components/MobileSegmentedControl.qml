import QtQuick

Rectangle {
    id: root

    property var theme
    property var options: []
    property int currentIndex: 0

    signal changed(int index)

    implicitHeight: 38
    radius: height / 2
    color: theme ? theme.segmentedTrack : "#EFE8DA"

    Row {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.options

            Rectangle {
                width: (root.width - 8 - Math.max(0, root.options.length - 1) * 4) / Math.max(1, root.options.length)
                height: parent.height
                radius: height / 2
                color: index === root.currentIndex ? (root.theme ? root.theme.accentGreen : "#8FBEA3") : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: index === root.currentIndex ? "#FFFFFF" : (root.theme ? root.theme.textSecondary : "#6E8076")
                    font.pixelSize: root.theme ? root.theme.fontCaption : 12
                    font.bold: index === root.currentIndex
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.currentIndex = index
                        root.changed(index)
                    }
                }
            }
        }
    }
}
