import QtQuick
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property bool checked: true

    signal toggled(bool checked)

    width: 40
    height: 24

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.checked ? root.theme.accent : root.theme.cardElevated
        border.color: root.checked ? root.theme.accent : root.theme.border
        border.width: 1
    }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 3
        x: root.checked ? 19 : 3
        color: root.checked ? "#FFFFFF" : root.theme.textMuted

        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
