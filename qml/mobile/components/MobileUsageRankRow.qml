import QtQuick
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property var app: ({})
    property int rank: 1
    property bool showSharePct: true
    property bool wallpaperActive: false

    height: 86

    Row {
        anchors.fill: parent
        spacing: 12

        MobileAppIcon {

            languageMode: root.languageMode
            anchors.verticalCenter: parent.verticalCenter
            theme: root.theme
            app: root.app
            iconSize: 48
            cornerRadius: 12
        }

        Column {
            width: parent.width - 60
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Row {
                width: parent.width
                height: 22

                Text {
                    width: parent.width - durationLabel.width - 12
                    text: (root.app && root.app.displayName)
                          ? root.tr(root.app.displayName) : root.tr("Unknown app")
                    color: root.wallpaperActive
                           ? root.theme.wallpaperInk : root.theme.textPrimary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: durationLabel
                    text: (root.app && root.app.durationText)
                          ? root.app.durationText : "0s"
                    color: root.wallpaperActive
                           ? root.theme.wallpaperInk : root.theme.textPrimary
                    font.family: root.theme.numberFontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 7
                radius: 4
                color: root.wallpaperActive
                       ? root.theme.withAlpha(root.theme.wallpaperMuted, 0.28)
                       : root.theme.progressTrack

                Rectangle {
                    width: parent.width * Math.max(
                               0.025,
                               Math.min(1, ((root.app && root.app.relativePct)
                                            ? root.app.relativePct : 0) / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: root.theme.normalDuration
                            easing.type: Easing.OutQuart
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 16

                Text {
                    width: parent.width / 2
                    text: I18n.sentence(root.languageMode, "rankPosition", {rank: root.rank})
                    color: root.wallpaperActive
                           ? root.theme.wallpaperMuted : root.theme.textMuted
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11
                }

                Text {
                    width: parent.width / 2
                    visible: root.showSharePct
                    text: ((root.app && root.app.sharePct)
                           ? root.app.sharePct : 0) + "%"
                    color: root.wallpaperActive
                           ? root.theme.wallpaperMuted : root.theme.textMuted
                    font.family: root.theme.numberFontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 60
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.wallpaperActive
               ? root.theme.timelineLine : root.theme.line
    }
}
