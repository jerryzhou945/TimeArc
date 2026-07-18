import QtQuick
import "../components"

Item {
    id: root

    required property var theme
    property bool wallpaperActive: false
    property var lakeModel: ({
        "report": {},
        "moments": [],
        "topApps": [],
        "empty": true
    })
    readonly property var report: lakeModel.report || ({})
    readonly property var moments: lakeModel.moments || []

    function hasService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function reload() {
        lakeModel = hasService()
                ? mobileUsageService.getMemoryLakeForCurrentMonth()
                : ({ "report": {}, "moments": [], "topApps": [], "empty": true })
    }

    Component.onCompleted: reload()

    Connections {
        target: root.hasService() ? mobileUsageService : null
        function onDataChanged() { root.reload() }
        function onStatusChanged() { root.reload() }
    }

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
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: content.implicitHeight + 30

            Column {
                id: content
                width: flick.width - 32
                x: 16
                spacing: 16

                Row {
                    width: parent.width
                    height: 54

                    Column {
                        width: parent.width - 110
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "记忆湖"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 27
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "回看被时间留下的真实片段"
                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    MobileGlassPanel {
                        width: 110
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                        wallpaperActive: root.wallpaperActive
                        strong: true

                        Text {
                            anchors.centerIn: parent
                            text: root.report.monthLabel || "本月"
                            color: root.theme.textPrimary
                            font.family: root.theme.numberFontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    id: reportCover
                    width: parent.width
                    height: 252
                    radius: 18
                    clip: true
                    color: root.theme.isDark ? "#17332A" : "#BBD29C"

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var g = ctx.createLinearGradient(0, 0, width, height)
                            g.addColorStop(0, "#17352C")
                            g.addColorStop(0.58, "#567D4E")
                            g.addColorStop(1, "#B7C991")
                            ctx.fillStyle = g
                            ctx.fillRect(0, 0, width, height)

                            for (var i = 0; i < 44; ++i) {
                                var x = (i * 79) % width
                                var y = 40 + (i * 53) % (height - 20)
                                var r = 6 + (i % 5) * 3
                                ctx.fillStyle = i % 3 === 0
                                        ? "rgba(218,228,146,.30)"
                                        : "rgba(47,91,57,.42)"
                                ctx.beginPath()
                                ctx.ellipse(x, y, r * 0.55, r, i * 0.43,
                                            0, Math.PI * 2)
                                ctx.fill()
                            }
                            ctx.strokeStyle = "rgba(225,243,226,.28)"
                            ctx.lineWidth = 1
                            for (var rain = 20; rain < width + 100; rain += 34) {
                                ctx.beginPath()
                                ctx.moveTo(rain, 0)
                                ctx.lineTo(rain - 72, height)
                                ctx.stroke()
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: root.theme.isDark ? "#3D000000" : "#26000000"
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 9

                        Text {
                            text: root.report.monthLabel || "本月时间报告"
                            color: "white"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: root.report.title || "等待第一段时间被记住"
                            color: "white"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 26
                            font.weight: Font.Bold
                            lineHeight: 1.18
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.report.summary
                                  || "同步后，这里会从真实记录生成月度故事。"
                            color: "#E7F0E5"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13
                            lineHeight: 1.42
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Item { width: 1; height: 4 }

                        Rectangle {
                            width: 134
                            height: 42
                            radius: root.theme.controlRadius
                            color: "#EAF5E8"

                            Text {
                                anchors.centerIn: parent
                                text: "打开完整月报"
                                color: "#17352C"
                                font.family: root.theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: monthlyStory.open()
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 38

                    Text {
                        width: parent.width - 120
                        text: "最近被记住"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 120
                        text: "使用友好名称与真实图标"
                        color: root.theme.textMuted
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    width: parent.width
                    visible: root.moments.length === 0
                    text: "还没有被记住的片段。完成授权并同步后，应用和时间会在这里形成可回看的句子。"
                    color: root.theme.textSecondary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14
                    lineHeight: 1.5
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.moments

                    Item {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 132

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: root.theme.withAlpha(
                                       root.theme.textPrimary, 0.14)
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 14

                            Column {
                                width: 48
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: {
                                        var raw = modelData.dateLabel || ""
                                        return raw.length >= 10
                                                ? raw.slice(8, 10) : "·"
                                    }
                                    color: root.theme.textPrimary
                                    font.family: root.theme.numberFontFamily
                                    font.pixelSize: 23
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    width: parent.width
                                    text: "本月"
                                    color: root.theme.textMuted
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Column {
                                width: parent.width - 62
                                spacing: 7

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: root.theme.textPrimary
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.body
                                    color: root.theme.textSecondary
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 12
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Row {
                                    width: parent.width
                                    height: 36
                                    spacing: 7

                                    Repeater {
                                        model: modelData.apps || []

                                        MobileAppIcon {
                                            required property var modelData
                                            theme: root.theme
                                            app: modelData
                                            iconSize: 34
                                            cornerRadius: 9
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.durationText || ""
                                        color: root.theme.textMuted
                                        font.family: root.theme.numberFontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MobileMonthlyStory {
        id: monthlyStory
        theme: root.theme
        model: root.lakeModel
    }
}
