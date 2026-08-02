import QtQuick
import QtQuick.Window

Item {
    id: root

    required property var theme
    property var dashboard: ({})
    property url wallpaperSource: ""
    property bool opened: false
    property string message: ""

    anchors.fill: parent
    parent: root.Window.window ? root.Window.window.contentItem : undefined
    visible: opened
    enabled: visible
    z: 110

    function openForRanking(model) {
        dashboard = model || ({})
        message = ""
        opened = true
    }

    function shareCopy() {
        var apps = dashboard.topApps || []
        if (apps.length === 0)
            return "时间还在等待第一段真实记录。"
        return (apps[0].displayName || "一个应用")
                + " 留下了最多时间；其余片段，也共同组成了这段生活的去向。"
    }

    function exportAndShare(channel) {
        message = "正在生成排行卡片…"
        poster.grabToImage(function(result) {
            if (typeof mobileUiService === "undefined" || !mobileUiService) {
                message = "当前环境无法保存图片。"
                return
            }
            var path = mobileUiService.createShareImagePath(
                        (dashboard.rangeLabel || "ranking") + "-ranking")
            if (!path || !result.saveToFile(path)) {
                message = "排行图片保存失败，请重试。"
                return
            }
            if (!mobileUiService.shareImageToChannel(
                        path, channel || "system", "分享时间使用排行")) {
                message = mobileUiService.lastError
                return
            }
            message = Qt.platform.os === "android"
                    ? "已打开系统分享面板" : "排行图片已保存"
        }, Qt.size(1080, 1920))
    }

    Rectangle {
        anchors.fill: parent
        color: root.theme.scrim
        MouseArea {
            anchors.fill: parent
            onClicked: root.opened = false
        }
    }

    Rectangle {
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
                height: 42
                Text {
                    width: parent.width - 50
                    text: "排行分享预览"
                    color: root.theme.textPrimary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle {
                    width: 42
                    height: 42
                    radius: 21
                    color: root.theme.surfaceRaised
                    MobileSymbolIcon {
                        anchors.centerIn: parent
                        name: "close"
                        color: root.theme.textPrimary
                        iconSize: 22
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.opened = false
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.min(570, parent.parent.height
                                 - SafeArea.margins.top
                                 - SafeArea.margins.bottom - 150)

                Rectangle {
                    id: poster
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * 0.5625)
                    height: width / 0.5625
                    radius: 18
                    clip: true
                    color: "#152124"

                    Image {
                        anchors.fill: parent
                        source: root.wallpaperSource
                        fillMode: Image.PreserveAspectCrop
                        visible: source.toString().length > 0
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: root.wallpaperSource.toString().length > 0
                               ? "#8710181B" : "#2010181B"
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#1827BBC0" }
                            GradientStop { position: 0.55; color: "#2710181B" }
                            GradientStop { position: 1; color: "#B810181B" }
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        Text {
                            text: "TIMEARC · "
                                  + (root.dashboard.rangeLabel || "时间排行")
                            color: "#AFFFFFFF"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                        Text {
                            text: root.dashboard.totalText || "0 分钟"
                            color: "white"
                            font.family: root.theme.numberFontFamily
                            font.pixelSize: 35
                            font.weight: Font.Black
                        }
                        Text {
                            width: parent.width
                            text: root.shareCopy()
                            color: "#E5FFFFFF"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13
                            lineHeight: 1.45
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#3AFFFFFF"
                        }

                        Repeater {
                            model: (root.dashboard.topApps || []).slice(0, 5)

                            Row {
                                required property var modelData
                                required property int index
                                width: parent.width
                                height: 50
                                spacing: 9

                                Text {
                                    width: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: index + 1
                                    color: index === 0 ? "#87E0E5" : "#AFFFFFFF"
                                    font.family: root.theme.numberFontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                                MobileAppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    theme: root.theme
                                    app: modelData
                                    iconSize: 36
                                    cornerRadius: 9
                                }
                                Column {
                                    width: parent.width - 72
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5
                                    Row {
                                        width: parent.width
                                        Text {
                                            width: parent.width - 70
                                            text: modelData.displayName || "未知应用"
                                            color: "white"
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: 70
                                            text: modelData.durationText || "0 分钟"
                                            color: "#DFFFFFFF"
                                            font.family: root.theme.numberFontFamily
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                    Rectangle {
                                        width: parent.width
                                        height: 3
                                        radius: 2
                                        color: "#35FFFFFF"
                                        Rectangle {
                                            width: parent.width
                                                   * Math.max(0, Math.min(100,
                                                       modelData.relativePct || 0)) / 100
                                            height: parent.height
                                            radius: 2
                                            color: "#79D5DC"
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: (root.dashboard.rangeText || "")
                                  + " · 仅呈现聚合时长"
                            color: "#9FFFFFFF"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
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
            Text {
                width: parent.width
                text: root.message
                color: root.theme.textMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
