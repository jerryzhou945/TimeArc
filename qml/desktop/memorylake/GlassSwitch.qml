import QtQuick

// 暗玻璃药丸开关（v88 .switch §7.1）。受控：checked 由父绑定，点击发 toggled(!checked)，
// 由父持久化 + 弹 toast（避免组件内双写 KV）。轨 48×28 / 旋钮 22×22；开态 aqua→violet 渐变。
// 色全取 MemoryLakeStyle 令牌（G1），昼夜随 style.night 自动切。
Item {
    id: sw

    property MemoryLakeStyle style
    property bool checked: false
    property bool enabledSwitch: true
    signal toggled(bool checked)

    implicitWidth: 48
    implicitHeight: 28
    opacity: enabledSwitch ? 1.0 : 0.4

    readonly property var _ease: style ? style.easeSnappy : [0.18, 0.9, 0.2, 1, 1, 1]

    // 关态轨底
    Rectangle {
        id: track
        anchors.fill: parent
        radius: 14
        color: sw.style ? sw.style.switchOff : Qt.rgba(1, 1, 1, 0.14)
        antialiasing: true

        // 开态渐变（aqua→violet），靠 opacity 过渡叠在关态之上
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: sw.checked ? 1 : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: sw.style ? Qt.rgba(sw.style.aqua.r, sw.style.aqua.g, sw.style.aqua.b, 0.75) : Qt.rgba(0.62, 0.90, 0.93, 0.75) }
                GradientStop { position: 1; color: sw.style ? Qt.rgba(sw.style.violet.r, sw.style.violet.g, sw.style.violet.b, 0.72) : Qt.rgba(0.61, 0.55, 1.0, 0.72) }
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // 旋钮
    Rectangle {
        id: knob
        width: 22
        height: 22
        radius: 11
        y: 3
        x: sw.checked ? 23 : 3
        color: sw.style ? sw.style.switchKnob : Qt.rgba(0.96, 0.98, 1.0, 0.95)
        antialiasing: true
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: sw._ease } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: sw.enabledSwitch
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true   // 嵌在 SilkyFlickable 内时不被滚动吞点击
        onClicked: sw.toggled(!sw.checked)
    }
}
