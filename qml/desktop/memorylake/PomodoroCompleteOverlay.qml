import QtQuick
import "../components/I18n.js" as I18n
import "../components/PlatformCursor.js" as Cursor

// 番茄完成全屏庆祝弹层（v88 .pomodoro-complete-overlay）。盖在一切之上：随机文案变体、
// 旋转 conic 光环（分段 Canvas 环近似，避免外部 GraphicalEffects 模块）、大像素番茄弹跳、
// 粒子迸发；点背景或「知道了」关闭。由 PomodoroWidget 的单一探测器（remain===0）触发。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §1.6 / 功能文 §2.7。
Item {
    id: comp

    property MemoryLakeStyle style
    property string languageMode: "zh"
    property string variant: "FOCUS COMPLETE"
    property bool shown: false
    signal closed()

    anchors.fill: parent
    z: 100000
    visible: shown && opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // 压暗背景 + 点击关闭。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: comp.closed() }
    }

    Item {
        id: cardWrap
        anchors.centerIn: parent
        width: 380; height: 380
        scale: comp.shown ? 1 : 0.88
        Behavior on scale { NumberAnimation { duration: 460; easing.type: Easing.OutBack } }

        // 旋转 conic 光环（分段彩环 aqua↔violet）。
        Canvas {
            id: halo
            anchors.centerIn: parent
            width: 320; height: 320
            property color a: comp.style ? comp.style.aqua : "#9FE7EE"
            property color v: comp.style ? comp.style.violet : "#9B8BFF"
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                var cx = width / 2, cy = height / 2, R = width / 2 - 14;
                ctx.lineWidth = 10;
                for (var deg = 0; deg < 360; deg += 5) {
                    var k = 0.5 + 0.5 * Math.sin(deg * Math.PI / 180.0);
                    var c = Qt.rgba(a.r + (v.r - a.r) * k, a.g + (v.g - a.g) * k,
                                    a.b + (v.b - a.b) * k, 0.55);
                    ctx.strokeStyle = c;
                    ctx.beginPath();
                    ctx.arc(cx, cy, R, deg * Math.PI / 180.0, (deg + 5.5) * Math.PI / 180.0);
                    ctx.stroke();
                }
            }
            Component.onCompleted: requestPaint()
            RotationAnimation on rotation {
                running: comp.shown; loops: Animation.Infinite
                from: 0; to: 360; duration: 4800
            }
        }

        // 大像素番茄弹跳。
        PixelTomato {
            id: bigTomato
            anchors.horizontalCenter: parent.horizontalCenter
            y: 96
            width: 150; height: 150
            style: comp.style
            SequentialAnimation on y {
                running: comp.shown; loops: Animation.Infinite
                NumberAnimation { from: 96; to: 74; duration: 620; easing.type: Easing.OutQuad }
                NumberAnimation { from: 74; to: 96; duration: 620; easing.type: Easing.InQuad }
            }
        }

        // 文案。
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: bigTomato.bottom; topMargin: 18 }
            text: comp.variant
            color: Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.96)
            font.pixelSize: 28; font.weight: Font.Bold; font.letterSpacing: 2
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: closeBtn.top; bottomMargin: 14 }
                text: I18n.t(comp.languageMode, "一段专注完成了")
            color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.6)
            font.pixelSize: 14
        }

        // 粒子迸发（一次性，随 shown 触发）。
        Repeater {
            model: 18
            delegate: Rectangle {
                required property int index
                readonly property real ang: index / 18 * 2 * Math.PI
                readonly property real dist: 90 + (index % 3) * 26
                property real t: 0
                width: 6; height: 6; radius: 3
                color: (index % 2 === 0) ? (comp.style ? comp.style.aqua : "#9FE7EE")
                                         : (comp.style ? comp.style.pomodoroAmber : "#FFE6A3")
                x: 160 + Math.cos(ang) * dist * t - width / 2
                y: 150 + Math.sin(ang) * dist * t - height / 2
                opacity: comp.shown ? (1 - t) : 0
                NumberAnimation on t {
                    running: comp.shown; from: 0; to: 1; duration: 1200; easing.type: Easing.OutCubic
                }
            }
        }

        // 关闭按钮。
        Rectangle {
            id: closeBtn
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            width: 132; height: 38; radius: 12
            color: closeH.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.20)
        // 中性文案：番茄钟与备忘黑板解耦后，这层可能盖在任意页面之上，关掉它回到的是用户
        // 原来那一页，不一定是黑板，旧文案里的「回到…」承诺已不成立。（zh/en/ja 三语齐备。）
        Text { anchors.centerIn: parent; text: I18n.t(comp.languageMode, "知道了")
                   color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.9); font.pixelSize: 14 }
            MouseArea {
                id: closeH; anchors.fill: parent; hoverEnabled: true
                cursorShape: Cursor.button(); onClicked: comp.closed()
            }
        }
    }
}
