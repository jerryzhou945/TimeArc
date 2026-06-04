import QtQuick

// 毛玻璃面板基座。半透明叠色 + 细高光描边 + 轻投影，模拟设计稿 backdrop-filter 质感。
// 注：QML 无 CSS 实时背景模糊，这里用叠色近似（详见 docs/memory-lake-fidelity-gaps.md 🔴1）。
Rectangle {
    id: panel

    property MemoryLakeStyle style
    property bool strong: false
    // 默认不挂硬偏移投影：设计稿三栏包裹板用的是柔和 backdrop 玻璃，没有这种「底部一道暗带」。
    // （旧版每面板一个 y:10 偏移色块读作生硬下沉阴影，与 html 不符，已默认关闭。）
    property bool dropShadow: false

    radius: style ? style.radiusPanel : 18
    color: style ? style.panelBg : "#0e1422"
    border.width: 1
    border.color: style ? (strong ? style.panelBorderStrong : style.panelBorder)
                        : "#ffffff14"
    antialiasing: true
    clip: true

    // 可选轻投影（默认关；仅在显式 dropShadow:true 时挂）
    Rectangle {
        visible: panel.dropShadow
        x: 0
        y: 10
        z: -2
        width: parent.width
        height: parent.height
        radius: parent.radius
        color: panel.style ? panel.style.shadowColor : "#05070D"
        opacity: panel.style ? panel.style.shadowOpacity : 0.22
    }

    // 磨砂玻璃顶沿柔光（毛玻璃质感：顶部一抹极淡白漫射，使包裹板读作有厚度的玻璃而非平涂）。
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        z: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: panel.style ? (panel.style.night ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.10)) : Qt.rgba(1, 1, 1, 0.045) }
            GradientStop { position: 0.35; color: "transparent" }
        }
    }

    // 顶部 1px 内高光，营造玻璃边缘（主光打在上边缘斜面）。
    // 左右内缩 = 圆角半径，只覆盖「直边段」，不越出圆角拐角（否则直线段会戳出圆角外成超界线条）。
    Rectangle {
        z: 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: panel.radius
        anchors.rightMargin: panel.radius
        height: 1
        color: panel.style ? panel.style.edgeHighlight : Qt.rgba(1, 1, 1, 0.08)
    }

    // 更亮底沿 = --ml-border-strong（玻璃下唇接住环境反弹光，Cookbook §3.5 / 法规 X3）：
    // 比四周 border(.075) 更亮(.13)，恒取更亮值；同样左右内缩半径，不越出圆角。
    Rectangle {
        z: 1
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottomMargin: 1
        anchors.leftMargin: panel.radius
        anchors.rightMargin: panel.radius
        height: 1
        color: panel.style ? panel.style.panelBorderStrong : Qt.rgba(1, 1, 1, 0.13)
    }
}
