import QtQuick

Rectangle {
    id: root

    default property alias content: contentHost.data

    property int padding: 20
    property color fillColor: "#FBF8F4"
    property real fillOpacity: 0.94
    property color strokeColor: "#E8E0D8"
    property int strokeWidth: 1
    property color shadowColor: "#BFAE9D"
    property real shadowOpacity: 0.10
    property int shadowOffset: 8
    property bool clipContent: false

    radius: 28
    color: "transparent"
    border.width: strokeWidth
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
        visible: root.shadowOpacity > 0
        z: -2
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.strokeWidth > 0 ? 1 : 0
        radius: Math.max(0, root.radius - 1)
        color: root.fillColor
        opacity: root.fillOpacity
        z: -1
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.margins: root.padding
        clip: root.clipContent
    }
}
