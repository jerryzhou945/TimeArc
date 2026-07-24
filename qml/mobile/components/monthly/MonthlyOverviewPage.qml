import QtQuick

Item {
    property var theme
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
            text: "这个月，时间有了刻度"
            color: "#E8FFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            text: report.totalText || "0 分钟"
            color: "white"
            font.family: theme.numberFontFamily
            font.pixelSize: 48
            font.weight: Font.Black
        }

        Text {
            width: parent.width
            text: (report.activeDays || 0) + " 个被记录的日子，"
                  + (report.longestStreakDays || 0)
                  + " 天连续留下时间。"
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
                    { label: "活跃日", value: (report.activeDays || 0) + " 天" },
                    { label: "较上月", value: report.deltaPct === undefined
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
