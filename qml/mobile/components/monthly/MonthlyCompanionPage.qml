import QtQuick
import ".."

Item {
    id: root
    property var theme
    property var report: ({})
    property var profile: ({})
    readonly property var companion: report.companion || ({})
    readonly property var firstApp: companion.firstApp || ({})
    readonly property var secondApp: companion.secondApp || ({})

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 25
        anchors.rightMargin: 25
        anchors.bottomMargin: 104
        spacing: 18

        Text {
            text: "总有一些应用，并肩出现"
            color: "#E8FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            height: 78
            spacing: 13

            MobileAppIcon {
                theme: root.theme
                app: firstApp
                iconSize: 72
                cornerRadius: 18
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "×"
                color: profile.accent || "#FFFFFF"
                font.pixelSize: 24
                font.weight: Font.Light
            }

            MobileAppIcon {
                theme: root.theme
                app: secondApp
                iconSize: 72
                cornerRadius: 18
            }
        }

        Text {
            width: parent.width
            text: companion.daysTogether
                  ? "共同出现 " + companion.daysTogether + " 天"
                  : "等待更多共同出现的日子"
            color: "white"
            font.family: theme.numberFontFamily
            font.pixelSize: 32
            font.weight: Font.Black
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: companion.body || "当两个应用在同一天反复相遇，"
                  + "它们也许正共同完成一件对你重要的事。"
            color: "#DFFFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            lineHeight: 1.55
            wrapMode: Text.WordWrap
        }
    }
}
