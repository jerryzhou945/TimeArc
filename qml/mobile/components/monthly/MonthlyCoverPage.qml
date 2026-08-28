import QtQuick
import "../../../shared/I18n.js" as I18n

Item {
    property var theme
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
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
            text: profile.eyebrow ? tr(profile.eyebrow)
                  : (I18n.reportMonthLabel(languageMode, report) || tr("MONTHLY STORY"))
            color: profile.accent || "#FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 12
            font.letterSpacing: 1.4
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: profile.title ? tr(profile.title)
                  : (I18n.reportTitle(languageMode, report) || tr("This month's time"))
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
            text: report.summary ? tr(report.summary) : tr(profile.opening)
                  || "Real records will form this month's time story here."
            color: "#E8FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            lineHeight: 1.55
            wrapMode: Text.WordWrap
        }

        Text {
            text: I18n.reportRange(languageMode, report)
            color: "#BFFFFFFF"
            font.family: theme.numberFontFamily
            font.pixelSize: 11
        }
    }
}
