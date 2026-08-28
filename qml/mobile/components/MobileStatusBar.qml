import QtQuick
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme

    // Android renders its real system status area. This zero-height item keeps
    // existing page layouts source-compatible without drawing simulated state.
    height: 0
}
