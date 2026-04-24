import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell
    property int listMode: 0

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 28
        clip: true

        Column {
            id: contentColumn
            width: parent.width - (theme ? theme.pageMargin * 2 : 36)
            x: theme ? theme.pageMargin : 18
            y: theme ? theme.topSafe + 8 : 22
            spacing: 16

            Item {
                width: parent.width
                height: 42

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: theme ? theme.accentGreenSoft : "#CFE3D2"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "T"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 48
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "TimeArc Today"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: "让时间产生价值"
                        color: theme ? theme.textMuted : "#93A297"
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: theme ? theme.panelGlass : "#FFFDF9"
                    border.width: 1
                    border.color: theme ? theme.softStroke : "#EEE6D8"

                    Text {
                        anchors.centerIn: parent
                        text: "♧"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 15
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 126
                radius: theme ? theme.radiusLarge : 30
                clip: true
                border.width: 1
                border.color: theme ? theme.cardStroke : "#E6DDCE"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: theme ? theme.headerStart : "#DDEADA" }
                    GradientStop { position: 1.0; color: theme ? theme.headerEnd : "#F4EACB" }
                }

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 18
                    anchors.topMargin: 20
                    spacing: 9

                    Text {
                        text: "你好，专注者 👋"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 21
                        font.bold: true
                    }

                    Text {
                        text: "今天是高效的一天"
                        color: theme ? theme.textSecondary : "#6E8076"
                        font.pixelSize: 13
                    }

                    Text {
                        text: shell ? shell.secondsToDisplay(shell.todayTotalSeconds()) : "4h 31m"
                        color: theme ? theme.accentGreenDeep : "#4D8D73"
                        font.pixelSize: 29
                        font.bold: true
                    }
                }

                Item {
                    id: ringWrap
                    width: 86
                    height: 86
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter

                    property real ratio: shell ? Math.min(1, shell.todayTotalSeconds() / (8 * 3600)) : 0.54

                    Canvas {
                        id: ringCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2
                            var cy = height / 2
                            var radius = Math.min(width, height) / 2 - 9
                            ctx.lineWidth = 13
                            ctx.lineCap = "round"
                            ctx.strokeStyle = "rgba(245, 239, 218, 0.72)"
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, -Math.PI * 0.5, Math.PI * 1.5)
                            ctx.stroke()
                            ctx.strokeStyle = root.theme ? root.theme.accentGreen : "#8FBEA3"
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, -Math.PI * 0.5, -Math.PI * 0.5 + Math.PI * 2 * ringWrap.ratio)
                            ctx.stroke()
                        }
                    }

                    onRatioChanged: ringCanvas.requestPaint()

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "目标 8h"
                            color: theme ? theme.textMuted : "#93A297"
                            font.pixelSize: 10
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(ringWrap.ratio * 100) + "%"
                            color: theme ? theme.accentGreenDeep : "#4D8D73"
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 2
                rowSpacing: 12
                columnSpacing: 12

                MobileStatCard {
                    theme: root.theme
                    width: (parent.width - 12) / 2
                    height: 74
                    title: "自动记录"
                    value: shell ? shell.secondsToDisplay(shell.todaySoftwareSeconds()) : "4h 31m"
                    iconText: "A"
                    accentColor: theme ? theme.accentGreenSoft : "#CFE3D2"
                }

                MobileStatCard {
                    theme: root.theme
                    width: (parent.width - 12) / 2
                    height: 74
                    title: "手动记录"
                    value: shell ? shell.secondsToDisplay(shell.todayManualSeconds()) : "0m"
                    iconText: "M"
                    accentColor: theme ? theme.accentCream : "#F1E5BD"
                }

                MobileStatCard {
                    theme: root.theme
                    width: (parent.width - 12) / 2
                    height: 74
                    title: "专注中"
                    value: timerManager && timerManager.running ? "1 个" : "0 个"
                    iconText: "▶"
                    accentColor: theme ? theme.accentLavender : "#CFC6DD"
                }

                MobileStatCard {
                    theme: root.theme
                    width: (parent.width - 12) / 2
                    height: 74
                    title: "中断次数"
                    value: "15 次"
                    iconText: "Ⅱ"
                    accentColor: theme ? theme.accentBlue : "#A9CCD5"
                }
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 318
                padding: 16

                Column {
                    anchors.fill: parent
                    spacing: 14

                    Item {
                        width: parent.width
                        height: 38

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "今日记录"
                            color: theme ? theme.textPrimary : "#123A35"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        MobileSegmentedControl {
                            theme: root.theme
                            width: 142
                            height: 36
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["时间轴", "软件"]
                            currentIndex: root.listMode
                            onChanged: function(index) { root.listMode = index }
                        }
                    }

                    Repeater {
                        model: shell ? (shell.refreshTick, root.listMode === 0 ? shell.todayTimelineItems() : shell.todaySoftwareItems(4)) : []

                        MobileTimelineItem {
                            theme: root.theme
                            width: parent.width
                            title: modelData.title
                            timeRange: modelData.timeRange
                            duration: modelData.duration
                            iconSource: modelData.iconSource
                            iconText: modelData.title ? modelData.title.charAt(0) : "A"
                            iconColor: modelData.iconColor
                            progress: shell ? (modelData.seconds / shell.maxSeconds(root.listMode === 0 ? shell.todayTimelineItems() : shell.todaySoftwareItems(4))) : 0.3
                        }
                    }
                }
            }
        }
    }
}
