import QtQuick
import QtQuick.Effects
import "MemoryLakeMock.js" as Mock

// 月度记忆回顾全屏覆盖层：自动播放 11 屏 + 进度条 + 看完解锁目录 + 滚轮/键盘/点击导航。
// 1:1 对应设计稿 .summary-overlay 全套逻辑。
Item {
    id: recap

    property MemoryLakeStyle style
    property var apps: []

    property bool opened: false
    property int index: 0
    property int seenMax: 0
    property bool autoPlay: true

    readonly property var slides: Mock.recap.slides
    readonly property bool storyComplete: seenMax >= slides.length - 1
    readonly property int bgIndex: slides[index] ? slides[index].bgIndex : -1

    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    scale: opened ? 1 : 0.985
    // .summary-overlay open/close：.46s cubic-bezier(.2,.8,.2,1)
    Behavior on opacity { NumberAnimation { duration: 460; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
    Behavior on scale { NumberAnimation { duration: 460; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
    focus: opened

    function open() {
        index = 0; seenMax = 0; autoPlay = true
        opened = true
        recap.forceActiveFocus()
        schedule()
    }
    function close() { opened = false; autoTimer.stop() }
    function setSlide(i, fromAuto) {
        index = Math.max(0, Math.min(slides.length - 1, i))
        seenMax = Math.max(seenMax, index)
        if (!fromAuto) autoPlay = false
        schedule()
    }
    function schedule() {
        autoTimer.stop()
        if (autoPlay && opened && index < slides.length - 1) {
            autoTimer.interval = index <= 1 ? 3200 : 4200
            autoTimer.restart()
        } else if (index >= slides.length - 1) {
            autoPlay = false
        }
    }

    Timer {
        id: autoTimer
        onTriggered: if (recap.autoPlay && recap.opened) recap.setSlide(recap.index + 1, true)
    }

    Keys.onPressed: function(e) {
        if (!opened) return
        if (e.key === Qt.Key_Escape) { close(); e.accepted = true }
        else if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Right || e.key === Qt.Key_Down) { setSlide(index + 1, false); e.accepted = true }
        else if (storyComplete && (e.key === Qt.Key_Left || e.key === Qt.Key_Up)) { setSlide(index - 1, false); e.accepted = true }
    }

    // 暗底
    Rectangle {
        anchors.fill: parent
        color: recap.style && recap.style.night ? Qt.rgba(0.008, 0.02, 0.04, 0.86) : Qt.rgba(0.10, 0.12, 0.18, 0.74)
    }

    // shell
    Rectangle {
        id: shell
        anchors.fill: parent
        anchors.margins: 22
        radius: 30
        color: recap.style && recap.style.night ? Qt.rgba(0.024, 0.04, 0.07, 0.82) : Qt.rgba(1, 1, 1, 0.55)
        border.width: 1
        border.color: recap.style ? recap.style.panelBorderStrong : "#ffffff20"
        clip: true

        // .summary-shell 入场：translateY(28→0) + scale(.965→1) .58s cubic-bezier(.16,.9,.2,1)
        // （设计稿另有 filter blur(10→0)，按 fidelity-gaps 性能取舍以位移+缩放+透明近似，不逐帧模糊整壳）
        opacity: recap.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        transform: [
            Translate {
                y: recap.opened ? 0 : 28
                Behavior on y { NumberAnimation { duration: 580; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] } }
            },
            Scale {
                origin.x: shell.width / 2; origin.y: shell.height / 2
                xScale: recap.opened ? 1 : 0.965
                yScale: recap.opened ? 1 : 0.965
                Behavior on xScale { NumberAnimation { duration: 580; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] } }
                Behavior on yScale { NumberAnimation { duration: 580; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] } }
            }
        ]

        // 模糊主角背景
        Item {
            id: bgSrc
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Image {
                anchors.fill: parent
                source: recap.bgIndex >= 0 && recap.apps[recap.bgIndex] ? Mock.imagePath(recap.apps[recap.bgIndex].image) : ""
                fillMode: Image.PreserveAspectCrop
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: bgSrc
            blurEnabled: true
            // .summary-bg-app: blur(42px) saturate(.92) brightness(.78) opacity .40 (v25)
            blur: 0.66
            blurMax: 64
            brightness: -0.22
            saturation: -0.08
            opacity: recap.bgIndex >= 0 ? (recap.style && recap.style.night ? 0.4 : 0.28) : 0
            Behavior on opacity { NumberAnimation { duration: 550 } }
        }

        // 流光（mix-blend screen 的近似：加色半透明渐变，详见 fidelity-gaps 🔴2）
        Rectangle {
            id: wave
            anchors.fill: parent
            rotation: -8
            // .summary-wave 入场：opacity 0→.34、scale 1.14→1.25 (.78s)
            scale: recap.opened ? 1.25 : 1.14
            opacity: recap.opened ? 0.34 : 0
            Behavior on scale { NumberAnimation { duration: 780; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] } }
            Behavior on opacity { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.42; color: Qt.rgba(0.62, 0.90, 0.93, 0.08) }
                GradientStop { position: 0.56; color: Qt.rgba(0.61, 0.55, 1.0, 0.12) }
                GradientStop { position: 0.66; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            SequentialAnimation on x {
                running: recap.opened
                loops: Animation.Infinite
                NumberAnimation { from: -40; to: 60; duration: 8000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 60; to: -40; duration: 8000; easing.type: Easing.InOutSine }
            }
        }

        // 底部光环
        GlowCircle {
            width: 920; height: 420
            x: shell.width / 2 - 460
            y: shell.height - 190
            glowColor: recap.style ? recap.style.violet : "#9B8BFF"
            glowOpacity: (recap.style ? recap.style.glowStrength : 1) * 0.18
            blurAmount: 1.0
            // .summary-glow-ring 入场：scale .82→1 (.72s) + opacity 0→1 (.52s)
            scale: recap.opened ? 1 : 0.82
            opacity: recap.opened ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 720; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] } }
            Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
        }

        // topbar
        Item {
            id: topbar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64

            // 错峰入场 transition-delay .08s（opacity 0→1 + translateY 14→0）
            opacity: 0
            transform: Translate { id: topbarT; y: 14 }
            SequentialAnimation {
                running: recap.opened
                PauseAnimation { duration: 80 }
                ParallelAnimation {
                    NumberAnimation { target: topbar; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                    NumberAnimation { target: topbarT; property: "y"; from: 14; to: 0; duration: 520; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                RecapPill { text: Mock.recap.headerLeft }
                RecapPill { text: Mock.recap.headerRight }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Rectangle {
                    width: pauseT.width + 28; height: 34; radius: 17
                    color: recap.style ? recap.style.cardBg : "#ffffff14"
                    border.width: 1; border.color: recap.style ? recap.style.cardBorder : "#ffffff20"
                    Text { id: pauseT; anchors.centerIn: parent; text: recap.autoPlay ? "暂停" : "继续"; color: recap.style ? recap.style.textPrimary : "#fff"; font.pixelSize: 12; font.bold: true }
                    TapHandler { onTapped: { recap.autoPlay = !recap.autoPlay; recap.schedule() } }
                }
                Rectangle {
                    width: closeT.width + 28; height: 34; radius: 17
                    color: recap.style && recap.style.night ? Qt.rgba(1, 1, 1, 0.84) : "#2D2724"
                    Text { id: closeT; anchors.centerIn: parent; text: "返回湖面"; color: recap.style && recap.style.night ? "#05070D" : "#fff"; font.pixelSize: 12; font.bold: true }
                    TapHandler { onTapped: recap.close() }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: recap.style ? recap.style.panelBorder : "#ffffff14" }
        }

        // mode note
        Rectangle {
            id: modeNote
            anchors.top: topbar.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 26
            width: noteT.width + 28; height: 34; radius: 17
            color: Qt.rgba(0, 0, 0, 0.28)
            border.width: 1; border.color: recap.style ? recap.style.panelBorder : "#ffffff14"

            // 错峰入场 ~.12s
            opacity: 0
            transform: Translate { id: modeNoteT; y: 14 }
            SequentialAnimation {
                running: recap.opened
                PauseAnimation { duration: 120 }
                ParallelAnimation {
                    NumberAnimation { target: modeNote; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                    NumberAnimation { target: modeNoteT; property: "y"; from: 14; to: 0; duration: 520; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] }
                }
            }

            Text {
                id: noteT
                anchors.centerIn: parent
                text: recap.storyComplete ? "已看完 · 右侧目录已解锁，可自由回看" : Mock.recap.modeNote
                color: recap.storyComplete ? (recap.style ? recap.style.accentText : "#9ef1ff") : (recap.style ? recap.style.textSecondary : "#bbb")
                font.pixelSize: 12
            }
        }

        // content：stage + 目录
        Item {
            id: content
            anchors.top: modeNote.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.bottomMargin: 40

            // 错峰入场 transition-delay .16s（stage + 目录整体）
            opacity: 0
            transform: Translate { id: contentT; y: 14 }
            SequentialAnimation {
                running: recap.opened
                PauseAnimation { duration: 160 }
                ParallelAnimation {
                    NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                    NumberAnimation { target: contentT; property: "y"; from: 14; to: 0; duration: 520; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] }
                }
            }

            // stage
            Rectangle {
                id: stage
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width - (recap.storyComplete ? 318 : 0)
                Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
                radius: 28
                color: recap.style ? Qt.rgba(0, 0, 0, recap.style.night ? 0.4 : 0.2) : "#00000066"
                border.width: 1; border.color: recap.style ? recap.style.cardBorder : "#ffffff16"
                clip: true

                Repeater {
                    model: recap.slides
                    delegate: RecapSlide {
                        required property int index
                        required property var modelData
                        anchors.fill: parent
                        style: recap.style
                        apps: recap.apps
                        slideData: modelData
                        active: index === recap.index
                        playing: index === recap.index && recap.opened
                    }
                }

                TapHandler { onTapped: recap.setSlide(recap.index + 1, false) }
                WheelHandler {
                    enabled: recap.storyComplete
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) { recap.setSlide(recap.index + (event.angleDelta.y > 0 ? -1 : 1), false) }
                }
            }

            // 目录
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 300
                radius: 28
                color: recap.style ? Qt.rgba(0, 0, 0, recap.style.night ? 0.3 : 0.16) : "#00000055"
                border.width: 1; border.color: recap.style ? recap.style.cardBorder : "#ffffff16"
                opacity: recap.storyComplete ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 420 } }

                SilkyFlickable {
                    anchors.fill: parent
                    anchors.margins: 16
                    style: recap.style
                    Column {
                        width: parent.width
                        spacing: 9
                        Repeater {
                            model: recap.slides
                            delegate: Rectangle {
                                required property int index
                                required property var modelData
                                width: parent.width
                                height: 58
                                radius: 18
                                color: recap.index === index ? (recap.style ? recap.style.accentSoft : "#8edfff22") : (recap.style ? recap.style.cardBg : "#ffffff0c")
                                border.width: 1
                                border.color: recap.index === index ? (recap.style ? recap.style.accentSoftBorder : "#8edfff55") : (recap.style ? recap.style.cardBorder : "#ffffff10")
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Column {
                                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                    Text { text: "Step " + String(index + 1).padStart(2, "0"); color: recap.style ? recap.style.textTertiary : "#888"; font.pixelSize: 11 }
                                    Text { text: modelData.step; color: recap.style ? recap.style.textPrimary : "#fff"; font.pixelSize: 14; font.bold: true }
                                }
                                TapHandler { onTapped: recap.setSlide(index, false) }
                            }
                        }
                    }
                }
            }
        }

        // 进度条
        Rectangle {
            id: progressBar
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 28; anchors.rightMargin: 28; anchors.bottomMargin: 24
            height: 4; radius: 2
            color: recap.style ? recap.style.trackBg : "#ffffff1a"

            // 错峰入场 transition-delay .28s
            opacity: 0
            transform: Translate { id: progressBarT; y: 14 }
            SequentialAnimation {
                running: recap.opened
                PauseAnimation { duration: 280 }
                ParallelAnimation {
                    NumberAnimation { target: progressBar; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                    NumberAnimation { target: progressBarT; property: "y"; from: 14; to: 0; duration: 520; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 0.9, 0.2, 1, 1, 1] }
                }
            }

            Rectangle {
                height: parent.height; radius: 2
                width: parent.width * ((recap.index + 1) / recap.slides.length)
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: recap.style ? recap.style.aqua : "#8cf3ff" }
                    GradientStop { position: 0.5; color: recap.style ? recap.style.violet : "#8a7dff" }
                    GradientStop { position: 1; color: recap.style ? recap.style.pink : "#ff76cb" }
                }
            }
        }
    }

    component RecapPill: Rectangle {
        property alias text: pt.text
        width: pt.width + 28; height: 34; radius: 17
        color: Qt.rgba(0, 0, 0, 0.20)
        border.width: 1; border.color: recap.style ? recap.style.panelBorder : "#ffffff14"
        Text { id: pt; anchors.centerIn: parent; color: recap.style ? recap.style.textSecondary : "#bbb"; font.pixelSize: 12 }
    }
}
