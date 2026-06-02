import QtQuick

// 中栏卡牌轮盘：水平卡轨 + 选中居中 + 滚轮切换 + 翻面锁定 + wheel-tip + 锁定徽标。
// 1:1 对应设计稿 .cards-zone / .cards / wheel 逻辑。
Item {
    id: carousel

    property MemoryLakeStyle style
    property var apps: []
    property int selectedIndex: 0
    property int flippedIndex: -1
    property int previewIndex: -1

    signal requestSelect(int cardIndex)
    signal requestToggleFlip(int cardIndex)
    signal hoverCard(int cardIndex)
    signal unhoverCard()

    readonly property bool locked: flippedIndex >= 0
    property bool wheelLock: false

    // 选中卡中心在卡轨内的偏移（用最终宽度解析计算，让宽度与位移动画同步推进）
    function centerOffset() {
        var spacing = 18;
        var x = 0;
        for (var j = 0; j < selectedIndex; j++)
            x += 156 + spacing;
        var selW = (flippedIndex === selectedIndex) ? 360 : 310;
        x += selW / 2;
        return x;
    }

    // 卡牌舞台
    Rectangle {
        id: zone
        anchors.fill: parent
        anchors.margins: 18
        radius: 26
        color: carousel.style ? (carousel.style.night ? Qt.rgba(0.012, 0.027, 0.055, 0.58) : Qt.rgba(1, 1, 1, 0.30)) : "#0a0f18"
        border.width: 1
        border.color: carousel.style ? carousel.style.cardBorder : "#ffffff14"
        clip: true

        // 中线
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 90
            anchors.rightMargin: 90
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(0.62, 0.90, 0.93, 0.12) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // 卡轨
        Item {
            id: viewport
            anchors.fill: parent
            clip: true

            Row {
                id: track
                height: 460
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18
                x: viewport.width / 2 - carousel.centerOffset()
                Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }

                Repeater {
                    model: carousel.apps
                    delegate: MemoryCard {
                        id: cardItem
                        required property int index
                        required property var modelData
                        style: carousel.style
                        app: modelData
                        selected: index === carousel.selectedIndex
                        flipped: index === carousel.flippedIndex
                        previewed: index === carousel.previewIndex && index !== carousel.selectedIndex
                        dimmed: carousel.locked && index !== carousel.flippedIndex
                        enabled: !carousel.locked || selected

                        y: (track.height - height) / 2 - (selected ? 6 : 0)
                        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                        onClicked: {
                            if (!selected) carousel.requestSelect(index)
                            else carousel.requestToggleFlip(index)
                        }
                        onHoverEnter: if (!carousel.locked) carousel.hoverCard(index)
                        onHoverLeave: carousel.unhoverCard()
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    if (carousel.locked) return
                    if (carousel.wheelLock) return
                    carousel.wheelLock = true
                    wheelTimer.restart()
                    var dir = event.angleDelta.y > 0 ? -1 : 1
                    var next = Math.max(0, Math.min(carousel.apps.length - 1, carousel.selectedIndex + dir))
                    if (next !== carousel.selectedIndex) carousel.requestSelect(next)
                }
            }
        }

        // wheel-tip
        Rectangle {
            x: 26; y: 22
            width: tipText.width + 22; height: 34; radius: 17
            color: carousel.locked ? (carousel.style ? carousel.style.lockBg : "#3c0a18")
                                    : Qt.rgba(0, 0, 0, carousel.style && carousel.style.night ? 0.18 : 0.06)
            border.width: 1
            border.color: carousel.locked ? (carousel.style ? carousel.style.lockBorder : "#ff789f30")
                                          : (carousel.style ? carousel.style.cardBorder : "#ffffff14")
            Behavior on color { ColorAnimation { duration: 180 } }
            Text {
                id: tipText
                anchors.centerIn: parent
                text: carousel.locked ? "已锁定：取消翻面后才能切换卡牌"
                                      : "滚轮 / 左侧排行切换当前 APP，悬停预览"
                color: carousel.locked ? (carousel.style ? carousel.style.lockText : "#ffeecd")
                                       : (carousel.style ? carousel.style.textTertiary : "#888")
                font.pixelSize: 12
            }
        }

        // 锁定徽标
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            width: lockText.width + 28; height: 36; radius: 18
            color: carousel.style ? carousel.style.lockBg : "#2a1c1088"
            border.width: 1
            border.color: carousel.style ? carousel.style.lockBorder : "#ffd89944"
            opacity: carousel.locked ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 240 } }
            Text {
                id: lockText
                anchors.centerIn: parent
                text: "当前记忆已展开 · 再次点击卡牌返回"
                color: carousel.style ? carousel.style.lockText : "#ffeecd"
                font.pixelSize: 12
            }
        }
    }

    Timer {
        id: wheelTimer
        interval: 240
        onTriggered: carousel.wheelLock = false
    }
}
