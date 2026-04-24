import QtQuick

MobileSoftCard {
    id: root

    property string totalText: "4h 31m"
    property string changeText: "+12% 较昨日"
    property real progress: 0.54

    padding: 0
    clip: true
    radius: 30
    fillColor: theme ? theme.lakeCard : "#DDEADB"
    shadowOpacity: 0.08

    Canvas {
        id: lakeCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var sky = ctx.createLinearGradient(0, 0, 0, height)
            sky.addColorStop(0, root.theme ? root.theme.lakeSkyTop : "#EEF0D8")
            sky.addColorStop(0.42, root.theme ? root.theme.lakeSkyMid : "#CFE1C9")
            sky.addColorStop(1, root.theme ? root.theme.lakeSkyBottom : "#AFCFBE")
            ctx.fillStyle = sky
            ctx.fillRect(0, 0, width, height)

            ctx.fillStyle = "rgba(245, 232, 190, 0.58)"
            ctx.beginPath()
            ctx.arc(width * 0.68, height * 0.17, 32, 0, Math.PI * 2)
            ctx.fill()

            ctx.fillStyle = "rgba(111, 154, 119, 0.36)"
            ctx.beginPath()
            ctx.moveTo(0, height * 0.44)
            ctx.lineTo(width * 0.22, height * 0.22)
            ctx.lineTo(width * 0.48, height * 0.46)
            ctx.closePath()
            ctx.fill()

            ctx.fillStyle = "rgba(91, 142, 112, 0.30)"
            ctx.beginPath()
            ctx.moveTo(width * 0.35, height * 0.45)
            ctx.lineTo(width * 0.72, height * 0.25)
            ctx.lineTo(width, height * 0.48)
            ctx.closePath()
            ctx.fill()

            var water = ctx.createLinearGradient(0, height * 0.42, 0, height)
            water.addColorStop(0, "rgba(206, 230, 216, 0.90)")
            water.addColorStop(1, "rgba(128, 188, 174, 0.86)")
            ctx.fillStyle = water
            ctx.fillRect(0, height * 0.42, width, height * 0.58)

            ctx.strokeStyle = "rgba(255, 253, 247, 0.45)"
            ctx.lineWidth = 2
            for (var i = 0; i < 6; ++i) {
                ctx.beginPath()
                ctx.ellipse(width * 0.48, height * (0.60 + i * 0.045), 44 + i * 18, 9 + i * 2, 0, 0, Math.PI * 2)
                ctx.stroke()
            }

            ctx.fillStyle = "rgba(218, 154, 72, 0.88)"
            ctx.beginPath()
            ctx.ellipse(width * 0.54, height * 0.66, 24, 17, 0, 0, Math.PI * 2)
            ctx.fill()
            ctx.fillStyle = "rgba(238, 191, 92, 0.86)"
            ctx.beginPath()
            ctx.moveTo(width * 0.51, height * 0.66)
            ctx.lineTo(width * 0.47, height * 0.61)
            ctx.lineTo(width * 0.47, height * 0.71)
            ctx.closePath()
            ctx.fill()
            ctx.fillStyle = "#35554C"
            ctx.beginPath()
            ctx.arc(width * 0.60, height * 0.62, 2, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 22
        anchors.topMargin: 28
        spacing: 8

        Text {
            text: "今日湖水"
            color: root.theme ? root.theme.lakeTextSoft : "#F9F5E8"
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            text: root.totalText
            color: root.theme ? root.theme.lakeText : "#FFFDF7"
            font.pixelSize: 34
            font.bold: true
        }

        Text {
            text: root.changeText
            color: root.theme ? root.theme.lakeTextSoft : "#FFF7DD"
            font.pixelSize: 13
            font.bold: true
        }
    }

    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.topMargin: 72
        anchors.bottomMargin: 42
        width: 56

        Rectangle {
            id: gauge
            anchors.centerIn: parent
            width: 20
            height: parent.height
            radius: 10
            color: "rgba(255, 253, 247, 0.42)"
            border.width: 1
            border.color: "rgba(255, 253, 247, 0.70)"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * Math.max(0, Math.min(1, root.progress))
                radius: 10
                color: root.theme ? root.theme.lakeGauge : "#8FC8C0"
                opacity: 0.70
            }
        }

        Repeater {
            model: [8, 6, 4, 2, 0]
            Text {
                x: gauge.x + 24
                y: gauge.y + gauge.height * (1 - modelData / 8) - 7
                text: modelData + "h"
                color: root.theme ? root.theme.lakeText : "#FDF7E8"
                font.pixelSize: 11
                font.bold: true
            }
        }
    }
}
