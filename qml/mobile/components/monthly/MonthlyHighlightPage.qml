import QtQuick

Item {
    property var theme
    property var report: ({})
    property var profile: ({})
    readonly property var insights: report.insights || []
    readonly property var highlight: insights.length > 0 ? insights[0] : ({})
    readonly property var longest: report.longestSession || ({})

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 25
        anchors.rightMargin: 25
        anchors.topMargin: 142
        spacing: 15

        Text {
            text: "最值得记住的一刻"
            color: profile.accent || "#FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Text {
            width: parent.width
            text: highlight.headline || longest.durationText || "时间仍在积累"
            color: "white"
            font.family: theme.numberFontFamily
            font.pixelSize: 38
            font.weight: Font.Black
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: highlight.body || profile.opening
                  || "当记录足够完整，这里会出现这个月最特别的一段时间。"
            color: "#E5FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 16
            lineHeight: 1.58
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#45FFFFFF"
        }

        Text {
            width: parent.width
            text: longest.startLocal
                  ? "发生于 " + longest.startLocal
                  : "只依据本地聚合记录生成"
            color: "#BFFFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 11
        }
    }
}
