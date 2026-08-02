import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string name: ""
    property color color: "white"
    property int iconSize: 20

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.name.length > 0
                ? Qt.resolvedUrl("../../../resources/app/icons/mobile/"
                                 + root.name + ".svg") : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: root.color
        }
    }
}
