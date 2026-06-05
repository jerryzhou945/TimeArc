import QtQuick

// tier-2 霜膜内层卡（Cookbook §5.1 / §3.4 Resting / 法规 L4）：
//   白霜膜 cardBg + 发丝边框 + 边缘光对（顶沿内高光 .035 + 更亮底沿 panelBorderStrong）
//   + 可选 accent 斜染膜（被柔光染过的彩色玻璃，配方#3）；静止**无投影**（嵌进父面、齐平读感）。
// 用法：当 Item 容器用，子项直接写在内部。accent 斜染由 tintTop/tintBottom 两色驱动（页面用
// ml 令牌派生 alpha，保持 G1 单一事实源），默认透明 = 无斜染。
Item {
    id: frost

    property MemoryLakeStyle style
    property int radius: 16
    // accent 斜染（竖直近似 135°/180°，卡尺度下与斜向差异可忽略）。默认透明 = 纯霜膜。
    property color tintTop: "transparent"
    property color tintBottom: "transparent"

    default property alias content: holder.data

    Rectangle {
        anchors.fill: parent
        radius: frost.radius
        color: frost.style ? frost.style.cardBg : Qt.rgba(1, 1, 1, 0.035)
        border.width: 1
        border.color: frost.style ? frost.style.cardBorder : Qt.rgba(1, 1, 1, 0.065)
        antialiasing: true

        // accent 斜染膜
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: frost.tintTop.a > 0 || frost.tintBottom.a > 0
            gradient: Gradient {
                GradientStop { position: 0; color: frost.tintTop }
                GradientStop { position: 1; color: frost.tintBottom }
            }
        }

        // 磨砂玻璃顶沿柔光（双重 frost 的「玻璃接住上方环境光」质感，纯静态合成）：
        // 顶部一抹极淡白 → 40% 处淡出，模拟光从上方漫射进霜面，使卡读作有厚度的玻璃而非平涂。
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: frost.style ? (frost.style.night ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.12)) : Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        // 顶沿 1px 内高光（夜 .035 / 昼瓷光）。左右内缩半径，只覆盖直边段，不越出圆角拐角。
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right
                      topMargin: 1; leftMargin: frost.radius; rightMargin: frost.radius }
            height: 1
            color: frost.style ? (frost.style.night ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(1, 1, 1, 0.55))
                               : Qt.rgba(1, 1, 1, 0.035)
        }
        // 更亮底沿 = panelBorderStrong（玻璃下唇）。同样左右内缩半径。
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                      bottomMargin: 1; leftMargin: frost.radius; rightMargin: frost.radius }
            height: 1
            color: frost.style ? frost.style.panelBorderStrong : Qt.rgba(1, 1, 1, 0.13)
        }
    }

    Item { id: holder; anchors.fill: parent }
}
