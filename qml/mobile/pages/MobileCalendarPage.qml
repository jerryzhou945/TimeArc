import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell
    property int selectedDay: 21
    property var weekdays: ["日", "一", "二", "三", "四", "五", "六"]

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 30
        clip: true

        Column {
            id: contentColumn
            width: parent.width - (theme ? theme.pageMargin * 2 : 36)
            x: theme ? theme.pageMargin : 18
            y: theme ? theme.topSafe + 10 : 24
            spacing: 16

            Item {
                width: parent.width
                height: 42

                Text {
                    text: "日历"
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 24
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: theme ? theme.panelGlass : "#FFFDF9"
                        border.width: 1
                        border.color: theme ? theme.softStroke : "#EEE6D8"
                        Text { anchors.centerIn: parent; text: "+"; color: theme ? theme.textPrimary : "#123A35"; font.pixelSize: 18 }
                    }
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: theme ? theme.panelGlass : "#FFFDF9"
                        border.width: 1
                        border.color: theme ? theme.softStroke : "#EEE6D8"
                        Text { anchors.centerIn: parent; text: "›"; color: theme ? theme.textPrimary : "#123A35"; font.pixelSize: 22 }
                    }
                }
            }

            Item {
                width: parent.width
                height: 34

                Text {
                    text: "2024年5月"
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌄"
                    color: theme ? theme.textSecondary : "#6E8076"
                    font.pixelSize: 18
                }
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 270
                padding: 14
                shadowOpacity: 0.06

                Column {
                    anchors.fill: parent
                    spacing: 10

                    Row {
                        width: parent.width
                        height: 22

                        Repeater {
                            model: root.weekdays
                            Text {
                                width: parent.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: theme ? theme.textMuted : "#93A297"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 7
                        rowSpacing: 8
                        columnSpacing: 0

                        Repeater {
                            model: 35

                            Item {
                                width: parent.width / 7
                                height: 32

                                property int day: index < 3 ? 0 : index - 2

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    radius: 12
                                    color: day === root.selectedDay ? (theme ? theme.accentGreen : "#8FBEA3") : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: day > 0 && day <= 31 ? day : ""
                                    color: day === root.selectedDay ? "#FFFFFF" : (theme ? theme.textPrimary : "#123A35")
                                    font.pixelSize: 13
                                    font.bold: day === root.selectedDay
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: day > 0 && day <= 31
                                    onClicked: root.selectedDay = day
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 34

                Text {
                    text: "5月" + root.selectedDay + "日 · 今天"
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell ? shell.secondsToDisplay(shell.todayTotalSeconds()) : "4h 31m"
                    color: theme ? theme.accentGreenDeep : "#4D8D73"
                    font.pixelSize: 18
                    font.bold: true
                }
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 242
                padding: 14

                Column {
                    anchors.fill: parent
                    spacing: 2

                    Repeater {
                        model: shell ? (shell.refreshTick, shell.todayTimelineItems()) : []

                        MobileTimelineItem {
                            theme: root.theme
                            width: parent.width
                            title: modelData.title
                            timeRange: modelData.timeRange
                            duration: modelData.duration
                            iconSource: modelData.iconSource
                            iconText: modelData.title ? modelData.title.charAt(0) : "A"
                            iconColor: modelData.iconColor
                            progress: 0
                        }
                    }
                }
            }
        }
    }
}
