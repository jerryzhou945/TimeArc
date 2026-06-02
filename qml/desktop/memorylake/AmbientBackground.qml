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

    // 居中柔光：原来的两个「角向」柔光会被方形裁切出硬边方角（伪影）。
    // 改为一处居中、四周自然衰减、不触及边角的柔光，配合整 App 暗色水面。
    GlowCircle {
        anchors.centerIn: parent
        width: parent.width * 0.66
        height: parent.height * 0.72
        glowColor: ambient.style ? ambient.style.aqua : "#9FE7EE"
        glowOpacity: (ambient.style ? ambient.style.glowStrength : 1.0) * 0.10
        blurAmount: 1.0
    }
}
