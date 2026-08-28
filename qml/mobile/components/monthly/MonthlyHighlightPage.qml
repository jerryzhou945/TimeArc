import QtQuick
import "../../../shared/I18n.js" as I18n

Item {
    property var theme
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
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
            text: "The moment most worth remembering"
            color: profile.accent || "#FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Text {
            width: parent.width
            text: highlight.headline || longest.durationText || "Time is still gathering"
            color: "white"
            font.family: theme.numberFontFamily
            font.pixelSize: 38
            font.weight: Font.Black
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: highlight.body ? tr(highlight.body) : tr(profile.opening)
                  || "Once there are enough records, this month's most distinctive stretch appears here."
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
                  ? I18n.sentence(root.languageMode, "occurredAt", {time: longest.startLocal})
                  : "Built only from locally aggregated records"
            color: "#BFFFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 11
        }
    }
}
