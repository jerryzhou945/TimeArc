import QtQuick
import "../../shared/I18n.js" as I18n

Rectangle {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property bool wallpaperActive: false
    property bool strong: false

    radius: theme.cardRadius
    color: wallpaperActive
           ? (strong ? theme.contentStrong : theme.contentClear)
           : theme.panelColor(false, strong)
    border.width: wallpaperActive ? 1 : 0
    border.color: wallpaperActive ? theme.timelineLine : "transparent"
}
