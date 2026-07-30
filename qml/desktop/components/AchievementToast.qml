import QtQuick
import QtQuick.Effects
import "PlatformCursor.js" as Cursor

Item {
    id: root

    visible: active
    enabled: visible
    z: 200

    property bool nightMode: false
    property bool active: false

    property int toastWidth: 400
    property int toastHeight: 154

    property string headerText: "Achievement unlocked"
    property string titleText: "Night Owl"
    property string subtitleText: "Demo unlock"
    property string rarityText: "LEGENDARY"
    property url imageSource: ""
    property color accentColor: nightMode ? "#F3D784" : "#D9A93A"
    property int displayDuration: 2200
    property real glowSpread: 0
    property real burstProgress: 1.0
    property var particleSpecs: [
        { startX: 72, startY: 52, endX: 16, endY: 18, size: 8, alpha: 0.78, delay: 0.00, diamond: false },
        { startX: 102, startY: 30, endX: 58, endY: -6, size: 7, alpha: 0.66, delay: 0.04, diamond: true },
        { startX: 142, startY: 18, endX: 118, endY: -22, size: 6, alpha: 0.58, delay: 0.08, diamond: false },
        { startX: 194, startY: 8, endX: 188, endY: -30, size: 6, alpha: 0.46, delay: 0.12, diamond: true },
        { startX: 456, startY: 22, endX: 510, endY: -8, size: 8, alpha: 0.80, delay: 0.02, diamond: false },
        { startX: 502, startY: 46, endX: 570, endY: 22, size: 7, alpha: 0.66, delay: 0.08, diamond: true },
        { startX: 534, startY: 78, endX: 604, endY: 72, size: 6, alpha: 0.54, delay: 0.12, diamond: false },
        { startX: 538, startY: 112, endX: 612, endY: 126, size: 7, alpha: 0.50, delay: 0.16, diamond: false },
        { startX: 82, startY: 176, endX: 18, endY: 208, size: 8, alpha: 0.66, delay: 0.10, diamond: false },
        { startX: 126, startY: 194, endX: 74, endY: 234, size: 7, alpha: 0.58, delay: 0.16, diamond: true },
        { startX: 184, startY: 208, endX: 158, endY: 248, size: 6, alpha: 0.48, delay: 0.20, diamond: false },
        { startX: 466, startY: 184, endX: 538, endY: 220, size: 8, alpha: 0.72, delay: 0.08, diamond: false },
        { startX: 516, startY: 166, endX: 594, endY: 192, size: 6, alpha: 0.60, delay: 0.14, diamond: false },
        { startX: 548, startY: 144, endX: 620, endY: 146, size: 5, alpha: 0.46, delay: 0.18, diamond: true },
        { startX: 276, startY: 2, endX: 276, endY: -34, size: 6, alpha: 0.50, delay: 0.06, diamond: true },
        { startX: 324, startY: 214, endX: 338, endY: 254, size: 7, alpha: 0.48, delay: 0.22, diamond: false },
        { startX: 242, startY: 218, endX: 228, endY: 256, size: 6, alpha: 0.44, delay: 0.18, diamond: true },
        { startX: 356, startY: 0, endX: 370, endY: -28, size: 5, alpha: 0.40, delay: 0.10, diamond: false }
    ]

    readonly property color panelColor: nightMode ? "#3E465F" : "#FFFDF9"
    readonly property color borderColor: nightMode ? "#746A4D" : "#E8E0D8"
    readonly property color textPrimary: nightMode ? "#F7F2E5" : "#2D2724"
    readonly property color textSecondary: nightMode ? "#DDD1B4" : "#7C746D"
    readonly property color glowColor: Qt.rgba(accentColor.r, accentColor.g,
                                               accentColor.b,
                                               nightMode ? 0.42 : 0.36)
    readonly property color creamGlowColor: Qt.rgba(0.98, 0.90, 0.63,
                                                    nightMode ? 0.14 : 0.24)
    readonly property color stageFillColor: Qt.rgba(nightMode ? 0.30 : 0.98,
                                                    nightMode ? 0.32 : 0.95,
                                                    nightMode ? 0.41 : 0.87,
                                                    nightMode ? 0.62 : 0.84)
    readonly property color stageBorderColor: Qt.rgba(accentColor.r,
                                                      accentColor.g,
                                                      accentColor.b,
                                                      nightMode ? 0.20 : 0.26)
    readonly property color dimColor: nightMode ? "#7A101621" : "#541D1710"

    component StageSparkle: Item {
        property color sparkleColor: "#FFFFFF"

        width: 28
        height: 28

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 2
            rotation: 45
            color: parent.sparkleColor
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: 18
            radius: 1
            color: parent.sparkleColor
        }

        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 2
            radius: 1
            color: parent.sparkleColor
        }

        Rectangle {
            x: 20
            y: 4
            width: 4
            height: 4
            radius: 2
            color: parent.sparkleColor
            opacity: 0.72
        }
    }

    function showAchievement(title, subtitle, source, glow, rarity, header) {
        if (title !== undefined && title !== null)
            titleText = title
        if (subtitle !== undefined && subtitle !== null)
            subtitleText = subtitle
        if (source !== undefined && source !== null)
            imageSource = source
        if (glow !== undefined && glow !== null)
            accentColor = glow
        if (rarity !== undefined && rarity !== null)
            rarityText = rarity
        if (header !== undefined && header !== null)
            headerText = header

        active = true
        holdTimer.stop()
        intro.stop()
        pulse.stop()
        outro.stop()

        backdrop.opacity = 0
        toastContainer.opacity = 0
        toastContainer.scale = 0.94
        toastContainer.y = 16
        stagePulse.opacity = 0
        stagePulse.scale = 0.96
        iconPulse.opacity = 0
        iconPulse.scale = 0.90
        glowSpread = 0
        burstProgress = 0

        intro.start()
        pulse.start()
        holdTimer.start()
    }

    function hideAchievement() {
        if (!active)
            return

        holdTimer.stop()
        if (!outro.running)
            outro.start()
    }

    Timer {
        id: holdTimer
        interval: root.displayDuration
        repeat: false
        onTriggered: root.hideAchievement()
    }

    ParallelAnimation {
        id: intro

        NumberAnimation {
            target: backdrop
            property: "opacity"
            from: 0
            to: 1
            duration: 180
        }

        NumberAnimation {
            target: toastContainer
            property: "opacity"
            from: 0
            to: 1
            duration: 180
        }

        NumberAnimation {
            target: toastContainer
            property: "scale"
            from: 0.94
            to: 1.0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: toastContainer
            property: "y"
            from: 16
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: pulse

        ParallelAnimation {
            NumberAnimation {
                target: stagePulse
                property: "opacity"
                from: 0.22
                to: 0
                duration: 520
            }

            NumberAnimation {
                target: stagePulse
                property: "scale"
                from: 0.96
                to: 1.07
                duration: 520
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: iconPulse
                property: "opacity"
                from: 0.24
                to: 0
                duration: 380
            }

            NumberAnimation {
                target: iconPulse
                property: "scale"
                from: 0.90
                to: 1.06
                duration: 380
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "burstProgress"
                from: 0
                to: 1
                duration: 720
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "glowSpread"
                from: 0
                to: 1
                duration: 760
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: outro

        NumberAnimation {
            target: backdrop
            property: "opacity"
            from: backdrop.opacity
            to: 0
            duration: 220
        }

        NumberAnimation {
            target: toastContainer
            property: "opacity"
            from: toastContainer.opacity
            to: 0
            duration: 220
        }

        NumberAnimation {
            target: toastContainer
            property: "scale"
            from: toastContainer.scale
            to: 0.98
            duration: 220
        }

        NumberAnimation {
            target: toastContainer
            property: "y"
            from: toastContainer.y
            to: 10
            duration: 220
        }

        onStopped: root.active = false
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: root.dimColor
        opacity: 0
    }

    Item {
        id: toastContainer
        width: root.toastWidth + 124
        height: root.toastHeight + 104
        anchors.centerIn: parent
        opacity: 0
        scale: 0.94
        y: 16
        transformOrigin: Item.Center

        Rectangle {
            id: creamGlowSource
            anchors.centerIn: parent
            width: root.toastWidth + 188 + root.glowSpread * 96
            height: root.toastHeight + 118 + root.glowSpread * 40
            radius: height / 2
            color: root.creamGlowColor
            visible: false
        }

        MultiEffect {
            anchors.centerIn: creamGlowSource
            width: creamGlowSource.width + 54
            height: creamGlowSource.height + 54
            source: creamGlowSource
            blurEnabled: true
            blur: 1.0
            shadowEnabled: true
            shadowColor: root.creamGlowColor
            shadowOpacity: 1.0
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            opacity: root.active ? (root.nightMode ? 0.50 : 0.66) * (1 - root.glowSpread * 0.18) : 0
        }

        Rectangle {
            id: warmGlowSource
            anchors.centerIn: parent
            width: root.toastWidth + 108 + root.glowSpread * 128
            height: root.toastHeight + 54 + root.glowSpread * 56
            radius: height / 2
            color: root.glowColor
            visible: false
        }

        MultiEffect {
            anchors.centerIn: warmGlowSource
            width: warmGlowSource.width + 60
            height: warmGlowSource.height + 60
            source: warmGlowSource
            blurEnabled: true
            blur: 1.0
            shadowEnabled: true
            shadowColor: root.glowColor
            shadowOpacity: 1.0
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            opacity: root.active ? (root.nightMode ? 0.54 : 0.64) * (1 - root.glowSpread * 0.30) : 0
        }

        Rectangle {
            id: burstGlowSource
            anchors.centerIn: parent
            width: root.toastWidth + 34 + root.glowSpread * 156
            height: root.toastHeight + 8 + root.glowSpread * 62
            radius: height / 2
            color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                           root.accentColor.b,
                           root.nightMode ? 0.20 : 0.16)
            visible: false
        }

        MultiEffect {
            anchors.centerIn: burstGlowSource
            width: burstGlowSource.width + 52 + root.glowSpread * 36
            height: burstGlowSource.height + 52 + root.glowSpread * 36
            source: burstGlowSource
            blurEnabled: true
            blur: 1.0
            shadowEnabled: true
            shadowColor: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                 root.accentColor.b,
                                 root.nightMode ? 0.28 : 0.22)
            shadowOpacity: 1.0
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            opacity: root.active ? (root.nightMode ? 0.42 : 0.48) * (1 - root.glowSpread * 0.46) : 0
        }

        Rectangle {
            id: stagePlate
            anchors.centerIn: parent
            width: root.toastWidth + 178
            height: root.toastHeight + 86
            radius: height / 2
            color: root.stageFillColor
            border.width: 1
            border.color: root.stageBorderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: height / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                       root.accentColor.b,
                                       root.nightMode ? 0.10 : 0.14)
                    }
                    GradientStop {
                        position: 0.42
                        color: Qt.rgba(0.99, 0.94, 0.78,
                                       root.nightMode ? 0.05 : 0.10)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            Repeater {
                model: [-56, -28, 0, 28, 56]

                delegate: Rectangle {
                    required property var modelData

                    width: 4
                    height: 74
                    radius: 2
                    anchors.centerIn: parent
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                   root.accentColor.b,
                                   root.nightMode ? 0.05 : 0.07)
                    rotation: modelData
                }
            }
        }

        Rectangle {
            id: stagePulse
            anchors.centerIn: parent
            width: stagePlate.width - 22
            height: stagePlate.height - 18
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                  root.accentColor.b, 0.22)
            opacity: 0
            scale: 0.96
        }

        Repeater {
            model: root.particleSpecs

            delegate: Item {
                required property var modelData

                readonly property real localProgress: Math.max(
                                                          0,
                                                          Math.min(
                                                              1,
                                                              (root.burstProgress - modelData.delay)
                                                              / Math.max(
                                                                  0.001,
                                                                  1 - modelData.delay)))

                x: modelData.startX + (modelData.endX - modelData.startX) * localProgress
                y: modelData.startY + (modelData.endY - modelData.startY) * localProgress
                width: modelData.size + 8
                height: modelData.size + 8
                opacity: root.active ? modelData.alpha * (1 - localProgress) : 0
                scale: 0.74 + localProgress * 0.40
                rotation: modelData.diamond ? 45 + localProgress * 90
                                            : localProgress * 42

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: (parent.width + 6) / 2
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                   root.accentColor.b, 0.22)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: modelData.diamond ? 2 : width / 2
                    color: Qt.rgba(0.99, 0.94, 0.72, 0.98)
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r,
                                          root.accentColor.g,
                                          root.accentColor.b, 0.54)
                }
            }
        }

        StageSparkle {
            x: 30
            y: 26
            rotation: -10
            sparkleColor: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                  root.accentColor.b,
                                  root.nightMode ? 0.46 : 0.60)
        }

        StageSparkle {
            x: toastContainer.width - width - 36
            y: 24
            rotation: 12
            sparkleColor: Qt.rgba(0.99, 0.94, 0.78,
                                  root.nightMode ? 0.40 : 0.54)
        }

        StageSparkle {
            x: 86
            y: 8
            scale: 0.70
            rotation: 18
            sparkleColor: Qt.rgba(0.99, 0.94, 0.78,
                                  root.nightMode ? 0.30 : 0.46)
        }

        StageSparkle {
            x: toastContainer.width / 2 - width / 2
            y: 10
            scale: 0.58
            rotation: -4
            sparkleColor: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                  root.accentColor.b,
                                  root.nightMode ? 0.24 : 0.36)
        }

        StageSparkle {
            x: toastContainer.width - width - 92
            y: 6
            scale: 0.72
            rotation: -14
            sparkleColor: Qt.rgba(0.99, 0.94, 0.78,
                                  root.nightMode ? 0.28 : 0.44)
        }

        StageSparkle {
            x: 52
            y: toastContainer.height - height - 26
            scale: 0.82
            rotation: 8
            sparkleColor: Qt.rgba(0.99, 0.94, 0.78,
                                  root.nightMode ? 0.30 : 0.42)
        }

        StageSparkle {
            x: toastContainer.width - width - 58
            y: toastContainer.height - height - 30
            scale: 0.92
            rotation: -8
            sparkleColor: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                  root.accentColor.b,
                                  root.nightMode ? 0.40 : 0.52)
        }

        StageSparkle {
            x: 108
            y: toastContainer.height - height - 14
            scale: 0.62
            rotation: -12
            sparkleColor: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                  root.accentColor.b,
                                  root.nightMode ? 0.22 : 0.34)
        }

        StageSparkle {
            x: toastContainer.width / 2 - width / 2 + 26
            y: toastContainer.height - height - 8
            scale: 0.56
            rotation: 6
            sparkleColor: Qt.rgba(0.99, 0.94, 0.78,
                                  root.nightMode ? 0.20 : 0.32)
        }

        StageSparkle {
            x: toastContainer.width - width - 114
            y: toastContainer.height - height - 16
            scale: 0.68
            rotation: 10
            sparkleColor: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                  root.accentColor.b,
                                  root.nightMode ? 0.26 : 0.40)
        }

        SoftCard {
            id: toastBody
            width: root.toastWidth
            height: root.toastHeight
            anchors.centerIn: parent
            radius: 30
            padding: 20
            fillColor: root.panelColor
            fillOpacity: root.nightMode ? 0.92 : 0.97
            strokeColor: root.borderColor
            shadowColor: root.nightMode ? "#05070D" : "#BFAE9D"
            shadowOpacity: root.nightMode ? 0.18 : 0.11
            shadowOffset: 10

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                       root.accentColor.b,
                                       root.nightMode ? 0.10 : 0.08)
                    }
                    GradientStop {
                        position: 0.44
                        color: Qt.rgba(0.99, 0.96, 0.90,
                                       root.nightMode ? 0.04 : 0.07)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
                z: -1
            }

            Row {
                anchors.fill: parent
                spacing: 16

                Item {
                    width: 84
                    height: parent.height

                    Rectangle {
                        id: iconGlowSource
                        anchors.centerIn: parent
                        width: 46
                        height: 46
                        radius: 23
                        color: root.glowColor
                        visible: false
                    }

                    MultiEffect {
                        anchors.centerIn: iconGlowSource
                        width: iconGlowSource.width + 48
                        height: iconGlowSource.height + 48
                        source: iconGlowSource
                        blurEnabled: true
                        blur: 1.0
                        shadowEnabled: true
                        shadowColor: root.glowColor
                        shadowOpacity: 1.0
                        shadowBlur: 1.0
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        opacity: root.active ? 0.36 : 0
                    }

                    Rectangle {
                        id: iconPulse
                        anchors.centerIn: parent
                        width: 68
                        height: 68
                        radius: 34
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(root.accentColor.r,
                                              root.accentColor.g,
                                              root.accentColor.b, 0.22)
                        opacity: 0
                        scale: 0.90
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 66
                        height: 66
                        radius: 33
                        color: Qt.rgba(0.99, 0.97, 0.92,
                                       root.nightMode ? 0.12 : 0.88)
                        border.width: 1
                        border.color: Qt.rgba(root.accentColor.r,
                                              root.accentColor.g,
                                              root.accentColor.b, 0.38)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 27
                            color: root.nightMode ? "#495170" : "#FFFDF9"
                            clip: true

                            Image {
                                id: iconImage
                                anchors.centerIn: parent
                                width: 38
                                height: 38
                                source: root.imageSource
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                mipmap: true
                                visible: source.toString().length > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "A"
                                color: root.textPrimary
                                font.pixelSize: 20
                                font.bold: true
                                visible: !iconImage.visible
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - 100
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Row {
                        spacing: 8

                        Rectangle {
                            width: unlockLabel.implicitWidth + 26
                            height: 24
                            radius: 12
                            color: Qt.rgba(0.99, 0.97, 0.92,
                                           root.nightMode ? 0.12 : 0.84)
                            border.width: 1
                            border.color: Qt.rgba(root.accentColor.r,
                                                  root.accentColor.g,
                                                  root.accentColor.b, 0.24)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Qt.rgba(root.accentColor.r,
                                                   root.accentColor.g,
                                                   root.accentColor.b, 0.72)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✦"
                                        color: "#FFFDF9"
                                        font.pixelSize: 8
                                        font.bold: true
                                    }
                                }

                                Text {
                                    id: unlockLabel
                                    text: root.headerText
                                    color: root.textSecondary
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }

                        Rectangle {
                            width: rarityLabel.implicitWidth + 16
                            height: 24
                            radius: 12
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(root.accentColor.r,
                                                   root.accentColor.g,
                                                   root.accentColor.b,
                                                   root.nightMode ? 0.24 : 0.20)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.rgba(0.99, 0.96, 0.88,
                                                   root.nightMode ? 0.10 : 0.18)
                                }
                            }
                            border.width: 1
                            border.color: Qt.rgba(root.accentColor.r,
                                                  root.accentColor.g,
                                                  root.accentColor.b, 0.30)

                            Text {
                                id: rarityLabel
                                anchors.centerIn: parent
                                text: root.rarityText
                                color: root.textPrimary
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.titleText
                        color: root.textPrimary
                        font.pixelSize: 25
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.subtitleText
                        color: root.textSecondary
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: 86
                        height: 4
                        radius: 2
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                       root.accentColor.b,
                                       root.nightMode ? 0.26 : 0.34)
                    }
                }
            }

            Rectangle {
                width: 20
                height: 20
                radius: 10
                x: 56
                y: 72
                color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                               root.accentColor.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(0.99, 0.97, 0.90,
                                      root.nightMode ? 0.24 : 0.38)

                Text {
                    anchors.centerIn: parent
                    text: "✦"
                    color: "#FFFDF9"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Cursor.button()
        onClicked: root.hideAchievement()
    }
}
