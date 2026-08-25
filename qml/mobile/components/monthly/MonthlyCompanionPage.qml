import QtQuick
import ".."
import "../../../shared/I18n.js" as I18n

Item {
    id: root

    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    property var theme
    property var report: ({})
    property var profile: ({})
    readonly property var companion: report.companion || ({})
    readonly property var firstApp: companion.firstApp || ({})
    readonly property var secondApp: companion.secondApp || ({})

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 25
        anchors.rightMargin: 25
        anchors.bottomMargin: 104
        spacing: 18

        Text {
            text: "Some apps always show up side by side"
            color: "#E8FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            height: 78
            spacing: 13

            MobileAppIcon {

                languageMode: root.languageMode
                theme: root.theme
                app: firstApp
                iconSize: 72
                cornerRadius: 18
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "×"
                color: profile.accent || "#FFFFFF"
                font.pixelSize: 24
                font.weight: Font.Light
            }

            MobileAppIcon {

                languageMode: root.languageMode
                theme: root.theme
                app: secondApp
                iconSize: 72
                cornerRadius: 18
            }
        }

        Text {
            width: parent.width
            text: companion.daysTogether
                  ? I18n.sentence(root.languageMode, "daysTogether", {days: companion.daysTogether})
                  : "Waiting for more days they appear together"
            color: "white"
            font.family: theme.numberFontFamily
            font.pixelSize: 32
            font.weight: Font.Black
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: companion.body || "When two apps keep meeting on the same day,"
                  + "they may be working together on something that matters to you."
            color: "#DFFFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            lineHeight: 1.55
            wrapMode: Text.WordWrap
        }
    }
}
