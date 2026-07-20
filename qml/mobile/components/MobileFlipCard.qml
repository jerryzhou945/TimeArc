import QtQuick

Item {
    id: root

    required property var theme
    property var app: ({})
    property bool wallpaperActive: false
    property bool selected: true
    property bool flipped: false
    property real flipAngle: flipped ? 180 : 0
    readonly property color frontInk: wallpaperActive
                                               ? theme.wallpaperInk
                                               : theme.textPrimary
    readonly property color frontMuted: wallpaperActive
                                                 ? theme.wallpaperMuted
                                                 : theme.textSecondary

    signal shareRequested(var app)
    signal permissionRequested()

    function value(key, fallbackValue) {
        return root.app && root.app[key] !== undefined
                ? root.app[key] : fallbackValue
    }

    Behavior on flipAngle {
        NumberAnimation {
            duration: root.theme.normalDuration
            easing.type: Easing.OutQuart
        }
    }

    Item {
        id: front
        anchors.fill: parent
        visible: root.flipAngle < 90
        transform: Rotation {
            origin.x: front.width / 2
            origin.y: front.height / 2
            axis.y: 1
            angle: root.flipAngle
        }

        Rectangle {
            anchors.fill: parent
            radius: root.theme.cardRadius
            color: root.wallpaperActive
                   ? root.theme.contentClear
                   : root.theme.withAlpha(root.theme.surface, 0.34)
            border.width: root.wallpaperActive ? 1 : 0
            border.color: root.wallpaperActive
                          ? root.theme.timelineLine : "transparent"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.58
            radius: root.theme.cardRadius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.38
                    color: root.theme.isDark ? "#18000000" : "#18FFFFFF"
                }
                GradientStop {
                    position: 1
                    color: root.theme.isDark ? "#86101114" : "#8FFFFFFF"
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            Row {
                width: parent.width
                height: 70
                spacing: 14

                MobileAppIcon {
                    theme: root.theme
                    app: root.app
                    iconSize: 64
                    cornerRadius: 15
                }

                Column {
                    width: parent.width - 78
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        width: parent.width
                        text: root.value("displayName", "等待记录")
                        color: root.frontInk
                        font.family: root.theme.fontFamily
                        font.pixelSize: 21
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: "累计时间卡 · "
                              + root.value("sharePct", 0) + "%"
                        color: root.frontMuted
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            Item { width: 1; height: 26 }

            Text {
                width: parent.width
                text: root.value("durationText", "0s")
                color: root.frontInk
                font.family: root.theme.numberFontFamily
                font.pixelSize: 42
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: root.value("storyText",
                                 "授权并同步后，这里会出现真实使用记录。")
                color: root.frontMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 14
                lineHeight: 1.45
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Item { width: 1; height: 4 }

            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: root.theme.withAlpha(root.theme.progressTrack, 0.76)

                Rectangle {
                    width: parent.width * Math.max(
                               0.03,
                               Math.min(1, root.value("relativePct", 0) / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.theme.accent
                }
            }

            Item { width: 1; height: 8 }

            Row {
                width: parent.width
                height: 44

                Text {
                    width: parent.width - 48
                    anchors.verticalCenter: parent.verticalCenter
                    text: "轻点翻面，查看这段时间的百科"
                    color: root.frontMuted
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12
                }

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: root.wallpaperActive
                           ? root.theme.contentWash
                           : root.theme.surfaceRaised

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: root.frontInk
                        font.pixelSize: 20
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.flipped = true
        }
    }

    Item {
        id: back
        anchors.fill: parent
        visible: root.flipAngle >= 90
        transform: Rotation {
            origin.x: back.width / 2
            origin.y: back.height / 2
            axis.y: 1
            angle: root.flipAngle - 180
        }

        Rectangle {
            anchors.fill: parent
            radius: root.theme.cardRadius
            color: root.theme.withAlpha(root.theme.memoryBrown, 0.94)
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            Row {
                width: parent.width
                height: 52
                spacing: 12

                MobileAppIcon {
                    theme: root.theme
                    app: root.app
                    iconSize: 48
                    cornerRadius: 12
                }

                Column {
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: "时间百科 · " + root.value("displayName", "应用")
                        color: root.theme.memoryInk
                        font.family: root.theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: "所有表达均来自本地记录"
                        color: root.theme.memoryCopy
                        font.family: root.theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.withAlpha(root.theme.memoryInk, 0.16)
            }

            FactRow {
                width: parent.width
                label: "初次记录"
                value: root.value("firstDateLocal", "等待同步")
            }

            FactRow {
                width: parent.width
                label: "累计记录"
                value: root.value("durationText", "0s")
            }

            FactRow {
                width: parent.width
                label: "出现日数"
                value: root.value("recordedDays", 0) + " 天"
            }

            FactRow {
                width: parent.width
                label: "日历跨度"
                value: root.value("spanDays", 0) + " 天"
            }

            Text {
                width: parent.width
                text: root.value("conversionText",
                                 "同步后会生成一条明确标注的时长换算。")
                color: root.theme.memoryCopy
                font.family: root.theme.fontFamily
                font.pixelSize: 13
                lineHeight: 1.45
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Item { width: 1; height: 4 }

            Row {
                width: parent.width
                height: root.theme.controlHeight
                spacing: 10

                Rectangle {
                    width: (parent.width - 10) * 0.38
                    height: parent.height
                    radius: root.theme.controlRadius
                    color: root.theme.withAlpha(root.theme.memoryInk, 0.10)

                    Text {
                        anchors.centerIn: parent
                        text: "返回正面"
                        color: root.theme.memoryInk
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.flipped = false
                    }
                }

                Rectangle {
                    width: (parent.width - 10) * 0.62
                    height: parent.height
                    radius: root.theme.controlRadius
                    color: root.theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "分享时间纪念卡"
                        color: "white"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.shareRequested(root.app)
                    }
                }
            }
        }
    }

    component FactRow: Row {
        property string label: ""
        property string value: ""

        height: 28

        Text {
            width: parent.width * 0.38
            text: label
            color: root.theme.memoryCopy
            font.family: root.theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            width: parent.width * 0.62
            text: value
            color: root.theme.memoryInk
            font.family: root.theme.numberFontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
