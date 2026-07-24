import QtQuick

Item {
    id: root

    required property var theme
    property var app: ({})
    property string dateRange: ""
    property bool anonymous: false
    property url wallpaperSource: ""
    property bool opened: false
    property string errorText: ""
    property string feedbackText: ""
    readonly property int posterRadius: 22

    signal closed()

    anchors.fill: parent
    visible: opened
    enabled: visible
    z: 100

    function openFor(appModel, rangeText) {
        app = appModel || ({})
        dateRange = rangeText || ""
        errorText = ""
        feedbackText = ""
        opened = true
    }

    function close() {
        opened = false
        closed()
    }

    function storyForShare() {
        if (!anonymous)
            return app.storyText
                    || "这段时间被安静地收进了本地档案。"
        var duration = app.durationText || "一段时间"
        var days = Number(app.recordedDays || 0)
        if (days > 1)
            return "在 " + days + " 个被记录的日子里，"
                    + duration + " 汇成了一段只属于自己的时间。"
        return duration + " 被安静地收进了时间档案，没有留下身份线索。"
    }

    function exportAndShare(channel) {
        errorText = ""
        feedbackText = "正在生成图片…"
        poster.grabToImage(function(result) {
            if (typeof mobileUiService === "undefined" || !mobileUiService) {
                errorText = "当前预览环境无法保存图片。"
                feedbackText = ""
                return
            }
            var stem = anonymous ? "memory" : (app.displayName || "memory")
            var path = mobileUiService.createShareImagePath(stem)
            if (!path || !result.saveToFile(path)) {
                errorText = "图片没有保存成功，请重试。"
                feedbackText = ""
                return
            }
            if (!mobileUiService.shareImageToChannel(
                        path, channel || "system", "分享时间纪念卡")) {
                errorText = mobileUiService.lastError
                feedbackText = ""
                return
            }
            feedbackText = Qt.platform.os === "android"
                    ? "已打开系统分享面板"
                    : "图片已保存到 " + path
        }, Qt.size(1080, 1920))
    }

    Rectangle {
        anchors.fill: parent
        color: root.theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: sheet
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(parent.height - 22, 760)
        radius: 18
        color: root.theme.surface

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Row {
                width: parent.width
                height: 44

                Column {
                    width: parent.width - 52
                    spacing: 2

                    Text {
                        text: "分享预览"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "原始标题、联系人、网址和包名不会进入图片"
                        color: root.theme.textMuted
                        font.family: root.theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: root.theme.surfaceRaised

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.theme.textPrimary
                        font.pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.close()
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.min(510, sheet.height - 188)

                Rectangle {
                    id: poster
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * 0.5625)
                    height: width / 0.5625
                    radius: root.posterRadius
                    color: root.theme.memoryBrown
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.wallpaperSource
                        fillMode: Image.PreserveAspectCrop
                        visible: source.toString().length > 0
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: root.wallpaperSource.toString().length > 0
                               ? "#8C15191D" : "#0015191D"
                    }

                    Canvas {
                        anchors.fill: parent
                        opacity: 0.30
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var grad = ctx.createLinearGradient(0, 0, width, height)
                            grad.addColorStop(0, "#2D7780")
                            grad.addColorStop(0.52, "#2D2724")
                            grad.addColorStop(1, "#17191D")
                            ctx.fillStyle = grad
                            ctx.fillRect(0, 0, width, height)
                            ctx.strokeStyle = "rgba(255,255,255,.12)"
                            ctx.lineWidth = 1
                            for (var y = 70; y < height; y += 64) {
                                ctx.beginPath()
                                ctx.moveTo(24, y)
                                ctx.lineTo(width - 24, y - 30)
                                ctx.stroke()
                            }
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 15

                        Text {
                            width: parent.width
                            text: "TimeArc · 时间纪念卡"
                            color: root.theme.memoryCopy
                            font.family: root.theme.fontFamily
                            font.pixelSize: 11
                        }

                        Row {
                            width: parent.width
                            height: 48
                            spacing: 10

                            MobileAppIcon {
                                visible: !root.anonymous
                                theme: root.theme
                                app: root.app
                                iconSize: 46
                                cornerRadius: 11
                            }

                            Text {
                                width: parent.width
                                       - (root.anonymous ? 0 : 56)
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.anonymous
                                      ? "一段被记住的时间"
                                      : (root.app.displayName || "应用")
                                color: root.theme.memoryInk
                                font.family: root.theme.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                        }

                        Item { width: 1; height: 6 }

                        Text {
                            width: parent.width
                            text: root.app.durationText || "0s"
                            color: root.theme.memoryInk
                            font.family: root.theme.numberFontFamily
                            font.pixelSize: 42
                            font.weight: Font.Bold
                        }

                        Text {
                            width: parent.width
                            text: root.dateRange
                            color: root.theme.memoryCopy
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            width: parent.width
                            text: root.storyForShare()
                            color: root.theme.memoryInk
                            font.family: root.theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            lineHeight: 1.45
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.theme.withAlpha(
                                       root.theme.memoryInk, 0.18)
                        }

                        Text {
                            width: parent.width
                            text: "记录 " + (root.app.recordedDays || 0)
                                  + " 天 · 占这段时间 "
                                  + (root.app.sharePct || 0) + "%"
                            color: root.theme.memoryCopy
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: root.app.conversionText || ""
                            color: root.theme.memoryCopy
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                            lineHeight: 1.45
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        id: posterHairline
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: root.posterRadius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: root.theme.withAlpha(
                                          root.theme.memoryInk, 0.20)
                    }
                }
            }

            Column {
                width: parent.width
                height: 108
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: root.theme.controlRadius
                    color: root.theme.surfaceRaised

                    Text {
                        anchors.centerIn: parent
                        text: root.anonymous ? "已匿名" : "显示应用"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.anonymous = !root.anonymous
                    }
                }

                MobileShareActionBar {
                    width: parent.width
                    theme: root.theme
                    compact: true
                    onChannelRequested: function(channel) {
                        root.exportAndShare(channel)
                    }
                }
            }

            Text {
                width: parent.width
                text: root.errorText.length > 0
                      ? root.errorText : root.feedbackText
                color: root.errorText.length > 0
                       ? root.theme.error : root.theme.success
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
