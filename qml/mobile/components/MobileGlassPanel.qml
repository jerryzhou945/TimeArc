import QtQuick

Rectangle {
    id: root

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
