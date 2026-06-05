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

    // 中央列（湖）区域：现在卡牌区已是中栏独立暗箱（设计稿 .cards-zone），lane = 整个卡区，
    // 灯光/水位线天然限定在卡区圆角内（不再需要避让左右面板的绝对偏移）。
    readonly property real laneLeft: 0
    readonly property real laneRight: width
    readonly property real laneCenter: (laneLeft + laneRight) / 2
    readonly property real laneWidth: Math.max(0, laneRight - laneLeft)
    // 悬停展开湖（C4）：指针进入中央卡区时轻微放大 + 一道扫光。
    property bool laneHovered: false

    // 选中卡中心在卡轨内的偏移（用最终宽度解析计算，让宽度与位移动画同步推进）
    function centerOffset() {
        var spacing = 18;
        var x = 0;
        for (var j = 0; j < selectedIndex; j++)
            x += 156 + spacing;
        var selW = (flippedIndex === selectedIndex) ? 434 : 310;
        x += selW / 2;
        return x;
    }

    // 卡牌舞台
    Rectangle {
        id: zone
        anchors.fill: parent
        anchors.margins: 0
        // 透明：不再画第二个圆角暗框；水面暗色已上移为整个 App 背景（见 Shell）
        color: "transparent"
        border.width: 0
        clip: true

        // 悬停展开湖（C4）：指针进入中央卡区，整块轻微 scale 1.012，离开复位（柔落）。
        transform: Scale {
            origin.x: zone.width / 2; origin.y: zone.height / 2
            xScale: carousel.laneHovered ? 1.012 : 1.0
            yScale: carousel.laneHovered ? 1.012 : 1.0
            Behavior on xScale { NumberAnimation { duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: carousel.style ? carousel.style.easeSoft : [0.2, 0.8, 0.2, 1, 1, 1] } }
            Behavior on yScale { NumberAnimation { duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: carousel.style ? carousel.style.easeSoft : [0.2, 0.8, 0.2, 1, 1, 1] } }
        }

        // 中央湖光：从下中升起的 aqua 上照光（C1，设计稿 radial 50% 68% aqua .055）。
        // 限定在中央列（laneCenter），不外溢到左右面板背后。
        GlowCircle {
            // 收敛到卡片量级（不再横跨整条中央列），从下中升起的一团柔光（径向自然淡出）。
            readonly property real d: Math.max(160, Math.min(carousel.laneWidth, carousel.height) * 0.72)
            width: d; height: d * 0.7
            x: carousel.laneCenter - width / 2
            y: carousel.height * 0.70 - height / 2
            glowColor: carousel.style ? carousel.style.aqua : "#9FE7EE"
            glowOpacity: (carousel.style ? carousel.style.glowStrength : 1.0) * 0.16
            visible: carousel.laneWidth > 0
        }
        // 水位线（C2）：约 64% 高度一条 aqua 三停渐变 1px 线，宽度限定中央列、左右内缩，
        // 避免横贯整屏割裂画面（现状注释已证实全宽中线的问题）。
        Rectangle {
            x: carousel.laneLeft
            width: carousel.laneWidth
            y: Math.round(carousel.height * 0.64)
            height: 1
            visible: carousel.laneWidth > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: carousel.style
                    ? Qt.rgba(carousel.style.aqua.r, carousel.style.aqua.g, carousel.style.aqua.b, 0.12)
                    : Qt.rgba(0.62, 0.90, 0.93, 0.12) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // 卡轨
        Item {
            id: viewport
            anchors.fill: parent
            clip: true

            // 悬停感应区：仅覆盖中央列（不含左右面板带），决定 laneHovered（C4）。
            // 置于卡牌之下、不拦截点击（HoverHandler 不消费 Tap）。
            Item {
                x: carousel.laneLeft - parent.x
                width: carousel.laneWidth
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: carousel.laneWidth > 0
                HoverHandler { onHoveredChanged: carousel.laneHovered = hovered }
            }

            Row {
                id: track
                height: 660   // 容纳翻面放大后的卡牌（616 高）并保持垂直居中
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18
                x: viewport.width / 2 - carousel.centerOffset()
                Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: carousel.style ? carousel.style.easeSoft : [0.2, 0.8, 0.2, 1, 1, 1] } }

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

                        // 垂直始终居中：y 直接跟随动画中的 height，使卡片中心恒定（330），
                        // 翻面只对称放大、不再上下漂移（去掉了原 -6 选中上移与会与高度动画抢拍的 y Behavior）。
                        y: (track.height - height) / 2

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

        // wheel-tip（卡区左上角，设计稿 .wheel-tip）
        Rectangle {
            x: 16; y: 14
            width: tipText.width + 22; height: 34; radius: 17
            color: carousel.locked ? (carousel.style ? carousel.style.lockBg : "#3c0a18")
                                    : (carousel.style ? carousel.style.pillScrim : Qt.rgba(0, 0, 0, 0.18))
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

        // （移除原「展开扫光 cardLakeExpandScan」：掠过整条中央列、范围远大于卡片，读作莫名其妙的
        //  大扫光。悬停反馈改由整块轻微 scale 1.012 + 顶部 hover-hint toast 承担，已足够且不喧宾夺主。）

        // 底部进度点胶囊（C3）：N 点对应 N 卡；active 点 morph 成 32px 青胶囊 + 外发光 + 内高光 + 横扫高光 1.4s。
        Row {
            id: progressPill
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 72
            x: carousel.laneCenter - width / 2
            spacing: 8
            visible: carousel.apps.length > 1 && carousel.laneWidth > 0
            Repeater {
                model: carousel.apps.length
                delegate: Item {
                    id: dotItem
                    required property int index
                    readonly property bool isActive: index === carousel.selectedIndex
                    width: isActive ? 32 : 7
                    height: 7
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                    // 外发光（active：叠一层更大低透 aqua 圆角条仿 0 0 辉光）
                    Rectangle {
                        visible: dotItem.isActive
                        anchors.centerIn: parent
                        width: parent.width + 10; height: parent.height + 10; radius: height / 2
                        color: carousel.style ? Qt.rgba(carousel.style.aqua.r, carousel.style.aqua.g, carousel.style.aqua.b, 0.18) : "#9FE7EE30"
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        clip: true
                        color: dotItem.isActive ? (carousel.style ? carousel.style.aqua : "#9FE7EE")
                                                : (carousel.style ? carousel.style.textTertiary : Qt.rgba(1, 1, 1, 0.34))
                        Behavior on color { ColorAnimation { duration: 220 } }

                        // 内高光顶沿（active）
                        Rectangle {
                            visible: dotItem.isActive
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 1; color: Qt.rgba(1, 1, 1, 0.4)
                        }
                        // 横扫高光（active 1.4s 循环；gate 在可见 + active）
                        Rectangle {
                            visible: dotItem.isActive
                            height: parent.height; width: 14
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.4) }
                                GradientStop { position: 1; color: "transparent" }
                            }
                            SequentialAnimation on x {
                                running: dotItem.isActive && carousel.visible
                                loops: Animation.Infinite
                                NumberAnimation { from: -14; to: 32; duration: 1400; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 400 }
                            }
                        }
                    }
                }
            }
        }

        // hover-hint toast（C5）：展开时顶部居中淡入一枚带发光 aqua 点的 frosted 胶囊（与左上 wheel-tip 不冲突）。
        Rectangle {
            id: hoverHint
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 22
            height: 34; radius: 17
            width: hintRow.width + 28
            color: carousel.style ? carousel.style.pillScrim : Qt.rgba(0, 0, 0, 0.18)
            border.width: 1
            border.color: carousel.style ? carousel.style.cardBorder : "#ffffff14"
            opacity: (carousel.laneHovered && !carousel.locked) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: 8
                Item {
                    width: 8; height: 8; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: carousel.style ? Qt.rgba(carousel.style.aqua.r, carousel.style.aqua.g, carousel.style.aqua.b, 0.3) : "#9FE7EE4d" }
                    Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: carousel.style ? carousel.style.aqua : "#9FE7EE" }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "滚轮切换 · 点击展开记忆"
                    color: carousel.style ? carousel.style.textSecondary : "#bbb"
                    font.pixelSize: 12
                }
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
