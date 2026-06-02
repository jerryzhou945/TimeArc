import QtQuick
import QtQuick.Effects

// 记忆窗口氛围层：底色 + 跟随当前 APP 的模糊大背景图 + 角向柔光。
// 对应设计稿 .app-bg / .memory-window::before/::after 的灯光。
Item {
    id: ambient

    property MemoryLakeStyle style
    property url appImage

    clip: true

    // 模糊大背景图已上移为「整个 App 背景」（见 DesktopAppShell，Issue 1）。
    // 这里底色透明，让 App 背景透出；仅保留角向柔光与底部加深营造水面氛围。

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
