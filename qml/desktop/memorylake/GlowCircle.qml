import QtQuick
import QtQuick.Effects

// 柔光圆：近似设计稿的 radial-gradient 角向光晕。
// 一张实心圆经高斯模糊得到柔边发光，可叠在舞台角落或回顾层。
Item {
    id: glow

    property color glowColor: "#9FE7EE"
    property real glowOpacity: 0.18
    property real blurAmount: 1.0

    Item {
        id: src
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: glow.glowColor
        }
    }

    MultiEffect {
        anchors.fill: src
        source: src
        blurEnabled: true
        blur: glow.blurAmount
        blurMax: 64
        autoPaddingEnabled: true
        opacity: glow.glowOpacity
    }
}
