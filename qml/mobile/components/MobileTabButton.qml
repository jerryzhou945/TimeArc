import QtQuick

Item {
    id: root

    required property var theme
    property string label: ""
    property string iconName: "home"
    property bool active: false
    property bool wallpaperActive: false
    property bool badgeVisible: false

    signal clicked()

    width: 80
    height: 58

    function iconFile() {
        if (iconName === "history")
            return "recap"
        return iconName
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 3

        Item {
            width: parent.width
            height: 30

            Rectangle {
                anchors.centerIn: parent
                width: root.active ? 42 : 30
                height: 28
                radius: 14
                color: root.active
                       ? root.theme.withAlpha(root.theme.accentSoft,
                                              root.wallpaperActive ? 0.84 : 1)
                       : "transparent"

                Behavior on width {
                    NumberAnimation {
                        duration: root.theme.fastDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: Qt.resolvedUrl("../../../resources/icons/"
                                       + root.iconFile()
                                       + (root.theme.isDark ? "_white.svg" : ".svg"))
                fillMode: Image.PreserveAspectFit
                opacity: root.active ? 1 : 0.68
            }

            Rectangle {
                id: notificationBadge
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: 12
                anchors.top: parent.top
                anchors.topMargin: 1
                width: 9
                height: 9
                radius: 4.5
                visible: root.badgeVisible
                color: root.theme.notificationRed
                border.width: 1
                border.color: root.theme.isDark ? "#1A1D22" : "#FFFFFF"
            }
        }

        Text {
            width: parent.width
            text: root.label
            color: root.active ? root.theme.tabActive : root.theme.tabInactive
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: root.active ? Font.DemiBold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
