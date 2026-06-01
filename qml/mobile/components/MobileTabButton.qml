import QtQuick

Item {
    id: root

    required property var theme
    property string label: ""
    property string iconName: "home"
    property bool active: false

    signal clicked()

    width: 72
    height: 52

    Column {
        width: parent.width
        height: 42
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 6
        spacing: 3

        Item {
            width: parent.width
            height: 24

            Canvas {
                id: iconCanvas
                anchors.centerIn: parent
                width: 22
                height: 22

                property color strokeColor: root.active ? root.theme.tabActive : root.theme.tabInactive

                onStrokeColorChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = strokeColor
                    ctx.lineWidth = 1.7
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.fillStyle = "transparent"

                    if (root.iconName === "home") {
                        ctx.beginPath()
                        ctx.moveTo(4, 10)
                        ctx.lineTo(11, 4)
                        ctx.lineTo(18, 10)
                        ctx.lineTo(18, 19)
                        ctx.lineTo(14, 19)
                        ctx.lineTo(14, 13)
                        ctx.lineTo(8, 13)
                        ctx.lineTo(8, 19)
                        ctx.lineTo(4, 19)
                        ctx.closePath()
                        ctx.stroke()
                    } else if (root.iconName === "stats") {
                        drawRoundRect(ctx, 4, 13, 4, 7, 1)
                        drawRoundRect(ctx, 9, 8, 4, 12, 1)
                        drawRoundRect(ctx, 14, 4, 4, 16, 1)
                    } else if (root.iconName === "history") {
                        ctx.beginPath()
                        ctx.arc(11, 11, 8, 0, Math.PI * 2)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(11, 7)
                        ctx.lineTo(11, 11)
                        ctx.lineTo(14, 14)
                        ctx.stroke()
                    } else {
                        ctx.beginPath()
                        ctx.arc(11, 11, 3, 0, Math.PI * 2)
                        ctx.stroke()
                        for (var i = 0; i < 8; ++i) {
                            var a = i * Math.PI / 4
                            ctx.beginPath()
                            ctx.moveTo(11 + Math.cos(a) * 6, 11 + Math.sin(a) * 6)
                            ctx.lineTo(11 + Math.cos(a) * 8, 11 + Math.sin(a) * 8)
                            ctx.stroke()
                        }
                    }
                }

                function drawRoundRect(ctx, x, y, w, h, r) {
                    ctx.beginPath()
                    ctx.moveTo(x + r, y)
                    ctx.lineTo(x + w - r, y)
                    ctx.quadraticCurveTo(x + w, y, x + w, y + r)
                    ctx.lineTo(x + w, y + h - r)
                    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
                    ctx.lineTo(x + r, y + h)
                    ctx.quadraticCurveTo(x, y + h, x, y + h - r)
                    ctx.lineTo(x, y + r)
                    ctx.quadraticCurveTo(x, y, x + r, y)
                    ctx.stroke()
                }
            }
        }

        Text {
            width: parent.width
            height: 14
            text: root.label
            horizontalAlignment: Text.AlignHCenter
            color: root.active ? root.theme.tabActive : root.theme.tabInactive
            font.pixelSize: 10
            font.weight: root.active ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
