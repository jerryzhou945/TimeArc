import QtQuick

Item {
    id: root

    required property var theme
    property var app: ({})
    property int iconSize: 48
    property int cornerRadius: 12
    readonly property string appIconPath: (app && app.appIconPath)
                                               ? app.appIconPath.toString()
                                               : ""

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

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.theme.surfaceRaised
        clip: true

        Text {
            anchors.centerIn: parent
            text: (root.app && root.app.initial) ? root.app.initial : "时"
            visible: iconImage.status !== Image.Ready
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
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: status === Image.Ready
        }
    }
}
