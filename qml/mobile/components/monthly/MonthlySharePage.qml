import QtQuick
import ".."

Item {
    id: root

    property var theme
    property var report: ({})
    property var profile: ({})
    signal shareRequested(string channel, var previewItem)

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 14

        Row {
            width: parent.width
            height: 42

            Column {
                width: parent.width - 74
                spacing: 2

                Text {
                    text: "分享预览"
                    color: "white"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.Bold
                }

                Text {
                    text: "保存和分享的图片会保持下面的样子"
                    color: "#BFFFFFFF"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 10
                }
            }

            Text {
                width: 74
                height: parent.height
                text: root.report.monthLabel || "本月"
                color: root.profile.accent || "#FFFFFF"
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Item {
            width: parent.width
            height: Math.min(446, root.height - 218)

            Rectangle {
                id: monthlyPoster
                anchors.centerIn: parent
                width: Math.min(parent.width - 30, parent.height * 0.5625)
                height: width / 0.5625
                radius: 22
                clip: true
                color: "#111719"

                Image {
                    anchors.fill: parent
                    source: root.profile.sceneSource || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#30101719"
                        }
                        GradientStop {
                            position: 0.48
                            color: "#50101719"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#D0101719"
                        }
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 20
                    spacing: 10

                    Text {
                        width: parent.width
                        text: root.profile.eyebrow
                              || (root.report.monthLabel + " · MONTHLY STORY")
                        color: root.profile.accent || "#EFFFFFFF"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.report.title
                              || "这个月的时间，被收进了一张卡片"
                        color: "white"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.Black
                        lineHeight: 1.12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.bottomMargin: 20
                    spacing: 9

                    Rectangle {
                        width: parent.width
                        height: facts.implicitHeight + 24
                        radius: 14
                        color: "#46FFFFFF"
                        border.width: 1
                        border.color: "#3FFFFFFF"

                        Column {
                            id: facts
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 6

                            Text {
                                text: root.report.totalText || "0 分钟"
                                color: "white"
                                font.family: root.theme.numberFontFamily
                                font.pixelSize: 25
                                font.weight: Font.Black
                            }

                            Text {
                                width: parent.width
                                text: root.report.summary
                                      || root.profile.opening
                                      || "真实记录会在这里组成这个月的故事。"
                                color: "#E7FFFFFF"
                                font.family: root.theme.fontFamily
                                font.pixelSize: 11
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "TimeArc · 仅呈现聚合后的时间"
                        color: "#AFFFFFFF"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 8
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 21
                    color: "transparent"
                    border.width: 1
                    border.color: "#42FFFFFF"
                }
            }
        }

        MobileShareActionBar {
            width: parent.width
            theme: root.theme
            compact: true
            onChannelRequested: function(channel) {
                root.shareRequested(channel, monthlyPoster)
            }
        }
    }
}
