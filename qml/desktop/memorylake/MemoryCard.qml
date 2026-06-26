import QtQuick
import QtQuick.Effects
import "../components/AppVisual.js" as AppVisual
import "../components/I18n.js" as I18n

// 单张记忆卡牌：3D 翻面（Flipable + Y 轴旋转，自带透视），选中放大，悬停预览。
// 1:1 对应设计稿 .card / .face / 翻面 rotateY。
Item {
    id: card

    property MemoryLakeStyle style
    property string languageMode: "zh"
    property var app
    property bool selected: false
    property bool flipped: false
    property bool previewed: false
    property bool dimmed: false   // 翻面锁定时其它卡变暗

    // 鼠标是否悬停在本卡上（设计稿 .card:hover）：霓虹底光 + 高光划过都只在悬停时醒来（§3.6）。
    readonly property bool hovered: hover.hovered

    // 卡面圆角 / 边缘光（描边）几何 + 圆角遮罩裁切阈值，集中此处便于统一调参。
    // maskThresholdMin：把 MultiEffect 圆角遮罩的裁切位置卡在「50% 覆盖」等高线（= 几何圆角
    // 半径），而不是默认 0 让抗锯齿淡边（alpha≈0）也整幅透出——后者会让内容圆角实际半径比
    // 描边大 ~2px，于是棱角处图片/黑底越过边缘光漏出。maskSpreadAtMin 给一点点软过渡保留抗锯齿。
    property int faceRadius: 28
    property real rimWidth: 2
    property real maskThresholdMin: 0.5
    property real maskSpreadAtMin: 0.28

    signal clicked()
    signal hoverEnter()
    signal hoverLeave()

    // 布局宽高（选中 310×440；翻面时整体放大 40% → 434×616，翻回恢复。
    // 用 layoutW 作为 Row 排布宽度，翻面变宽时会自动把相邻卡牌挤开。）
    readonly property int layoutW: selected ? (flipped ? 434 : 310) : 156
    readonly property int layoutH: selected ? (flipped ? 616 : 440) : 310

    width: layoutW
    height: layoutH

    // 选中放大走品牌「柔落」缓动（与翻面同曲线，整卡运动一致），让选卡过渡更整体。
    Behavior on width { NumberAnimation { duration: 360; easing.type: Easing.Bezier; easing.bezierCurve: card.style ? card.style.easeSoft : [0.2, 0.8, 0.2, 1, 1, 1] } }
    Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.Bezier; easing.bezierCurve: card.style ? card.style.easeSoft : [0.2, 0.8, 0.2, 1, 1, 1] } }

    // .card.is-selected{ scale(1.01) }；非选中 .88；锁定时其它卡 .25；预览微放大
    scale: selected ? 1.01 : (previewed ? 0.96 : 0.88)
    opacity: selected ? 1.0 : (dimmed ? 0.25 : (previewed ? 0.82 : 0.42))
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: card.style ? card.style.easeSoft : [0.2, 0.8, 0.2, 1, 1, 1] } }
    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

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

        // 霓虹底光只在交互时醒来（设计稿 .card:hover drop-shadow aqua）：**悬停**任意卡即点亮底光；
        // 选中卡翻面（locked，展示分析）时保持点亮以承载翻面透视高光。静止未悬停的卡无底光。
        // 翻面高光走 edgeOn（跟随 flipAngle 动画），与 baseGlow 相乘，互不干扰。
        property real baseGlow: (card.hovered || (card.selected && card.flipped)) ? 0.7 : 0.0
        Behavior on baseGlow { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        opacity: baseGlow * (1.0 + 0.55 * edgeOn)
        visible: opacity > 0.01

        // 透视收束：侧面观时水平压成光芯（留 14% 下限，避免完全熄灭）
        transform: Scale {
            origin.x: ambientGlow.width / 2
            origin.y: ambientGlow.height / 2
            xScale: 0.14 + 0.86 * ambientGlow.foreshorten
        }

        // 底灯改用平滑径向渐变（GlowCircle），取代旧的「实心圆角矩形 + MultiEffect 高斯模糊」——
        // 后者中心是平的实心块、模糊后仍能看出长方形轮廓、且大半径模糊出现一圈圈 banding（一层一层）。
        // 径向渐变中心最亮→边缘透明，天然柔和、椭圆无方角；放大到卡片外缘，中心被卡身遮住、只透出
        // 四周柔光晕（= 设计稿「向外散出、向内被卡身遮住」）。aqua→violet 折射偏移走 glowColor。
        GlowCircle {
            anchors.fill: parent
            anchors.margins: -Math.round(Math.min(parent.width, parent.height) * 0.30)
            glowColor: Qt.rgba(
                ambientGlow.restColor.r + (ambientGlow.peakColor.r - ambientGlow.restColor.r) * ambientGlow.edgeOn * 0.7,
                ambientGlow.restColor.g + (ambientGlow.peakColor.g - ambientGlow.restColor.g) * ambientGlow.edgeOn * 0.7,
                ambientGlow.restColor.b + (ambientGlow.peakColor.b - ambientGlow.restColor.b) * ambientGlow.edgeOn * 0.7,
                1.0)
            glowOpacity: 1.0
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

            // 选中卡会随翻面绕 Y 轴旋转。把整张正面（含边缘光描边）合成进一张多重采样 layer，
            // 让 Flipable 旋转的是这张已抗锯齿的单一纹理（圆角 + 描边一起重采样，无旋转锯齿台阶）。
            // 仅 selected 开（只有选中卡会翻面），避免给 9 张卡都建 FBO。
            layer.enabled: card.selected
            layer.samples: 4
            layer.smooth: true

            // 整张正面（底色 + 封面图 + 文本 + 顶层边缘光）先按方角合成，再用单一圆角遮罩统一裁切。
            // 关键：边缘光（描边）放进同一张被裁切的合成里，与内容共用同一条圆角边——内容绝不会越过
            // 描边漏到边缘光之外（修复棱角处图片/黑底突破边缘光的漏边）。圆角也由这张整面遮罩统一负责，
            // 消除早前「封面图自带圆角 vs 卡片圆角」两套半径对不齐露出底色黑边的问题（如 P3R 卡）。
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
                        // 生成式封面（§4.3）：appColor 渐变 + 居中系统图标，取代游戏海报。
                        GenerativeCover {
                            anchors.fill: parent
                            style: card.style
                            app: card.app
                            iconSize: card.selected ? 112 : 66
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
                            text: card.app ? AppVisual.modelDisplayNameForLanguage(card.app, card.languageMode) : ""
                            color: card.style ? card.style.textPrimary : "#fff"
                            font.pixelSize: card.selected ? 25 : 15
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: card.app ? I18n.t(card.languageMode, card.app.type) : ""
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
                            text: I18n.t(card.languageMode, "点击翻面后锁定选择")
                            color: card.style ? card.style.textTertiary : "#888"
                            font.pixelSize: 11
                        }
                    }
                }
                // 顶层边缘光（描边）：合进同一张被裁切的合成，与内容共用同一条圆角边——
                // 内容绝不会越过它漏到边缘光外（这正是修复棱角漏边的关键）。
                Rectangle {
                    anchors.fill: parent
                    radius: card.faceRadius
                    color: "transparent"
                    antialiasing: true
                    border.width: card.rimWidth
                    border.color: card.selected ? (card.style ? card.style.faceBorderActive : "#9ef1ffb0")
                                                 : (card.style ? card.style.faceBorder : "#ffffff14")
                }
            }

            // 单一圆角遮罩：整面一次裁圆（含边缘光），封面图随之得到与卡片完全一致的圆角
            Rectangle {
                id: faceMask
                anchors.fill: parent
                radius: card.faceRadius
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
                // 把裁切卡在 50% 覆盖等高线（几何圆角半径），而非默认 0 阈值让抗锯齿淡边整幅透出——
                // 后者使内容圆角实际半径比描边大 ~2px、棱角处越过边缘光漏出。spread 留软过渡保留抗锯齿，
                // 旋转时父层 layer.samples:4 再做一次重采样。
                maskThresholdMin: card.maskThresholdMin
                maskSpreadAtMin: card.maskSpreadAtMin
            }
        }

        back: Item {
            anchors.fill: parent

            // 同正面：整张背面（底色 + 淡背景图 + 暗罩 + 文本 + 顶层边缘光）合成进一张多重采样 layer，
            // Flipable 旋转的是这张单一已抗锯齿纹理。仅 selected 开（只有选中卡会翻面）。
            layer.enabled: card.selected
            layer.samples: 4
            layer.smooth: true

            // 背面整面方角合成，再单一圆角遮罩一次裁切（含边缘光），避免方角/图片溢出卡片圆角。
            Item {
                id: backArtSrc
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.samples: 4
                layer.smooth: true

                // 底色（方角，交给下方遮罩裁圆）
                Rectangle {
                    anchors.fill: parent
                    color: card.style ? card.style.faceBg : "#0D121D"
                }
                // 淡背景：APP 专属 appColor 低透明晕染（取代游戏海报），仍是 APP 专属色调。
                Rectangle {
                    anchors.fill: parent
                    color: card.app ? AppVisual.modelAppColor(card.app) : AppVisual.appColor("", "", "")
                    opacity: 0.16
                }
                Rectangle {
                    anchors.fill: parent
                    color: card.style && card.style.night ? Qt.rgba(0.05, 0.07, 0.11, 0.93) : Qt.rgba(1, 1, 1, 0.86)
                }

                // 文本区
                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14
                    Text {
                        width: parent.width
                        text: card.app ? I18n.smartText(card.languageMode, card.app.mood) : ""
                        color: card.style ? card.style.textPrimary : "#fff"
                        font.pixelSize: card.selected ? 30 : 20
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: card.app ? I18n.smartText(card.languageMode, card.app.analysis) : ""
                        color: card.style ? card.style.textSecondary : "#bbb"
                        font.pixelSize: 14
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: parent.width
                            height: 58
                            radius: 16
                            color: card.style ? card.style.cardBg : "#ffffff12"
                            border.width: 1
                            border.color: card.style ? card.style.cardBorder : "#ffffff16"
                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 3
                                Text {
                                    width: parent.width
                                    text: I18n.t(card.languageMode, "总使用")
                                    color: card.style ? card.style.textSecondary : "#ccc"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: card.app ? I18n.smartText(card.languageMode, card.app.totalTime || card.app.time) : "0m"
                                    color: card.style ? card.style.accentText : "#9FE7EE"
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        Row {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: card.app ? [
                                    { k: "本年", v: card.app.yearTime },
                                    { k: "本月", v: card.app.monthTime },
                                    { k: "今日", v: card.app.dayTime }
                                ] : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: (parent.width - 16) / 3
                                    height: 52
                                    radius: 14
                                    color: card.style ? card.style.cardBg : "#ffffff12"
                                    border.width: 1
                                    border.color: card.style ? card.style.cardBorder : "#ffffff16"
                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 12
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: I18n.t(card.languageMode, modelData.k)
                                            color: card.style ? card.style.textTertiary : "#aaa"
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: I18n.smartText(card.languageMode, modelData.v || "0m")
                                            color: card.style ? card.style.textPrimary : "#fff"
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
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
                                    height: 40
                                    radius: 14
                                    color: card.style ? card.style.cardBg : "#ffffff12"
                                    border.width: 1
                                    border.color: card.style ? card.style.cardBorder : "#ffffff16"
                                    Text {
                                        anchors.centerIn: parent
                                        text: I18n.t(card.languageMode, modelData.k) + "  " + I18n.smartText(card.languageMode, modelData.v)
                                        color: card.style ? card.style.textSecondary : "#ccc"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // 顶层边缘光（描边）：合进同一张被裁切的合成，与内容共用同一条圆角边
                Rectangle {
                    anchors.fill: parent
                    radius: card.faceRadius
                    color: "transparent"
                    antialiasing: true
                    border.width: card.rimWidth
                    border.color: card.style ? card.style.faceBorderActive : "#9ef1ffb0"
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
                radius: card.faceRadius
            }
            MultiEffect {
                anchors.fill: parent
                source: backArtSrc
                maskEnabled: true
                maskSource: backArtMask
                maskThresholdMin: card.maskThresholdMin
                maskSpreadAtMin: card.maskSpreadAtMin
            }
        }
    }

    // 高光划过（设计稿 .card:hover 玻璃反光 / cookbook §3.6「扫光只在 :hover 时出现」）：
    // 悬停时一道斜向高光反复扫过卡面（玻璃反光质感）。独立叠层 z:2，不进翻面合成；
    // RoundedFrame round-clip 收在卡面圆角内（clip:true 只裁矩形会让斜光戳出圆角成方角）。仅正面、仅悬停时跑。
    RoundedFrame {
        id: sheen
        anchors.fill: parent
        radius: card.faceRadius
        z: 2
        visible: card.hovered && !card.flipped
        Rectangle {
            id: sheenBar
            width: parent.width * 0.4
            height: parent.height * 1.9
            y: -parent.height * 0.45
            rotation: 16
            transformOrigin: Item.Center
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: card.style && !card.style.night ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            SequentialAnimation on x {
                running: sheen.visible
                loops: Animation.Infinite
                NumberAnimation { from: -card.width * 0.5; to: card.width * 1.1; duration: 820; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 1700 }
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
