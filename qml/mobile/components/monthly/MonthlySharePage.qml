import QtQuick
import QtQuick.Window
import ".."
import "../../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    property var theme
    property var report: ({})
    property var profile: ({})
    signal shareRequested(string channel, var previewItem)

    Rectangle {
        id: monthlyShareSheet
        anchors.fill: parent
        radius: 0
        color: root.theme.surface

        Column {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: SafeArea.margins.top + 58
            anchors.bottomMargin: SafeArea.margins.bottom + 12
            spacing: 12

            Row {
                width: parent.width
                height: 44

                Column {
                    width: parent.width - 80
                    spacing: 2

                    Text {
                        text: "Share preview"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "The image shows only aggregated monthly time"
                        color: root.theme.textMuted
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Text {
                    width: 80
                    height: parent.height
                    text: I18n.reportMonthLabel(root.languageMode, root.report) || root.tr("This Month")
                    color: root.theme.accentBright
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
                height: Math.min(532, monthlyShareSheet.height
                                  - SafeArea.margins.top
                                  - SafeArea.margins.bottom - 214)

                MobileRoundedFrame {
                    id: monthlyPoster
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 36,
                                    parent.height * 0.5625)
                    height: width / 0.5625
                    radius: 22
                    border.width: 1
                    border.color: "#42FFFFFF"

                    Rectangle {
                        anchors.fill: parent
                        color: "#111719"
                    }

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
                            text: root.tr(root.profile.eyebrow)
                                  || (root.report.monthLabel
                                      + " · MONTHLY STORY")
                            color: root.profile.accent || "#EFFFFFFF"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: I18n.reportTitle(root.languageMode, root.report)
                                  || "This month's time, gathered into a single card"
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

                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: root.report.totalText || "0 minutes"
                                color: "white"
                                font.family: root.theme.numberFontFamily
                                font.pixelSize: 31
                                font.weight: Font.Black
                            }

                            Text {
                                width: parent.width
                                text: root.report.summary
                                      || root.profile.opening
                                      || "Real records will make up this month's story here."
                                color: "#E7FFFFFF"
                                font.family: root.theme.fontFamily
                                font.pixelSize: 11
                                lineHeight: 1.42
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: parent.width
                            text: "TimeArc · aggregated time only"
                            color: "#AFFFFFFF"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 8
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            MobileShareActionBar {

                languageMode: root.languageMode
                width: parent.width
                theme: root.theme
                compact: true
                onChannelRequested: function(channel) {
                    root.shareRequested(channel, monthlyPoster)
                }
            }
        }
    }
}
