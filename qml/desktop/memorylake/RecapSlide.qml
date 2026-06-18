import QtQuick
import "../components/I18n.js" as I18n

// 月度回顾单屏：kicker + 类型化布局 + 入场转场（zoom/wipe/rise/rotate/ticket）+ 内滚动。
// 1:1 对应设计稿 .summary-slide / 各 data-transition。
Item {
    id: slide

    property MemoryLakeStyle style
    property var slideData
    property var apps: []
    property string languageMode: "zh"
    property bool active: false
    // 由 overlay 注入 = active && opened：用于在"打开瞬间"为当前屏触发入场（active 在关闭时也可能为真）。
    property bool playing: false

    readonly property color tPrimary: style ? style.textPrimary : "#fff"
    readonly property color tSecondary: style ? style.textSecondary : "#bbb"
    readonly property color tTertiary: style ? style.textTertiary : "#888"

    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

    transform: [
        Scale { id: sc; origin.x: slide.width / 2; origin.y: slide.height * 0.6 },
        Rotation { id: ro; origin.x: slide.width / 2; origin.y: slide.height * 0.6; axis: Qt.vector3d(1, 0, 0) },
        Translate { id: tr }
    ]

    onPlayingChanged: if (playing) applyEnter()

    function applyEnter() {
        var t = slideData ? slideData.transition : "rise"
        sc.xScale = 1; sc.yScale = 1; tr.x = 0; tr.y = 0; ro.angle = 0; ro.axis = Qt.vector3d(1, 0, 0)
        if (t === "zoom") { sc.xScale = 1.08; sc.yScale = 1.08 }
        else if (t === "rise") { tr.y = 58 }
        else if (t === "wipe") { tr.x = 44 }
        else if (t === "rotate") { ro.axis = Qt.vector3d(1, 0, 0); ro.angle = 10; tr.y = 38 }
        else if (t === "ticket") { ro.axis = Qt.vector3d(0, 0, 1); ro.angle = -2; tr.y = 42 }
        enterAnim.restart()
        // 屏内内容错峰上浮（recapRise）：kicker 先、正文随后。
        kickerChip.opacity = 0; kickerT.y = 24
        bodyLoader.opacity = 0; bodyT.y = 24
        kickerRise.restart()
        bodyRise.restart()
    }

    function tr(source) { return I18n.t(languageMode, source) }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: sc; property: "xScale"; to: 1; duration: 620; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
        NumberAnimation { target: sc; property: "yScale"; to: 1; duration: 620; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
        NumberAnimation { target: tr; property: "x"; to: 0; duration: 600; easing.type: Easing.OutCubic }
        NumberAnimation { target: tr; property: "y"; to: 0; duration: 620; easing.type: Easing.OutCubic }
        NumberAnimation { target: ro; property: "angle"; to: 0; duration: 640; easing.type: Easing.OutCubic }
    }

    // recapRise：kicker 先（~.06s），正文随后（~.15s），各自 opacity 0→1 + translateY 24→0
    SequentialAnimation {
        id: kickerRise
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: kickerChip; property: "opacity"; from: 0; to: 1; duration: 460; easing.type: Easing.OutCubic }
            NumberAnimation { target: kickerT; property: "y"; from: 24; to: 0; duration: 560; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] }
        }
    }
    SequentialAnimation {
        id: bodyRise
        PauseAnimation { duration: 150 }
        ParallelAnimation {
            NumberAnimation { target: bodyLoader; property: "opacity"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { target: bodyT; property: "y"; from: 24; to: 0; duration: 600; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] }
        }
    }

    SilkyFlickable {
        id: scroller
        anchors.fill: parent
        style: slide.style

        Column {
            id: col
            width: scroller.width
            leftPadding: 42
            rightPadding: 42
            topPadding: 42
            bottomPadding: 56
            spacing: 18

            // kicker
            Rectangle {
                id: kickerChip
                width: kickerText.width + 26
                height: 34
                radius: 17
                color: slide.style ? slide.style.accentSoft : "#ffffff14"
                border.width: 1
                border.color: slide.style ? slide.style.accentSoftBorder : "#ffffff20"
                opacity: 0
                transform: Translate { id: kickerT; y: 24 }
                Text {
                    id: kickerText
                    anchors.centerIn: parent
                    text: slide.slideData ? slide.tr(slide.slideData.kicker) : ""
                    color: slide.style ? slide.style.accentText : "#9ef1ff"
                    font.pixelSize: 13
                }
            }

            Loader {
                id: bodyLoader
                width: col.width - 84
                active: true
                opacity: 0
                transform: Translate { id: bodyT; y: 24 }
                sourceComponent: {
                    if (!slide.slideData) return coverBody
                    switch (slide.slideData.type) {
                    case "cover": return coverBody
                    case "monthMap": return monthMapBody
                    case "poster": return posterBody
                    case "split": return splitBody
                    case "orbit": return orbitBody
                    case "article": return articleBody
                    case "timeline": return timelineBody
                    case "trend": return trendBody
                    case "keywords": return keywordsBody
                    case "comparison": return comparisonBody
                    case "ticket": return ticketBody
                    default: return coverBody
                    }
                }
            }
        }
    }

    // —— 通用文本片段 ——
    // .slide-title 有效最终值（v25）：weight 760 + letter-spacing -2.2 + line-height 1.02。
    component BigTitle: Text {
        width: parent.width
        color: slide.tPrimary
        font.pixelSize: 50
        font.weight: 760
        font.letterSpacing: -2.2
        lineHeight: 1.02
        lineHeightMode: Text.ProportionalHeight
        wrapMode: Text.WordWrap
    }
    component SubText: Text {
        width: parent.width
        color: slide.tSecondary
        font.pixelSize: 16
        lineHeight: 1.6
        wrapMode: Text.WordWrap
    }
    component StatChip: Rectangle {
        property string k: ""
        property string v: ""
        width: 150
        height: 64
        radius: 18
        color: slide.style ? slide.style.cardBg : "#ffffff12"
        border.width: 1
        border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 4
            Text { text: slide.tr(k); color: slide.tTertiary; font.pixelSize: 12 }
            Text { text: slide.tr(v); color: slide.tPrimary; font.pixelSize: 20; font.bold: true }
        }
    }

    // 月度主角 = 月级 apps[bgIndex]（真实当月 Top），喂给生成式封面。
    function protagApp(i) { return (i >= 0 && slide.apps && slide.apps[i]) ? slide.apps[i] : null }

    // —— 01 封面 ——
    Component {
        id: coverBody
        Column {
            spacing: 20
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 54 }
            SubText { text: slide.tr(slide.slideData.subtitle) }
            Row {
                spacing: 18
                Repeater {
                    model: slide.slideData.metrics
                    delegate: Rectangle {
                        required property var modelData
                        width: 190; height: 92; radius: 24
                        color: slide.style ? slide.style.cardBg : "#ffffff12"
                        border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                        Column {
                            anchors.fill: parent; anchors.margins: 18; spacing: 8
                            Text { text: slide.tr(modelData.label); color: slide.tSecondary; font.pixelSize: 13 }
                            Text { text: modelData.value; color: slide.tPrimary; font.pixelSize: 28; font.bold: true }
                        }
                    }
                }
            }
        }
    }

    // —— 02 月初到月末 ——
    Component {
        id: monthMapBody
        Column {
            spacing: 20
            BigTitle { text: slide.tr(slide.slideData.title) }
            SubText { text: slide.tr(slide.slideData.subtitle) }
            Row {
                spacing: 10
                Repeater {
                    model: slide.slideData.monthMap
                    delegate: RoundedFrame {
                        required property var modelData
                        width: 86; height: 92; radius: 18
                        border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                        // 底色
                        Rectangle {
                            anchors.fill: parent
                            color: slide.style ? slide.style.cardBg : "#ffffff10"
                        }
                        // 填充条：方角，整体随帧圆角遮罩一次裁切——矮条保持平顶水位线；满条（如 Jun28 96%）
                        // 顶部自然贴合容器圆角、不再方角溢出（满溢漏顶）；底部同样收圆。比 clip:true（只裁矩形）正确。
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: parent.height * modelData.h
                            gradient: Gradient {
                                GradientStop { position: 0; color: slide.style ? Qt.rgba(slide.style.aqua.r, slide.style.aqua.g, slide.style.aqua.b, 0.18) : "#63eaff30" }
                                GradientStop { position: 1; color: slide.style ? Qt.rgba(slide.style.violet.r, slide.style.violet.g, slide.style.violet.b, 0.40) : "#d15aff66" }
                            }
                        }
                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 2
                            Item { width: 1; height: parent.height - 32 }
                            Text { text: modelData.value; color: slide.tPrimary; font.pixelSize: 15; font.bold: true }
                            Text { text: modelData.day; color: slide.tTertiary; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }
    }

    // —— 03 主角 poster ——
    Component {
        id: posterBody
        Row {
            spacing: 28
            // 圆角裁切帧：封面图 + 底部暗角渐变 + 标题随帧圆角一起裁切，杜绝方角棱角溢出。
            RoundedFrame {
                width: 300; height: 460; radius: 28
                border.width: 1; border.color: slide.style ? slide.style.faceBorder : "#ffffff20"
                GenerativeCover { anchors.fill: parent; style: slide.style; app: slide.protagApp(slide.slideData.bgIndex); iconSize: 150 }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 1; color: slide.style ? slide.style.mediaScrim : Qt.rgba(0, 0, 0, 0.78) }
                    }
                }
                Column {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 22; spacing: 8
                    Text { text: slide.tr(slide.slideData.posterTitle); color: "#fff"; font.pixelSize: 36; font.bold: true }
                    Text { text: slide.tr(slide.slideData.posterSub); color: "#ffffffb0"; font.pixelSize: 14 }
                }
            }
            Column {
                width: 420; spacing: 18
                BigTitle { width: 420; text: slide.tr(slide.slideData.title); font.pixelSize: 40 }
                SubText { width: 420; text: slide.tr(slide.slideData.subtitle) }
                Flow {
                    width: 420; spacing: 12
                    Repeater { model: slide.slideData.stats; delegate: StatChip { required property var modelData; k: modelData.label; v: modelData.value } }
                }
            }
        }
    }

    // —— 04 split ——
    Component {
        id: splitBody
        Row {
            spacing: 24
            Column {
                width: 430; spacing: 18
                BigTitle { width: 430; text: slide.tr(slide.slideData.title); font.pixelSize: 44 }
                SubText { width: 430; text: slide.tr(slide.slideData.subtitle) }
                RoundedFrame {
                    width: 430; height: 250; radius: 28
                    border.width: 1; border.color: slide.style ? slide.style.faceBorder : "#ffffff20"
                    GenerativeCover { anchors.fill: parent; style: slide.style; app: slide.protagApp(slide.slideData.bgIndex); iconSize: 120 }
                    Rectangle { anchors.fill: parent; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: slide.style ? slide.style.mediaScrim : Qt.rgba(0, 0, 0, 0.78) } } }
                }
            }
            Column {
                width: 200; spacing: 14
                Repeater {
                    model: slide.slideData.stats
                    delegate: Rectangle {
                        required property var modelData
                        width: 200; height: 80; radius: 24
                        color: slide.style ? slide.style.cardBg : "#ffffff12"
                        border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                        Column { anchors.fill: parent; anchors.margins: 16; spacing: 4
                            Text { text: slide.tr(modelData.label); color: slide.tTertiary; font.pixelSize: 13 }
                            Text { text: modelData.value; color: slide.tPrimary; font.pixelSize: 26; font.bold: true }
                        }
                    }
                }
            }
        }
    }

    // —— 05 orbit ——
    Component {
        id: orbitBody
        Column {
            spacing: 18
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 40 }
            SubText { text: slide.tr(slide.slideData.subtitle) }
            Item {
                width: parent.width; height: 360
                RoundedFrame {
                    anchors.centerIn: parent
                    width: 220; height: 220; radius: 110   // = 半边长 → 正圆环形头像
                    border.width: 1; border.color: slide.style ? slide.style.faceBorderActive : "#ffffff33"
                    GenerativeCover { anchors.fill: parent; style: slide.style; app: slide.protagApp(slide.slideData.bgIndex); iconSize: 120 }
                }
                Repeater {
                    model: slide.slideData.orbit
                    delegate: Rectangle {
                        required property var modelData
                        width: 150; height: 64; radius: 20
                        color: slide.style ? slide.style.cardBg : "#ffffff12"
                        border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                        x: parent.width / 2 - 75 + Math.cos(modelData.a * Math.PI / 180) * 230
                        y: parent.height / 2 - 32 + Math.sin(modelData.a * Math.PI / 180) * 150
                        Column { anchors.centerIn: parent; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: slide.tPrimary; font.pixelSize: 20; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t(slide.languageMode, modelData.label); color: slide.tTertiary; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }

    // —— 06 article ——
    Component {
        id: articleBody
        Column {
            spacing: 18
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 40 }
            Row {
                spacing: 24
                Rectangle {
                    width: 420; height: 240; radius: 28
                    color: slide.style ? slide.style.cardBg : "#ffffff12"
                    border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                    Column { anchors.fill: parent; anchors.margins: 24; spacing: 12
                        Text { width: parent.width; text: slide.tr(slide.slideData.articleTitle); color: slide.tPrimary; font.pixelSize: 26; font.bold: true; wrapMode: Text.WordWrap }
                        Text { width: parent.width; text: slide.tr(slide.slideData.articleBody); color: slide.tSecondary; font.pixelSize: 15; lineHeight: 1.6; wrapMode: Text.WordWrap }
                    }
                }
                RoundedFrame {
                    width: 260; height: 360; radius: 28
                    border.width: 1; border.color: slide.style ? slide.style.faceBorder : "#ffffff20"
                    GenerativeCover { anchors.fill: parent; style: slide.style; app: slide.protagApp(slide.slideData.bgIndex); iconSize: 120 }
                }
            }
        }
    }

    // —— 07 timeline ——
    Component {
        id: timelineBody
        Column {
            spacing: 18
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 40 }
            SubText { text: slide.tr(slide.slideData.subtitle) }
            Column {
                width: parent.width; spacing: 15
                Repeater {
                    model: slide.slideData.strips
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 78; radius: 22
                        color: slide.style ? slide.style.cardBg : "#ffffff10"
                        border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                        Column {
                            anchors.fill: parent; anchors.margins: 16; spacing: 12
                            Row {
                                width: parent.width
                Text { width: parent.width / 2; text: slide.tr(modelData.tag); color: slide.tSecondary; font.pixelSize: 13 }
                                Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: modelData.apps; color: slide.tPrimary; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                            }
                            Item {
                                width: parent.width; height: 10
                                Rectangle { anchors.fill: parent; radius: 5; color: slide.style ? slide.style.trackBg : "#ffffff14" }
                                Repeater {
                                    model: modelData.segs
                                    delegate: Rectangle {
                                        required property var modelData
                                        x: parent.width * modelData[0]; width: parent.width * modelData[1]
                                        height: 10; radius: 5
                                        gradient: Gradient { orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: slide.style ? slide.style.aqua : "#86f0ff" }
                                            GradientStop { position: 1; color: slide.style ? slide.style.violet : "#d87cff" } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // —— 08 trend ——
    Component {
        id: trendBody
        Column {
            spacing: 18
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 40 }
            SubText { text: slide.tr(slide.slideData.subtitle) }
            Rectangle {
                width: parent.width; height: 230; radius: 28
                color: slide.style ? slide.style.recapStage : Qt.rgba(1, 1, 1, 0.3)
                border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                clip: true
                Canvas {
                    id: trendCanvas
                    anchors.fill: parent
                    anchors.margins: 16
                    // 接真实按天序列（0..1，1=当月最高日）；空/单点不画（断言守卫）。
                    readonly property var series: (slide.slideData && slide.slideData.series) ? slide.slideData.series : []
                    onSeriesChanged: requestPaint()
                    onVisibleChanged: if (visible) requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var pts = trendCanvas.series;
                        if (!pts || pts.length < 2) return;
                        var w = width, h = height;
                        ctx.beginPath();
                        for (var i = 0; i < pts.length; i++) {
                            var x = (i / (pts.length - 1)) * w;
                            var y = (1 - pts[i]) * h;   // 高值 -> 靠顶（湖面水位）
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        var grad = ctx.createLinearGradient(0, 0, w, 0);
                        grad.addColorStop(0, slide.style ? slide.style.aqua : "#63eaff");
                        grad.addColorStop(0.55, slide.style ? slide.style.violet : "#7a7dff");
                        grad.addColorStop(1, slide.style ? slide.style.pink : "#ff67c8");
                        ctx.strokeStyle = grad; ctx.lineWidth = 4; ctx.stroke();
                        ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
                        ctx.fillStyle = "rgba(104,143,255,0.16)"; ctx.fill();
                    }
                }
            }
        }
    }

    // —— 09 keywords ——
    Component {
        id: keywordsBody
        Column {
            spacing: 20
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 40 }
            Flow {
                width: parent.width; spacing: 14
                Repeater {
                    model: slide.slideData.keywords
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool major: modelData === slide.slideData.major
                        width: kw.width + (major ? 52 : 36); height: kw.height + (major ? 36 : 26); radius: height / 2
                        color: major ? (slide.style ? slide.style.accentSoft : "#63eaff20") : (slide.style ? slide.style.cardBg : "#ffffff12")
                        border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                        Text {
                    id: kw; anchors.centerIn: parent; text: slide.tr(modelData)
                            color: slide.tPrimary; font.bold: true
                            font.pixelSize: major ? 30 : 15
                        }
                    }
                }
            }
            SubText { text: slide.tr(slide.slideData.subtitle) }
        }
    }

    // —— 10 comparison ——
    Component {
        id: comparisonBody
        Column {
            spacing: 20
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 40 }
            Flow {
                width: parent.width; spacing: 16
                Repeater {
                    model: slide.slideData.comparisons
                    delegate: Rectangle {
                        required property var modelData
                        width: 230; height: 170; radius: 26
                        color: slide.style ? slide.style.cardBg : "#ffffff12"
                        border.width: 1; border.color: slide.style ? slide.style.cardBorder : "#ffffff16"
                        Column {
                            anchors.fill: parent; anchors.margins: 20; spacing: 10
                    Text { text: slide.tr(modelData.label); color: slide.tSecondary; font.pixelSize: 14 }
                            Text { text: modelData.change; color: modelData.down ? (slide.style ? slide.style.changeDown : "#FF8FB5") : (slide.style ? slide.style.aqua : "#8df3ff"); font.pixelSize: 34; font.bold: true }
                            Text { width: parent.width; text: modelData.desc; color: slide.tTertiary; font.pixelSize: 12; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }
        }
    }

    // —— 11 ticket ——
    Component {
        id: ticketBody
        Column {
            spacing: 20
            BigTitle { text: slide.tr(slide.slideData.title); font.pixelSize: 44 }
            SubText { text: slide.tr(slide.slideData.subtitle) }
            Rectangle {
                width: 300; height: 360; radius: 22
                rotation: -2
                gradient: Gradient {
                    GradientStop { position: 0; color: slide.style ? slide.style.ticketTop : "#DED3BD" }
                    GradientStop { position: 1; color: slide.style ? slide.style.ticketBottom : "#BFAE91" }
                }
                Column {
                    anchors.fill: parent; anchors.margins: 24; spacing: 16
                    Text { text: slide.slideData.ticket.title; color: slide.style ? slide.style.ticketInk : "#1A130D"; font.pixelSize: 34; font.bold: true; lineHeight: 1.0 }
                    Repeater {
                        model: slide.slideData.ticket.rows
                        delegate: Rectangle {
                            required property var modelData
                            width: 252; height: 44; radius: 12; color: slide.style ? slide.style.ticketRow : Qt.rgba(0, 0, 0, 0.08)
                            Text { anchors.centerIn: parent; text: modelData; color: slide.style ? slide.style.ticketInk : "#1A130D"; font.pixelSize: 15; font.bold: true }
                        }
                    }
                }
            }
        }
    }
}
