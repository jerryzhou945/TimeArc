import QtQuick

// 毛玻璃面板基座。半透明叠色 + 细高光描边 + 轻投影，模拟设计稿 backdrop-filter 质感。
// 注：QML 无 CSS 实时背景模糊，这里用叠色近似（详见 docs/memory-lake-fidelity-gaps.md 🔴1）。
Rectangle {
    id: panel

    property MemoryLakeStyle style
    property bool strong: false
    property bool dropShadow: true

    radius: style ? style.radiusPanel : 18
    color: style ? style.panelBg : "#0e1422"
    border.width: 1
    border.color: style ? (strong ? style.panelBorderStrong : style.panelBorder)
                        : "#ffffff14"
    antialiasing: true

    // 轻投影（沿用 App 主壳的廉价偏移阴影做法，避免每面板挂 MultiEffect）
    Rectangle {
        visible: panel.dropShadow
        x: 0
        y: 10
        z: -2
        width: parent.width
        height: parent.height
        radius: parent.radius
        color: panel.style && panel.style.night ? "#05070D" : "#BFAE9D"
        opacity: panel.style && panel.style.night ? 0.22 : 0.10
    }

    // 顶部 1px 内高光，营造玻璃边缘
    Rectangle {
        z: 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: 1
        radius: 1
        color: panel.style && panel.style.night ? Qt.rgba(1, 1, 1, 0.08)
                                                : Qt.rgba(1, 1, 1, 0.45)
    }
}
