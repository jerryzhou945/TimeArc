import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell
    property int rangeIndex: 1
    property var bars: [0.55, 0.62, 0.58, 0.83, 0.64, 0.76, 0.52]
    property var labels: ["13", "14", "15", "16", "17", "18", "19"]
    property var distribution: [
        { label: "学习", value: "16h 30m", ratio: "57%", colorKey: "study" },
        { label: "工作", value: "6h 45m", ratio: "23%", colorKey: "work" },
        { label: "娱乐", value: "3h 30m", ratio: "12%", colorKey: "fun" },
        { label: "其他", value: "2h 0m", ratio: "8%", colorKey: "other" }
    ]

    function chartColor(key) {
        if (!theme) return "#77B5BF"
        if (key === "study") return theme.chartStudy
        if (key === "work") return theme.chartWork
        if (key === "fun") return theme.chartFun
        return theme.chartOther
    }

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

            Row {
                width: parent.width
                height: 42

                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: theme ? theme.panelGlass : "#FFFDF9"
                    border.width: 1
                    border.color: theme ? theme.softStroke : "#EEE6D8"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "‹"; color: theme ? theme.textPrimary : "#123A35"; font.pixelSize: 23 }
                    MouseArea { anchors.fill: parent; onClicked: shell ? shell.goBack("profile") : undefined }
                }

                Text {
                    text: "统计"
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 24
                    font.bold: true
                    anchors.centerIn: parent
                }
            }

            MobileSegmentedControl {
                theme: root.theme
                width: parent.width
                height: 42
                options: ["日", "周", "月", "年"]
                currentIndex: root.rangeIndex
                onChanged: function(index) { root.rangeIndex = index }
            }

            Row {
                width: parent.width
                height: 64

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: "总计时长"
                        color: theme ? theme.textSecondary : "#6E8076"
                        font.pixelSize: 12
                    }

                    Text {
                        text: "28h 45m"
                        color: theme ? theme.accentGreenDeep : "#4D8D73"
                        font.pixelSize: 27
                        font.bold: true
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: "日均时长"
                        color: theme ? theme.textSecondary : "#6E8076"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                    }

                    Text {
                        text: "4h 6m"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 198
                padding: 18

                Row {
                    anchors.fill: parent
                    spacing: 11

                    Repeater {
                        model: root.bars

                        Column {
                            width: (parent.width - 66) / 7
                            height: parent.height
                            spacing: 8

                            Item {
                                width: parent.width
                                height: parent.height - 24

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 10
                                    height: Math.max(24, parent.height * modelData)
                                    radius: 5
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: theme ? theme.barStart : "#A7CFB3" }
                                        GradientStop { position: 1.0; color: theme ? theme.barEnd : "#DDE3B4" }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root.labels[index]
                                color: theme ? theme.textSecondary : "#6E8076"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 214
                padding: 18

                Row {
                    anchors.fill: parent
                    spacing: 18

                    Canvas {
                        id: donut
                        width: 112
                        height: 112
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var colors = [
                                root.chartColor("study"),
                                root.chartColor("work"),
                                root.chartColor("fun"),
                                root.chartColor("other")
                            ]
                            var values = [57, 23, 12, 8]
                            var start = -Math.PI / 2
                            ctx.lineWidth = 20
                            ctx.lineCap = "butt"
                            for (var i = 0; i < values.length; ++i) {
                                var angle = Math.PI * 2 * values[i] / 100
                                ctx.strokeStyle = colors[i]
                                ctx.beginPath()
                                ctx.arc(width / 2, height / 2, 40, start, start + angle)
                                ctx.stroke()
                                start += angle
                            }
                            ctx.fillStyle = "#FFFDF7"
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, 28, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }

                    Column {
                        width: parent.width - 130
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: "时间分布"
                            color: theme ? theme.textPrimary : "#123A35"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Repeater {
                            model: root.distribution
                            Row {
                                width: parent.width
                                height: 22
                                spacing: 8

                                Rectangle { width: 8; height: 8; radius: 4; color: root.chartColor(modelData.colorKey); anchors.verticalCenter: parent.verticalCenter }
                                Text { width: 42; text: modelData.label; color: theme ? theme.textSecondary : "#6E8076"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { width: 74; text: modelData.value; color: theme ? theme.textPrimary : "#123A35"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { width: parent.width - 132; text: modelData.ratio; color: theme ? theme.accentGreenDeep : "#4D8D73"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }
        }
    }
}
