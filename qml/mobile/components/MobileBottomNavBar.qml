import QtQuick

Item {
    id: root

    property var theme
    property string currentPage: "home"

    signal navigate(string page)
    signal plusClicked()

    height: (theme ? theme.navHeight : 72) + (theme ? theme.bottomSafe : 12)

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 10
        radius: 28
        color: theme ? theme.panelGlass : "#FFFDF9"
        border.width: 1
        border.color: theme ? theme.softStroke : "#EEE6D8"
        opacity: 0.94
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 18
        radius: 28
        color: theme ? theme.shadow : "#A89372"
        opacity: 0.08
        z: -1
    }

    Row {
        id: navRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 17
        anchors.bottomMargin: theme ? theme.bottomSafe : 12

        Repeater {
            model: [
                { page: "home", label: "首页", icon: "⌂" },
                { page: "chat", label: "聊天", icon: "…" },
                { page: "", label: "", icon: "" },
                { page: "memory", label: "记忆湖", icon: "◌" },
                { page: "calendar", label: "日历", icon: "□" },
                { page: "profile", label: "我的", icon: "♙" }
            ]

            Item {
                width: navRow.width / 6
                height: navRow.height

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    visible: modelData.page.length > 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        color: root.currentPage === modelData.page ? (root.theme ? root.theme.accentGreenDeep : "#4D8D73") : (root.theme ? root.theme.textSecondary : "#6E8076")
                        font.pixelSize: 17
                        font.bold: root.currentPage === modelData.page
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: root.currentPage === modelData.page ? (root.theme ? root.theme.accentGreenDeep : "#4D8D73") : (root.theme ? root.theme.textSecondary : "#6E8076")
                        font.pixelSize: 10
                        font.bold: root.currentPage === modelData.page
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: modelData.page.length > 0
                    onClicked: root.navigate(modelData.page)
                }
            }
        }
    }

    MobileGradientButton {
        theme: root.theme
        width: 58
        height: 58
        radius: 29
        text: "+"
        fontSize: 26
        fromColor: theme ? theme.navPlusStart : "#9BC8A9"
        toColor: theme ? theme.navPlusEnd : "#C9D99B"
        x: (parent.width - width) / 2
        y: 2
        onClicked: root.plusClicked()
    }
}
