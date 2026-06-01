import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    color: theme.bg

    property int selectedSegment: 0
    property var segments: ["今天", "7天", "30天"]
    property var bars: [
        { "label": "开发", "value": "4h20m", "pct": 82, "colorKey": "accent" },
        { "label": "娱乐", "value": "2h15m", "pct": 43, "colorKey": "amber" },
        { "label": "音乐/视频", "value": "3h12m", "pct": 61, "colorKey": "green" },
        { "label": "社交", "value": "1h05m", "pct": 20, "colorKey": "textMuted" }
    ]
    property var topApps: [
        { "name": "VSCode", "time": "3h10m", "colorKey": "accent", "initial": "V" },
        { "name": "Steam", "time": "1h35m", "colorKey": "amber", "initial": "S" },
        { "name": "WeChat", "time": "1h12m", "colorKey": "green", "initial": "W" },
        { "name": "Chrome", "time": "58m", "colorKey": "textMuted", "initial": "C" },
        { "name": "Spotify", "time": "46m", "colorKey": "red", "initial": "Sp" }
    ]

    Column {
        anchors.fill: parent

        MobileStatusBar {
            width: parent.width
            theme: root.theme
        }

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - y
            clip: true
            contentHeight: content.implicitHeight + 20

            Column {
                id: content
                width: flick.width - 40
                x: 20
                spacing: 16

                MobileSectionTitle {
                    width: parent.width
                    theme: root.theme
                    title: "统计"
                    subtitle: "只看最重要的变化"
                }

                Rectangle {
                    width: parent.width
                    height: summaryColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Column {
                        id: summaryColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        Text {
                            text: "今日记录"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Text {
                            text: "7h42m"
                            color: root.theme.textPrimary
                            font.pixelSize: 36
                            font.weight: Font.Bold
                            font.letterSpacing: -1
                        }

                        Text {
                            text: "↗ 比昨天 +38m"
                            color: root.theme.green
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 12
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 2

                        Repeater {
                            model: root.segments

                            Rectangle {
                                width: parent.width / root.segments.length
                                height: parent.height
                                radius: 10
                                color: index === root.selectedSegment ? root.theme.cardElevated : "transparent"
                                border.color: index === root.selectedSegment ? root.theme.border : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: index === root.selectedSegment ? root.theme.textPrimary : root.theme.textMuted
                                    font.pixelSize: 13
                                    font.weight: index === root.selectedSegment ? Font.Medium : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedSegment = index
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: categoryColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Column {
                        id: categoryColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 13

                        Text {
                            text: "时间分类"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Repeater {
                            model: root.bars

                            Column {
                                width: parent.width
                                spacing: 6

                                Row {
                                    width: parent.width
                                    Text {
                                        width: parent.width - valueText.width
                                        text: modelData.label
                                        color: root.theme.textSecondary
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: valueText
                                        text: modelData.value
                                        color: root.theme.textPrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: root.theme.border

                                    Rectangle {
                                        width: parent.width * modelData.pct / 100
                                        height: parent.height
                                        radius: 3
                                        color: root.theme.colorFor(modelData.colorKey)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: topAppsColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Column {
                        id: topAppsColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 0

                        Text {
                            width: parent.width
                            text: "常用应用"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Repeater {
                            model: root.topApps

                            Item {
                                width: parent.width
                                height: 42

                                Row {
                                    anchors.fill: parent
                                    spacing: 12

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28
                                        height: 28
                                        radius: 8
                                        color: root.theme.cardElevated
                                        border.color: root.theme.border
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.initial
                                            color: root.theme.colorFor(modelData.colorKey)
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 112
                                        text: modelData.name
                                        color: root.theme.textSecondary
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 54
                                        text: modelData.time
                                        color: root.theme.textPrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: root.theme.border
                                    opacity: index < root.topApps.length - 1 ? 0.5 : 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
