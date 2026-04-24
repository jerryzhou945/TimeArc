import QtQuick

Rectangle {
    id: root

    default property alias content: contentHost.data

    property var theme
    property int padding: 18
    property color fillColor: theme ? theme.panelGlass : "#FFFDF9"
    property color strokeColor: theme ? theme.softStroke : "#EEE6D8"
    property color shadowColor: theme ? theme.shadow : "#A89372"
    property real shadowOpacity: 0.10
    property int shadowOffset: 8
    property bool clipContent: false

    radius: theme ? theme.radiusCard : 24
    color: "transparent"
    border.width: 1
    border.color: strokeColor
    clip: false

    Rectangle {
        x: 0
        y: root.shadowOffset
        width: parent.width
        height: parent.height
        radius: root.radius
        color: root.shadowColor
        opacity: root.shadowOpacity
        z: -2
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(0, root.radius - 1)
        color: root.fillColor
        opacity: 0.88
        z: -1
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.margins: root.padding
        clip: root.clipContent
    }
}
