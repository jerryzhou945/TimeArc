import QtQuick

Item {
    id: root

    required property var theme
    property bool compact: false
    signal channelRequested(string channel)

    implicitHeight: compact ? 62 : 72

    readonly property var actions: [
        { channel: "gallery", label: "保存到图库", icon: "download",
          color: theme.accent },
        { channel: "moments", label: "朋友圈", icon: "group",
          color: "#20B45A" },
        { channel: "qzone", label: "QQ动态", icon: "star",
          color: "#2B7DE9" },
        { channel: "system", label: "更多", icon: "more",
          color: theme.textMuted }
    ]

    Row {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: root.actions

            Item {
                required property var modelData
                width: (parent.width - 18) / 4
                height: parent.height

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: root.compact ? 36 : 40
                        height: width
                        radius: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: modelData.color
                        opacity: actionMouse.pressed ? 0.68 : 0.92

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.theme.fastDuration
                            }
                        }

                        MobileSymbolIcon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            color: "white"
                            iconSize: root.compact ? 19 : 21
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.compact ? 9 : 10
                    }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    onClicked: root.channelRequested(modelData.channel)
                }
            }
        }
    }
}
