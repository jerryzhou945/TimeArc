import QtQuick

// 键帽 chip（v88 .kbd §7.10）。纯展示（只读）。min-w 34 / h 28 / r 9，weight 900。
// 色取 MemoryLakeStyle 令牌（G1，复用 ghost 玻璃族）。
Rectangle {
    id: cap

    property MemoryLakeStyle style
    property string keyText: ""

    implicitWidth: Math.max(34, label.implicitWidth + 16)
    implicitHeight: 28
    radius: 9
    color: style ? style.calGhostHover : Qt.rgba(1, 1, 1, 0.10)
    border.width: 1
    border.color: style ? style.calGhostBorder : Qt.rgba(1, 1, 1, 0.14)
    antialiasing: true

    Text {
        id: label
        anchors.centerIn: parent
        text: cap.keyText
        color: cap.style ? cap.style.textPrimary : Qt.rgba(1, 1, 1, 0.88)
        font.pixelSize: 12
        font.weight: 900
    }
}
