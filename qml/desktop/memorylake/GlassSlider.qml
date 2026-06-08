import QtQuick

// 暗玻璃磨砂滑块（v88 range-control §7.4）。轨 trackBg + 填充 aqua→violet + aqua 圆把手。
// 受控：value 由父绑定；拖动/点击发 moved(newValue)，由父持久化 + 弹 toast。色取 MemoryLakeStyle（G1）。
Item {
    id: sld

    property MemoryLakeStyle style
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    signal moved(real value)

    implicitWidth: 160
    implicitHeight: 24

    readonly property real _span: Math.max(0.0001, to - from)
    readonly property real _ratio: Math.max(0, Math.min(1, (value - from) / _span))
    readonly property int _handle: 16
    readonly property real _trackW: width - _handle

    function _setFromX(px) {
        var r = Math.max(0, Math.min(1, (px - _handle / 2) / Math.max(1, _trackW)))
        var raw = from + r * _span
        var snapped = stepSize > 0 ? (from + Math.round((raw - from) / stepSize) * stepSize) : raw
        snapped = Math.max(from, Math.min(to, snapped))
        // 受控：只发 moved，不自写 value（否则会盖掉父级 value: 绑定，首拖后断开）。
        if (snapped !== value) sld.moved(snapped)
    }

    // 轨
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: sld._handle / 2
        width: sld._trackW
        height: 6
        radius: 3
        color: sld.style ? sld.style.trackBg : Qt.rgba(1, 1, 1, 0.055)
        antialiasing: true

        // 填充
        Rectangle {
            height: parent.height
            radius: parent.radius
            width: Math.max(parent.radius * 2, parent.width * sld._ratio)
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: sld.style ? sld.style.aqua : "#9FE7EE" }
                GradientStop { position: 1; color: sld.style ? sld.style.violet : "#9B8BFF" }
            }
        }
    }

    // 把手（aqua 圆 + 内高光）
    Rectangle {
        id: handle
        width: sld._handle
        height: sld._handle
        radius: sld._handle / 2
        y: (parent.height - height) / 2
        x: sld._ratio * sld._trackW
        color: sld.style ? sld.style.aqua : "#9FE7EE"
        border.width: 1
        border.color: sld.style ? sld.style.calInputBorder : Qt.rgba(0.55, 0.87, 1.0, 0.12)
        antialiasing: true
        Rectangle {
            anchors.centerIn: parent
            width: 6; height: 6; radius: 3
            color: Qt.rgba(1, 1, 1, 0.9)
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function (m) { sld._setFromX(m.x) }
        onPositionChanged: function (m) { if (pressed) sld._setFromX(m.x) }
    }
}
