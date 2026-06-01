import QtQuick
import QtQuick.Effects

// 记忆窗口氛围层：底色 + 跟随当前 APP 的模糊大背景图 + 角向柔光。
// 对应设计稿 .app-bg / .memory-window::before/::after 的灯光。
Item {
    id: ambient

    property MemoryLakeStyle style
    property url appImage

    clip: true

    // 底色
    Rectangle {
        anchors.fill: parent
        color: ambient.style ? ambient.style.stageBg : "#070A11"
    }

    // 模糊大背景图（真模糊层之一，受控使用，详见 fidelity-gaps 🔴1 / 性能注意）
    Item {
        id: imgSource
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Image {
            anchors.fill: parent
            source: ambient.appImage
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: imgSource
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: ambient.style && ambient.style.night ? -0.22 : -0.06
        saturation: -0.10
        scale: 1.16
        opacity: ambient.style ? ambient.style.ambientImageOpacity : 0.3
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    }

    // 顶部角向柔光（aqua 左 / violet 右）
    GlowCircle {
        width: 560; height: 560
        x: -180; y: -260
        glowColor: ambient.style ? ambient.style.aqua : "#9FE7EE"
        glowOpacity: (ambient.style ? ambient.style.glowStrength : 1.0) * 0.16
        blurAmount: 1.0
    }
    GlowCircle {
        width: 520; height: 520
        x: parent.width - 360; y: -240
        glowColor: ambient.style ? ambient.style.violet : "#9B8BFF"
        glowOpacity: (ambient.style ? ambient.style.glowStrength : 1.0) * 0.14
        blurAmount: 1.0
    }

    // 底部加深，营造水面纵深
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop {
                position: 1.0
                color: ambient.style && ambient.style.night ? Qt.rgba(0.02, 0.03, 0.05, 0.55)
                                                            : Qt.rgba(0.40, 0.34, 0.28, 0.10)
            }
        }
    }
}
