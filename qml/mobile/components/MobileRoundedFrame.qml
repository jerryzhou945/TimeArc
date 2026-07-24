import QtQuick
import QtQuick.Effects

Item {
    id: frame

    property real radius: 22
    property alias border: rim.border
    default property alias content: holder.data

    Item {
        id: holder
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true

        Rectangle {
            id: rim
            anchors.fill: parent
            z: 1000
            radius: frame.radius
            color: "transparent"
            antialiasing: true
        }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: frame.radius
        color: "white"
        antialiasing: true
        visible: false
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true
    }

    MultiEffect {
        anchors.fill: parent
        source: holder
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.28
    }
}
