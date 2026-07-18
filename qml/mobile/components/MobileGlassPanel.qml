import QtQuick

Rectangle {
    id: root

    required property var theme
    property bool wallpaperActive: false
    property bool strong: false

    radius: theme.cardRadius
    color: theme.panelColor(wallpaperActive, strong)
    border.width: wallpaperActive ? 1 : 0
    border.color: wallpaperActive ? theme.glassLine : "transparent"
}
