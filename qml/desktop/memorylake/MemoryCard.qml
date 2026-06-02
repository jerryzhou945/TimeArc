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

    // 布局宽高（选中 310×440；翻面时整体放大 40% → 434×616，翻回恢复。
    // 用 layoutW 作为 Row 排布宽度，翻面变宽时会自动把相邻卡牌挤开。）
    readonly property int layoutW: selected ? (flipped ? 434 : 310) : 156
    readonly property int layoutH: selected ? (flipped ? 616 : 440) : 310

    width: layoutW
    height: layoutH

    Behavior on width { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

    // .card.is-selected{ scale(1.01) }；非选中 .88；锁定时其它卡 .25；预览微放大
    scale: selected ? 1.01 : (previewed ? 0.96 : 0.88)
    opacity: selected ? 1.0 : (dimmed ? 0.25 : (previewed ? 0.82 : 0.42))
    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260 } }

    // 翻面角度提升为卡片级属性：底灯据此做 3D 透视收束 + 高光绽放（见下方 ambientGlow）。
    property real flipAngle: flipped ? 180 : 0
    Behavior on flipAngle {
        NumberAnimation { duration: 680; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
    }

    // 选中卡牌氛围底灯 + 翻面光效。让光像是卡片自身发出、随 3D 转动守恒，而非呆板的亮方块：
    //  · 静止：贴合卡片圆角轮廓的 aqua 柔光（向外散出，向内被卡身遮住），底部略向下成「底灯」。
    //  · 翻面中：光随卡片透视收束——转到侧面(90°)时水平压成一道竖直光芯，
    //    同时亮度绽放、色相由 aqua 偏移到 violet（仿光线穿过转动卡片的折射），转回正面再舒展还原。
    Item {
        id: ambientGlow
        z: -1
        anchors.fill: parent
        anchors.bottomMargin: -Math.round(card.height * 0.05)

        // 卡片在 Y 轴旋转下的投影系数：|cos θ|（正面=1，侧面=0，背面=1）
        readonly property real foreshorten: Math.abs(Math.cos(card.flipAngle * Math.PI / 180))
        readonly property real edgeOn: 1.0 - foreshorten   // 侧面观程度，90° 处达峰
        readonly property color restColor: card.style ? card.style.aqua : "#9FE7EE"
        readonly property color peakColor: card.style ? card.style.violet : "#9B8BFF"

        // 选中淡入淡出走 baseGlow（带 Behavior）；翻面高光走 edgeOn（跟随 flipAngle 动画），两者相乘，互不干扰
        property real baseGlow: card.selected ? 0.55 : 0.0
        Behavior on baseGlow { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        opacity: baseGlow * (1.0 + 0.55 * edgeOn)
        visible: opacity > 0.01

        // 透视收束：侧面观时水平压成光芯（留 14% 下限，避免完全熄灭）
        transform: Scale {
            origin.x: ambientGlow.width / 2
            origin.y: ambientGlow.height / 2
            xScale: 0.14 + 0.86 * ambientGlow.foreshorten
        }

        Rectangle {
            id: glowSrc
            anchors.fill: parent
            radius: 30
            // aqua → violet 折射偏移（峰值偏移 0.7）
            color: Qt.rgba(
                ambientGlow.restColor.r + (ambientGlow.peakColor.r - ambientGlow.restColor.r) * ambientGlow.edgeOn * 0.7,
                ambientGlow.restColor.g + (ambientGlow.peakColor.g - ambientGlow.restColor.g) * ambientGlow.edgeOn * 0.7,
                ambientGlow.restColor.b + (ambientGlow.peakColor.b - ambientGlow.restColor.b) * ambientGlow.edgeOn * 0.7,
                1.0)
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: glowSrc
            source: glowSrc
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            autoPaddingEnabled: true
        }
    }

    Flipable {
        id: flip
        anchors.fill: parent

        transform: Rotation {
            origin.x: card.width / 2
            origin.y: card.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: card.flipAngle   // 动画由 card.flipAngle 的 Behavior 驱动（底灯共享同一角度）
        }

        front: Item {
            anchors.fill: parent

            // 整张正面（底色 + 封面图 + 文本）先按方角合成，再用单一圆角遮罩统一裁切：
            // 让封面图圆角「就是」卡片圆角，消除早前「封面图自带圆角 vs 卡片圆角」两套半径
            // 对不齐、在上方两个棱角露出底色黑边的问题（如 P3R 卡）。
            Item {
                id: faceContent
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.samples: 4        // 关键：给 layer FBO 开多重采样，否则边缘无抗锯齿
                layer.smooth: true

                // 底色（方角，统一交给下方遮罩裁圆）
                Rectangle {
                    anchors.fill: parent
                    color: card.style ? card.style.faceBg : "#0D121D"
                }

                Column {
                    anchors.fill: parent
                    // 封面图（方角铺满顶部；不再自带圆角，圆角由整面遮罩负责）
                    Item {
                        id: cover
                        width: parent.width
                        height: card.selected ? 196 : 128
                        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
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
            }

            // 单一圆角遮罩（四角统一 28），整面一次裁圆——封面图随之得到与卡片完全一致的圆角
            Rectangle {
                id: faceMask
                anchors.fill: parent
                radius: 28
                color: "white"
                antialiasing: true
                visible: false
                layer.enabled: true
                layer.samples: 4        // 多重采样让圆角遮罩边缘平滑，消除黑色锯齿噪边
                layer.smooth: true
            }
            MultiEffect {
                anchors.fill: parent
                source: faceContent
                maskEnabled: true
                maskSource: faceMask
                // 默认阈值：直接采用遮罩的抗锯齿 alpha 渐变（已由上面的多重采样平滑），
                // 不做硬阈值，否则会把边缘渐变重新切成锯齿。
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
                layer.samples: 4
                layer.smooth: true
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
                layer.samples: 4        // 与正面一致：多重采样平滑圆角遮罩边缘
                layer.smooth: true
                antialiasing: true
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
