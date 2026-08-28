import QtQuick
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property var app: ({})
    property bool wallpaperActive: false
    property bool selected: true
    property bool flipped: false
    property real flipAngle: flipped ? 180 : 0
    readonly property real flipDepth:
        Math.sin(flipAngle * Math.PI / 180)
    readonly property real frontFaceAngle: flipAngle
    readonly property real backFaceAngle: flipAngle - 180
    readonly property real frontFaceOpacity:
        Math.max(0, Math.min(1, (100 - flipAngle) / 20))
    readonly property real backFaceOpacity:
        Math.max(0, Math.min(1, (flipAngle - 80) / 20))
    readonly property color frontInk: wallpaperActive
                                               ? theme.wallpaperInk
                                               : theme.textPrimary
    readonly property color frontMuted: wallpaperActive
                                                 ? theme.wallpaperMuted
                                                 : theme.textSecondary

    signal shareRequested(var app)
    signal permissionRequested()
    signal flippedRequested(bool flipped)

    function value(key, fallbackValue) {
        return root.app && root.app[key] !== undefined
                ? root.app[key] : fallbackValue
    }

    Behavior on flipAngle {
        NumberAnimation {
            duration: root.theme.reducedMotion ? 0 : 520
            easing.type: Easing.InOutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8 - root.flipDepth * 3
        radius: root.theme.cardRadius + 2
        color: "transparent"
        border.width: 10
        border.color: root.theme.withAlpha(
                          root.theme.shadowColor,
                          0.10 + root.flipDepth * 0.22)
        opacity: 0.78
        scale: 1 - root.flipDepth * 0.025
    }

    Item {
        id: front
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: root.frontFaceOpacity
        scale: 1 - root.flipDepth * 0.035
        transformOrigin: Item.Center
        transform: Rotation {
            origin.x: front.width / 2
            origin.y: front.height / 2
            axis: Qt.vector3d(0, 1, 0)
            angle: root.frontFaceAngle
        }

        Rectangle {
            anchors.fill: parent
            radius: root.theme.cardRadius
            color: root.wallpaperActive
                   ? root.theme.contentClear
                   : root.theme.withAlpha(root.theme.surface, 0.34)
            border.width: root.wallpaperActive ? 1 : 0
            border.color: root.wallpaperActive
                          ? root.theme.timelineLine : "transparent"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.58
            radius: root.theme.cardRadius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.38
                    color: root.theme.isDark ? "#18000000" : "#18FFFFFF"
                }
                GradientStop {
                    position: 1
                    color: root.theme.isDark ? "#86101114" : "#8FFFFFFF"
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            Row {
                width: parent.width
                height: 70
                spacing: 14

                MobileAppIcon {

                    languageMode: root.languageMode
                    theme: root.theme
                    app: root.app
                    iconSize: 64
                    cornerRadius: 15
                }

                Column {
                    width: parent.width - 78
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        width: parent.width
                        text: root.value("displayName", "Waiting for records")
                        color: root.frontInk
                        font.family: root.theme.fontFamily
                        font.pixelSize: 21
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.tr("Cumulative time card · ")
                              + root.value("sharePct", 0) + "%"
                        color: root.frontMuted
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            Item { width: 1; height: 26 }

            Text {
                width: parent.width
                text: root.value("durationText", "0s")
                color: root.frontInk
                font.family: root.theme.numberFontFamily
                font.pixelSize: 42
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: root.value("storyText",
                                 "Grant access and sync, and your real records will appear here.")
                color: root.frontMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 14
                lineHeight: 1.45
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Item { width: 1; height: 4 }

            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: root.theme.withAlpha(root.theme.progressTrack, 0.76)

                Rectangle {
                    width: parent.width * Math.max(
                               0.03,
                               Math.min(1, root.value("relativePct", 0) / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.theme.accent
                }
            }

            Item { width: 1; height: 8 }

            Row {
                width: parent.width
                height: 44

                Text {
                    width: parent.width - 48
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tap to flip and read about this stretch of time"
                    color: root.frontMuted
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12
                }

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: root.wallpaperActive
                           ? root.theme.contentWash
                           : root.theme.surfaceRaised

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: root.frontInk
                        font.pixelSize: 20
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.flippedRequested(true)
        }
    }

    Item {
        id: back
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: root.backFaceOpacity
        scale: 1 - root.flipDepth * 0.035
        transformOrigin: Item.Center
        transform: Rotation {
            origin.x: back.width / 2
            origin.y: back.height / 2
            axis: Qt.vector3d(0, 1, 0)
            angle: root.backFaceAngle
        }

        Rectangle {
            anchors.fill: parent
            radius: root.theme.cardRadius
            color: root.theme.withAlpha(root.theme.memoryBrown, 0.94)
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            Row {
                width: parent.width
                height: 52
                spacing: 12

                MobileAppIcon {

                    languageMode: root.languageMode
                    theme: root.theme
                    app: root.app
                    iconSize: 48
                    cornerRadius: 12
                }

                Column {
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: I18n.sentence(root.languageMode, "timeWikiFor", {app: root.value("displayName", "App")})
                        color: root.theme.memoryInk
                        font.family: root.theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: "Every phrase is drawn from local records"
                        color: root.theme.memoryCopy
                        font.family: root.theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.withAlpha(root.theme.memoryInk, 0.16)
            }

            FactRow {
                width: parent.width
                label: "First record"
                value: root.value("firstDateLocal", "Waiting to sync")
            }

            FactRow {
                width: parent.width
                label: "Total recorded"
                value: root.value("durationText", "0s")
            }

            FactRow {
                width: parent.width
                label: "Days seen"
                value: I18n.sentence(root.languageMode, "dayCount", {count: root.value("recordedDays", 0)})
            }

            FactRow {
                width: parent.width
                label: "Calendar span"
                value: I18n.sentence(root.languageMode, "dayCount", {count: root.value("spanDays", 0)})
            }

            Text {
                width: parent.width
                text: root.value("conversionText",
                                 "After syncing, a clearly labelled duration comparison is generated.")
                color: root.theme.memoryCopy
                font.family: root.theme.fontFamily
                font.pixelSize: 13
                lineHeight: 1.45
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Item { width: 1; height: 4 }

            Row {
                width: parent.width
                height: root.theme.controlHeight
                spacing: 10

                Rectangle {
                    width: (parent.width - 10) * 0.38
                    height: parent.height
                    radius: root.theme.controlRadius
                    color: root.theme.withAlpha(root.theme.memoryInk, 0.10)

                    Text {
                        anchors.centerIn: parent
                        text: "Back to front"
                        color: root.theme.memoryInk
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.flippedRequested(false)
                    }
                }

                Rectangle {
                    width: (parent.width - 10) * 0.62
                    height: parent.height
                    radius: root.theme.controlRadius
                    color: root.theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Share time keepsake card"
                        color: "white"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.shareRequested(root.app)
                    }
                }
            }
        }
    }

    component FactRow: Row {
        property string label: ""
        property string value: ""

        height: 28

        Text {
            width: parent.width * 0.38
            text: label
            color: root.theme.memoryCopy
            font.family: root.theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            width: parent.width * 0.62
            text: value
            color: root.theme.memoryInk
            font.family: root.theme.numberFontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
