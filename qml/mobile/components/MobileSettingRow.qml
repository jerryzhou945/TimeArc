import QtQuick

Item {
    id: root

    required property var theme
    property string label: ""
    property string value: ""
    property bool hasSwitch: false
    property bool checked: true
    property bool hasArrow: false

    signal switchToggled(bool checked)
    signal clicked()

    height: Math.max(48, Math.max(labelText.implicitHeight, rightRow.implicitHeight) + 24)

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(96, parent.width - rightRow.width - 16)
        text: root.label
        color: root.theme.textSecondary
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(130, implicitWidth)
            text: root.value
            color: root.theme.textMuted
            font.pixelSize: 13
            visible: text.length > 0
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }

        MobileSwitch {
            theme: root.theme
            checked: root.checked
            visible: root.hasSwitch
            onToggled: function(v) {
                root.checked = v
                root.switchToggled(v)
            }
        }

        Canvas {
            width: 16
            height: 16
            visible: root.hasArrow
            property color strokeColor: root.theme.textMuted

            onStrokeColorChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = strokeColor
                ctx.lineWidth = 1.7
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(6, 4)
                ctx.lineTo(10, 8)
                ctx.lineTo(6, 12)
                ctx.stroke()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.hasArrow && !root.hasSwitch
        onClicked: root.clicked()
    }
}
