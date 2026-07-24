import QtQuick
import ".."

Item {
    id: root
    property var theme
    property var report: ({})
    property var profile: ({})
    readonly property var apps: report.topApps || []

    Column {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 120
        anchors.bottomMargin: 76
        spacing: 16

        Text {
            text: "这个月，时间去了这里"
            color: "white"
            font.family: theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.Black
        }

        Text {
            width: parent.width
            text: apps.length > 0
                  ? "不是输赢，只是你真实生活的一份去向。"
                  : "同步后，应用与时间会在这里形成排行。"
            color: "#CFFFFFFF"
            font.family: theme.fontFamily
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: apps.slice(0, 4)

            Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 66

                Row {
                    anchors.fill: parent
                    spacing: 11

                    Text {
                        width: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(index + 1).padStart(2, "0")
                        color: index === 0
                               ? (profile.accent || "#FFFFFF") : "#AFFFFFFF"
                        font.family: theme.numberFontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    MobileAppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                        app: modelData
                        iconSize: 44
                        cornerRadius: 12
                    }

                    Column {
                        width: parent.width - 22 - 44 - 33
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Row {
                            width: parent.width
                            Text {
                                width: parent.width - 82
                                text: modelData.displayName || "未知应用"
                                color: "white"
                                font.family: theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: 82
                                text: modelData.durationText || "0 分钟"
                                color: "#E2FFFFFF"
                                font.family: theme.numberFontFamily
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 4
                            radius: 2
                            color: "#35FFFFFF"
                            Rectangle {
                                width: parent.width
                                       * Math.max(0, Math.min(100,
                                           modelData.relativePct || 0)) / 100
                                height: parent.height
                                radius: 2
                                color: profile.accent || "#FFFFFF"
                            }
                        }
                    }
                }
            }
        }
    }
}
