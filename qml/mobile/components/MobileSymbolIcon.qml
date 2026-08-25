import QtQuick
import QtQuick.Effects
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
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
