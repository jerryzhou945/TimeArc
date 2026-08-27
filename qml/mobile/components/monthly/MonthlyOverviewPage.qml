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
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 25
        anchors.rightMargin: 25
        spacing: 18

        Text {
            text: "This month, time gained a scale"
            color: "#E8FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            text: report.totalText || "0 minutes"
            color: "white"
            font.family: theme.numberFontFamily
            font.pixelSize: 48
            font.weight: Font.Black
        }

        Text {
            width: parent.width
            text: I18n.sentence(root.languageMode, "overviewActiveStreak",
                                {days: report.activeDays || 0,
                                 streak: report.longestStreakDays || 0})
            color: "#E5FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 17
            lineHeight: 1.5
            wrapMode: Text.WordWrap
        }

        Row {
            width: parent.width
            height: 92
            spacing: 10

            Repeater {
                model: [
                    { label: "Active days", value: I18n.sentence(root.languageMode, "dayCount", {count: report.activeDays || 0}) },
                    { label: "vs last month", value: report.deltaPct === undefined
                              ? "—" : ((report.deltaPct >= 0 ? "+" : "")
                                      + report.deltaPct + "%") }
                ]

                Rectangle {
                    required property var modelData
                    width: (parent.width - 10) / 2
                    height: parent.height
                    radius: 18
                    color: "#2EFFFFFF"
                    border.width: 1
                    border.color: "#38FFFFFF"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 6
                        Text {
                            text: modelData.label
                            color: "#BFFFFFFF"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData.value
                            color: "white"
                            font.family: theme.numberFontFamily
                            font.pixelSize: 23
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }
}
