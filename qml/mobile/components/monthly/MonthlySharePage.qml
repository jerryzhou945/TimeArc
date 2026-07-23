import QtQuick
import ".."

Item {
    property var theme
    property var report: ({})
    property var profile: ({})
    signal shareRequested()

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 25
        anchors.rightMargin: 25
        spacing: 18

        Text {
            text: report.monthLabel || "本月时间报告"
            color: profile.accent || "#FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 12
            font.letterSpacing: 1.2
            font.weight: Font.Bold
        }

        Text {
            width: parent.width
            text: "把这个月\n收进一张卡片"
            color: "white"
            font.family: theme.fontFamily
            font.pixelSize: 38
            font.weight: Font.Black
            lineHeight: 1.05
        }

        Rectangle {
            width: parent.width
            height: 176
            radius: 22
            color: "#34FFFFFF"
            border.width: 1
            border.color: "#3FFFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 9

                Text {
                    text: report.totalText || "0 分钟"
                    color: "white"
                    font.family: theme.numberFontFamily
                    font.pixelSize: 30
                    font.weight: Font.Black
                }
                Text {
                    width: parent.width
                    text: report.summary || profile.opening
                    color: "#DEFFFFFF"
                    font.family: theme.fontFamily
                    font.pixelSize: 13
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Text {
                    text: "TimeArc · 只分享聚合后的时间"
                    color: "#AFFFFFFF"
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 50
            radius: 16
            color: profile.accent || "#FFFFFF"

            Text {
                anchors.centerIn: parent
                text: "保存并分享"
                color: profile.accentInk || "#172026"
                font.family: theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                onClicked: parent.parent.parent.shareRequested()
            }
        }
    }
}
