import QtQuick
import QtQuick.Window
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
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
    parent: root.Window.window ? root.Window.window.contentItem : undefined
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
                    || "This stretch of time was quietly filed away on this device."
        var duration = app.durationText || "a stretch of time"
        var days = Number(app.recordedDays || 0)
        if (days > 1)
            return I18n.sentence(root.languageMode, "shareStoryDays",
                                 {days: days, duration: duration})
        return I18n.sentence(root.languageMode, "shareStoryAnon",
                             {duration: duration})
    }

    function exportAndShare(channel) {
        errorText = ""
        feedbackText = "Building the image…"
        poster.grabToImage(function(result) {
            if (typeof mobileUiService === "undefined" || !mobileUiService) {
                errorText = "Images cannot be saved in this preview environment."
                feedbackText = ""
                return
            }
            var stem = anonymous ? "memory" : (app.displayName || "memory")
            var path = mobileUiService.createShareImagePath(stem)
            if (!path || !result.saveToFile(path)) {
                errorText = "The image was not saved. Try again."
                feedbackText = ""
                return
            }
            if (!mobileUiService.shareImageToChannel(
                        path, channel || "system", "Share time keepsake card")) {
                errorText = mobileUiService.lastError
                feedbackText = ""
                return
            }
            feedbackText = Qt.platform.os === "android"
                    ? root.tr("System share sheet opened")
                    : I18n.sentence(root.languageMode, "imageSavedTo", {path: path})
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
        anchors.fill: parent
        radius: 0
        color: root.theme.bg

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        Column {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: SafeArea.margins.top + 14
            anchors.bottomMargin: SafeArea.margins.bottom + 10
            spacing: 12

            Row {
                width: parent.width
                height: 44

                Column {
                    width: parent.width - 52
                    spacing: 2

                    Text {
                        text: "Share preview"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "Original titles, contacts, URLs and package names never enter the image"
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

                    MobileSymbolIcon {

                        languageMode: root.languageMode
                        anchors.centerIn: parent
                        name: "close"
                        color: root.theme.textPrimary
                        iconSize: 22
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.close()
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.min(560, sheet.height
                                 - SafeArea.margins.top
                                 - SafeArea.margins.bottom - 220)

                MobileRoundedFrame {
                    id: poster
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * 0.5625)
                    height: width / 0.5625
                    radius: root.posterRadius
                    border.width: 1
                    border.color: root.theme.withAlpha(
                                      root.theme.memoryInk, 0.20)

                    Rectangle {
                        anchors.fill: parent
                        color: root.theme.memoryBrown
                    }

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
                            text: "TimeArc · time keepsake"
                            color: root.theme.memoryCopy
                            font.family: root.theme.fontFamily
                            font.pixelSize: 11
                        }

                        Row {
                            width: parent.width
                            height: 48
                            spacing: 10

                            MobileAppIcon {

                                languageMode: root.languageMode
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
                                      ? "A stretch of time remembered"
                                      : (root.app.displayName || "App")
                                color: root.theme.memoryInk
                                font.family: root.theme.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.Bold
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
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
                            text: I18n.sentence(root.languageMode, "recordedDaysShare",
                                                {days: root.app.recordedDays || 0,
                                                 percent: root.app.sharePct || 0})
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
                        text: root.anonymous ? "Anonymised" : "Show app"
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

                    languageMode: root.languageMode
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
