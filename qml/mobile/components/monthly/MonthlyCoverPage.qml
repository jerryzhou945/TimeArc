import QtQuick

Item {
    property var theme
    property var report: ({})
    property var profile: ({})

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 26
        anchors.rightMargin: 26
        anchors.bottomMargin: 86
        spacing: 12

        Text {
            text: profile.eyebrow || report.monthLabel || "MONTHLY STORY"
            color: profile.accent || "#FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 12
            font.letterSpacing: 1.4
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: profile.title || report.title || "这个月的时间"
            color: "white"
            font.family: theme.fontFamily
            font.pixelSize: 44
            font.weight: Font.Black
            lineHeight: 0.98
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: 42
            height: 3
            radius: 2
            color: profile.accent || "#FFFFFF"
        }

        Text {
            width: parent.width
            text: report.summary || profile.opening
                  || "真实记录会在这里形成属于这个月的时间故事。"
            color: "#E8FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            lineHeight: 1.55
            wrapMode: Text.WordWrap
        }

        Text {
            text: report.rangeText || ""
            color: "#BFFFFFFF"
            font.family: theme.numberFontFamily
            font.pixelSize: 11
        }
    }
}
