import QtQuick
import QtQuick.Effects
import "MemoryLakeMock.js" as Mock

// 单张记忆卡牌：3D 翻面（Flipable + Y 轴旋转，自带透视），选中放大，悬停预览。
// 1:1 对应设计稿 .card / .face / 翻面 rotateY。
Item {
    id: card

    property MemoryLakeStyle style
    property var app
    property bool selected: false
    property bool flipped: false
    property bool previewed: false
    property bool dimmed: false   // 翻面锁定时其它卡变暗

    signal clicked()
    signal hoverEnter()
    signal hoverLeave()

    // 布局宽高（选中 310×440；翻面时整体放大 20% → 372×528，翻回恢复。
    // 用 layoutW 作为 Row 排布宽度，翻面变宽时会自动把相邻卡牌挤开。）
    readonly property int layoutW: selected ? (flipped ? 372 : 310) : 156
    readonly property int layoutH: selected ? (flipped ? 528 : 440) : 310

    width: layoutW
    height: layoutH

    Behavior on width { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

    // .card.is-selected{ scale(1.01) }；非选中 .88；锁定时其它卡 .25；预览微放大
    scale: selected ? 1.01 : (previewed ? 0.96 : 0.88)
    opacity: selected ? 1.0 : (dimmed ? 0.25 : (previewed ? 0.82 : 0.42))
    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260 } }

    // 选中卡牌氛围底灯：aqua 柔光从卡片四周/下方散出（近似设计稿 .face 的 0 0 38px 辉光）
    GlowCircle {
        z: -1
        visible: card.selected
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Math.round(card.height * 0.10)
        width: Math.round(card.width * 1.40)
        height: Math.round(card.height * 1.14)
        glowColor: card.style ? card.style.aqua : "#9FE7EE"
        glowOpacity: card.selected ? 0.46 : 0.0
        blurAmount: 1.0
        Behavior on glowOpacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }

    Flipable {
        id: flip
        anchors.fill: parent

        transform: Rotation {
            origin.x: card.width / 2
            origin.y: card.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: card.flipped ? 180 : 0
            Behavior on angle {
                NumberAnimation { duration: 680; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
            }
        }

        front: Rectangle {
            anchors.fill: parent
            radius: 28
            color: card.style ? card.style.faceBg : "#0D121D"
            // 描边由顶层 overlay 绘制（见 face 末尾），确保盖在封面图之上且随翻面
            border.width: 0
            clip: true

            Column {
                anchors.fill: parent
                // 封面图：顶部圆角裁切到卡片圆角（Qt 的 clip 只裁矩形，会让方角溢出，
                // 故用 MultiEffect + 顶部圆角遮罩做真正的圆角裁切）
                Item {
                    id: cover
                    width: parent.width
                    height: card.selected ? 196 : 128
                    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                    // 被裁切的内容（图 + 底部渐变），渲染到 layer 供 MultiEffect 取样
                    Item {
                        id: coverSrc
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Image {
                            anchors.fill: parent
                            source: card.app ? Mock.imagePath(card.app.image) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: 0.88
                        }
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: card.style && card.style.night ? Qt.rgba(0.027, 0.035, 0.063, 0.6) : Qt.rgba(1, 1, 1, 0.35) }
                            }
                        }
                    }
                    // 顶部圆角遮罩（底部保持直角，与下方文字区平接）
                    Rectangle {
                        id: coverMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        color: "white"
                        topLeftRadius: 28
                        topRightRadius: 28
                        bottomLeftRadius: 0
                        bottomRightRadius: 0
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: coverSrc
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }
                // 文本区
                Column {
                    width: parent.width
                    padding: card.selected ? 18 : 13
                    spacing: 8
                    Text {
                        width: parent.width - (card.selected ? 36 : 26)
                        text: card.app ? card.app.name : ""
                        color: card.style ? card.style.textPrimary : "#fff"
                        font.pixelSize: card.selected ? 25 : 15
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: card.app ? card.app.type : ""
                        color: card.style ? card.style.textTertiary : "#888"
                        font.pixelSize: card.selected ? 13 : 12
                    }
                    Rectangle {
                        width: pillText.width + 24
                        height: pillText.height + (card.selected ? 20 : 16)
                        radius: 14
                        color: card.style ? card.style.accentSoft : "#8edfff20"
                        border.width: 1
                        border.color: card.style ? card.style.accentSoftBorder : "#8edfff33"
                        Text {
                            id: pillText
                            anchors.centerIn: parent
                            text: card.app ? card.app.time : ""
                            color: card.style ? card.style.accentText : "#dffaff"
                            font.pixelSize: card.selected ? 18 : 14
                            font.bold: true
                        }
                    }
                    Rectangle {
                        width: parent.width - (card.selected ? 36 : 26)
                        height: 8
                        radius: 4
                        color: card.style ? card.style.trackBg : "#ffffff14"
                        Rectangle {
                            width: parent.width * (card.app ? card.app.progress : 0)
                            height: parent.height
                            radius: 4
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: card.style ? card.style.aqua : "#82efff" }
                                GradientStop { position: 1; color: card.style ? card.style.violet : "#dd7dff" }
                            }
                        }
                    }
                    Text {
                        visible: card.selected
                        text: "点击翻面后锁定选择"
                        color: card.style ? card.style.textTertiary : "#888"
                        font.pixelSize: 11
                    }
                }
            }

            // 顶层描边：盖在封面图之上（封面侧边也有辉光），随卡片翻面
            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "transparent"
                border.width: 1
                border.color: card.selected ? (card.style ? card.style.faceBorderActive : "#9ef1ffb0")
                                             : (card.style ? card.style.faceBorder : "#ffffff14")
            }
        }

        back: Rectangle {
            anchors.fill: parent
            radius: 28
            color: card.style ? card.style.faceBg : "#0D121D"
            border.width: 0

            // 背面的淡背景图 + 暗罩同样圆角裁切（避免方角溢出卡片圆角）
            Item {
                id: backArtSrc
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Image {
                    anchors.fill: parent
                    source: card.app ? Mock.imagePath(card.app.image) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.18
                }
                Rectangle {
                    anchors.fill: parent
                    color: card.style && card.style.night ? Qt.rgba(0.05, 0.07, 0.11, 0.93) : Qt.rgba(1, 1, 1, 0.86)
                }
            }
            Rectangle {
                id: backArtMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                color: "white"
                radius: 28
            }
            MultiEffect {
                anchors.fill: parent
                source: backArtSrc
                maskEnabled: true
                maskSource: backArtMask
            }

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14
                Text {
                    width: parent.width
                    text: card.app ? card.app.mood : ""
                    color: card.style ? card.style.textPrimary : "#fff"
                    font.pixelSize: card.selected ? 30 : 20
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: card.app ? card.app.analysis : ""
                    color: card.style ? card.style.textSecondary : "#bbb"
                    font.pixelSize: 14
                    lineHeight: 1.4
                    wrapMode: Text.WordWrap
                }
                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: card.app ? [
                            { k: "启动", v: card.app.launches },
                            { k: "最长", v: card.app.longest }
                        ] : []
                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - 10) / 2
                            height: 44
                            radius: 14
                            color: card.style ? card.style.cardBg : "#ffffff12"
                            border.width: 1
                            border.color: card.style ? card.style.cardBorder : "#ffffff16"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.k + "  " + modelData.v
                                color: card.style ? card.style.textSecondary : "#ccc"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // 顶层描边：盖在背面暗罩之上，随卡片翻面
            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "transparent"
                border.width: 1
                border.color: card.style ? card.style.faceBorderActive : "#9ef1ffb0"
            }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: hovered ? card.hoverEnter() : card.hoverLeave()
    }
    TapHandler {
        onTapped: card.clicked()
    }
}
