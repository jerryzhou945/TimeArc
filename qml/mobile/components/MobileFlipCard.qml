import QtQuick

Item {
    id: root

    required property var theme
    required property var card

    property bool flipped: false
    property color accent: card ? theme.colorFor(card.accentKey) : theme.textMuted
    property real flipAngle: flipped ? 180 : 0

    height: Math.max(140, frontContent.implicitHeight + 22,
                     backContent.implicitHeight + 42)

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    Behavior on flipAngle {
        NumberAnimation {
            duration: 560
            easing.type: Easing.InOutCubic
        }
    }

    Rectangle {
        id: front
        anchors.fill: parent
        radius: 16
        color: root.theme.card
        border.color: root.withAlpha(root.accent, 0.42)
        border.width: 1
        visible: root.flipAngle >= 90
        opacity: visible ? 1 : 0

        transform: Rotation {
            origin.x: front.width / 2
            origin.y: front.height / 2
            axis.x: 0
            axis.y: 1
            axis.z: 0
            angle: root.flipAngle - 180
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.color: root.withAlpha(root.accent, root.theme.isDark ? 0.24 : 0.18)
            border.width: 2
            opacity: 0.75
        }

        Column {
            id: frontContent
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 10
            spacing: 6

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: root.card.index
                    color: root.accent
                    opacity: 0.75
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }

                Text {
                    width: parent.width - durationText.width - 44
                    text: root.card.title
                    color: root.theme.textSecondary
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    id: durationText
                    text: root.card.duration
                    color: root.accent
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    font.letterSpacing: -0.4
                }
            }

            Text {
                width: parent.width
                text: root.card.body
                color: root.theme.textSecondary
                font.pixelSize: 12
                lineHeight: 1.5
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: "— " + root.card.summary
                color: root.theme.textPrimary
                font.pixelSize: 11
                font.italic: true
                lineHeight: 1.4
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Flow {
                width: parent.width
                spacing: 5

                Repeater {
                    model: root.card ? root.card.tags : []

                    Rectangle {
                        height: 20
                        radius: 5
                        color: root.theme.cardElevated
                        border.color: root.withAlpha(root.accent, 0.38)
                        border.width: 1
                        width: tagText.implicitWidth + 14

                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: modelData
                            color: root.accent
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: back
        anchors.fill: parent
        radius: 16
        color: root.theme.card
        border.color: root.theme.border
        border.width: 1
        visible: root.flipAngle < 90
        opacity: visible ? 1 : 0

        transform: Rotation {
            origin.x: back.width / 2
            origin.y: back.height / 2
            axis.x: 0
            axis.y: 1
            axis.z: 0
            angle: root.flipAngle
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.color: root.withAlpha(root.accent, root.theme.isDark ? 0.20 : 0.14)
            border.width: 2
            opacity: 0.7
        }

        Canvas {
            anchors.fill: parent
            opacity: root.theme.isDark ? 0.16 : 0.12
            property color strokeColor: root.accent

            onStrokeColorChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = strokeColor
                ctx.lineWidth = 0.8
                for (var x = -160; x < width + 160; x += 40) {
                    ctx.beginPath()
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x + 140, height)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(x, height)
                    ctx.lineTo(x + 140, 0)
                    ctx.stroke()
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 88
            height: 88
            rotation: 45
            radius: 4
            color: "transparent"
            border.color: root.withAlpha(root.accent, 0.28)
            border.width: 1
        }

        Column {
            id: backContent
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 8

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 26
                height: 26
                radius: 13
                color: root.theme.isDark ? "#CC15171A" : "#CCFFFFFF"
                border.color: root.withAlpha(root.accent, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.card.index
                    color: root.accent
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }

            Text {
                width: parent.width
                text: root.card.backText
                color: root.theme.textMuted
                font.pixelSize: 12
                lineHeight: 1.5
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.flipped = !root.flipped
    }
}
