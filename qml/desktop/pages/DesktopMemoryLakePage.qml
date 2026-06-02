import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    anchors.fill: parent

    property bool nightMode: false
    property color themeTextPrimary: "#4E342E"
    property color themeTextSecondary: "#9C806C"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#D8C2AC"
    property color themeAccentColor: "#E8C6A3"

    // 今日卡片（由 C++ DailyCardService 生成的 QVariantMap 列表）。
    property var cards: []

    function reloadCards() {
        if (typeof dailyCardService !== "undefined" && dailyCardService)
            root.cards = dailyCardService.getTodayCards();
        else
            root.cards = [];
    }

    Component.onCompleted: reloadCards()
    onVisibleChanged: if (visible) reloadCards()

    // 湖面渐变背景，保留氛围
    Rectangle {
        anchors.fill: parent
        radius: 30
        color: "transparent"
        border.width: 1
        border.color: nightMode ? "#6D7668" : "#D9CEB9"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 29
            opacity: nightMode ? 0.74 : 0.90
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: nightMode ? "#23302C" : "#FFF2C9" }
                GradientStop { position: 0.46; color: nightMode ? "#273A31" : "#DCD6B5" }
                GradientStop { position: 1.0; color: nightMode ? "#1A2A26" : "#A8D5BA" }
            }
            z: -1
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 29
        color: "transparent"
        opacity: nightMode ? 0.16 : 0.24
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#7ACB73" }
            GradientStop { position: 0.55; color: "#D4CFA9" }
            GradientStop { position: 1.0; color: "#FFC7D8" }
        }
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 42
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 96, 720)
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "记忆湖"
            color: nightMode ? "#F6F2DD" : themeTextPrimary
            font.pixelSize: 38
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "今天的时间,慢慢沉淀成可以回看的卡片。"
            color: nightMode ? "#C9D5C9" : themeTextSecondary
            font.pixelSize: 15
        }
    }

    Flickable {
        id: cardScroll
        anchors.top: header.bottom
        anchors.topMargin: 26
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 96, 720)
        contentHeight: cardColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: root.cards.length > 0

        Column {
            id: cardColumn
            width: parent.width
            spacing: 18

            Repeater {
                model: root.cards
                delegate: DesktopDailyCardView {
                    width: cardColumn.width
                    cardData: modelData
                    nightMode: root.nightMode
                    themeTextPrimary: root.themeTextPrimary
                    themeTextSecondary: root.themeTextSecondary
                    themePanelColor: root.themePanelColor
                    themeBorderColor: root.themeBorderColor
                    themeAccentColor: root.themeAccentColor
                }
            }
        }
    }

    // 空态
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 460)
        spacing: 10
        visible: root.cards.length === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "今天还没有足够的记录"
            color: nightMode ? "#F6F2DD" : themeTextPrimary
            font.pixelSize: 20
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "让 TimeArc 在后台多陪你一会儿,稍后这里会浮现今天的时间卡片。"
            color: nightMode ? "#C9D5C9" : themeTextSecondary
            font.pixelSize: 14
        }
    }
}
