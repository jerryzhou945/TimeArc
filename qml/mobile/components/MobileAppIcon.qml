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
    property int iconSize: 48
    readonly property real adaptiveCornerRatio: 0.22
    property int cornerRadius: Math.round(iconSize * adaptiveCornerRatio)
    readonly property string appIconPath: (app && app.appIconPath)
                                               ? app.appIconPath.toString()
                                               : ""
    readonly property string appIdentifier: (app && app.packageName)
                                                    ? app.packageName.toString()
                                                    : ((app && app.appIdentifier)
                                                       ? app.appIdentifier.toString()
                                                       : "")
    readonly property bool launcherFallback:
        appIdentifier.toLowerCase().indexOf("com.huawei.android.launcher") === 0

    width: iconSize
    height: iconSize

    function normalizedSource(pathValue) {
        var value = (pathValue || "").toString().trim()
        if (value.length === 0)
            return ""
        if (value.indexOf("file://") === 0
                || value.indexOf("qrc:/") === 0
                || value.indexOf("image://") === 0)
            return value
        value = value.replace(/\\/g, "/")
        return value.charAt(0) === "/" ? "file://" + value : "file:///" + value
    }

    MobileRoundedFrame {
        anchors.fill: parent
        radius: root.cornerRadius

        Rectangle {
            anchors.fill: parent
            color: root.theme.surfaceRaised
        }

        MobileSymbolIcon {

            languageMode: root.languageMode
            anchors.centerIn: parent
            visible: iconImage.status !== Image.Ready && root.launcherFallback
            name: "home"
            color: root.theme.accentBright
            iconSize: Math.round(root.iconSize * 0.52)
        }

        Text {
            anchors.centerIn: parent
            text: (root.app && root.app.initial) ? root.app.initial : "h"
            visible: iconImage.status !== Image.Ready && !root.launcherFallback
            color: root.theme.accentBright
            font.family: root.theme.fontFamily
            font.pixelSize: Math.max(13, Math.round(root.iconSize * 0.34))
            font.weight: Font.Bold
        }

        Image {
            id: iconImage
            anchors.fill: parent
            anchors.margins: 3
            source: root.normalizedSource(root.appIconPath)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            visible: status === Image.Ready
        }
    }
}
