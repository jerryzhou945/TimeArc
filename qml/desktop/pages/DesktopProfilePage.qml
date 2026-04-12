import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent
    clip: true

    signal nightModeToggled(bool enabled)

    property bool nightMode: false
    property color themeTextPrimary: nightMode ? "#F3E7DA" : "#4E342E"
    property color themeTextSecondary: nightMode ? "#C8B7AA" : "#9C806C"
    property color themePanelColor: nightMode ? "#4A3D37" : "#FFFDF9"
    property color themeBorderColor: nightMode ? "#6B5A51" : "#DDC9B5"
    property color themeAccentColor: nightMode ? "#C9976B" : "#E8C6A3"

    property color panelGlass: themePanelColor
    property real panelOpacity: nightMode ? 0.52 : 0.48

    property color cardGlass: nightMode ? "#5A4B44" : "#FFFDF9"
    property real cardOpacity: nightMode ? 0.46 : 0.42

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 30
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: pageColumn
            width: root.width
            spacing: 18

            // 顶部标题
            Column {
                spacing: 6

                Text {
                    text: "我的"
                    color: themeTextPrimary
                    font.pixelSize: 40
                    font.bold: true
                }

                Text {
                    text: "查看个人主页、使用概览与主题设置"
                    color: themeTextSecondary
                    font.pixelSize: 15
                }
            }

            // 个人信息区
            Rectangle {
                width: parent.width
                height: 210
                radius: 30
                color: "transparent"
                border.width: 2
                border.color: themeBorderColor
                clip: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 29
                    color: panelGlass
                    opacity: panelOpacity
                    z: -1
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 22

                    Rectangle {
                        width: 92
                        height: 92
                        radius: 46
                        color: themeAccentColor
                        opacity: 0.92
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "C"
                            color: nightMode ? "#FFF8F2" : "#6A4C3B"
                            font.pixelSize: 34
                            font.bold: true
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        width: parent.width - 140

                        Text {
                            text: "Chen"
                            color: themeTextPrimary
                            font.pixelSize: 30
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: "TimeArc 用户"
                            color: themeTextSecondary
                            font.pixelSize: 16
                        }

                        Text {
                            text: nightMode
                                  ? "今晚也在慢慢积累自己的时间轨迹。"
                                  : "今天也在慢慢积累自己的时间轨迹。"
                            color: themeTextSecondary
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            width: parent.width
                        }

                        Row {
                            spacing: 10

                            Rectangle {
                                width: 110
                                height: 34
                                radius: 17
                                color: cardGlass
                                opacity: cardOpacity
                                border.width: 1
                                border.color: themeBorderColor

                                Text {
                                    anchors.centerIn: parent
                                    text: "记忆湖旅者"
                                    color: themeTextPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                width: 96
                                height: 34
                                radius: 17
                                color: cardGlass
                                opacity: cardOpacity
                                border.width: 1
                                border.color: themeBorderColor

                                Text {
                                    anchors.centerIn: parent
                                    text: nightMode ? "夜晚模式" : "白天模式"
                                    color: themeTextPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            // 使用概览
            Row {
                width: parent.width
                spacing: 18

                Rectangle {
                    width: (parent.width - 36) / 3
                    height: 138
                    radius: 24
                    color: "transparent"
                    border.width: 2
                    border.color: themeBorderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 23
                        color: cardGlass
                        opacity: cardOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: "今日项目"
                            color: themeTextSecondary
                            font.pixelSize: 15
                        }

                        Text {
                            text: projectManager ? (projectManager.todayProjectMinutes + " 分钟") : "0 分钟"
                            color: themeTextPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: "今日累计手动计时"
                            color: themeTextSecondary
                            font.pixelSize: 13
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 36) / 3
                    height: 138
                    radius: 24
                    color: "transparent"
                    border.width: 2
                    border.color: themeBorderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 23
                        color: cardGlass
                        opacity: cardOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: "本月项目"
                            color: themeTextSecondary
                            font.pixelSize: 15
                        }

                        Text {
                            text: projectManager ? (projectManager.monthProjectMinutes + " 分钟") : "0 分钟"
                            color: themeTextPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: "本月累计手动计时"
                            color: themeTextSecondary
                            font.pixelSize: 13
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 36) / 3
                    height: 138
                    radius: 24
                    color: "transparent"
                    border.width: 2
                    border.color: themeBorderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 23
                        color: cardGlass
                        opacity: cardOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: "全部项目"
                            color: themeTextSecondary
                            font.pixelSize: 15
                        }

                        Text {
                            text: projectManager ? (projectManager.allProjectMinutes + " 分钟") : "0 分钟"
                            color: themeTextPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: "总累计手动计时"
                            color: themeTextSecondary
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // 个人信息 + 偏好
            Row {
                width: parent.width
                spacing: 18

                Rectangle {
                    width: (parent.width - 18) / 2
                    height: 220
                    radius: 28
                    color: "transparent"
                    border.width: 2
                    border.color: themeBorderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 27
                        color: cardGlass
                        opacity: cardOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 14

                        Text {
                            text: "个人资料"
                            color: themeTextPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: "昵称：Chen"
                            color: themeTextPrimary
                            font.pixelSize: 16
                        }

                        Text {
                            text: "身份：TimeArc 用户"
                            color: themeTextPrimary
                            font.pixelSize: 16
                        }

                        Text {
                            text: "风格：米色温馨 / 大圆角 / 半透明"
                            color: themeTextPrimary
                            font.pixelSize: 16
                            wrapMode: Text.Wrap
                            width: parent.width
                        }

                        Text {
                            text: "这里以后可以继续放头像、自定义签名、账号信息。"
                            color: themeTextSecondary
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            width: parent.width
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 2
                    height: 220
                    radius: 28
                    color: "transparent"
                    border.width: 2
                    border.color: themeBorderColor
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 27
                        color: cardGlass
                        opacity: cardOpacity
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 14

                        Text {
                            text: "偏好设置"
                            color: themeTextPrimary
                            font.pixelSize: 26
                            font.bold: true
                        }

                        Text {
                            text: "常用标签：学习 / 运动 / 游戏"
                            color: themeTextPrimary
                            font.pixelSize: 16
                        }

                        Text {
                            text: "当前主题：" + (nightMode ? "夜晚模式" : "白天模式")
                            color: themeTextPrimary
                            font.pixelSize: 16
                        }

                        Text {
                            text: "这里以后可以继续放通知设置、字体大小、语言切换。"
                            color: themeTextSecondary
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            width: parent.width
                        }
                    }
                }
            }

            // 夜晚模式设置（保留原功能）
            Rectangle {
                width: parent.width
                height: 200
                radius: 28
                color: "transparent"
                border.width: 2
                border.color: themeBorderColor
                clip: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 27
                    color: panelGlass
                    opacity: panelOpacity
                    z: -1
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 20

                    Text {
                        text: "夜晚模式"
                        color: themeTextPrimary
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Text {
                        text: nightMode
                              ? "当前已开启夜晚主题，背景和整体组件颜色会切换。"
                              : "当前为白天主题，点击右侧开关可切换到夜晚主题。"
                        color: themeTextSecondary
                        font.pixelSize: 15
                        wrapMode: Text.Wrap
                        width: parent.width
                    }

                    Row {
                        spacing: 18

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: nightMode ? "开启" : "关闭"
                            color: nightMode ? "#86D38E" : "#E06A6A"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Rectangle {
                            id: switchTrack
                            width: 86
                            height: 42
                            radius: 21
                            color: nightMode ? "#69C36F" : "#D96C6C"
                            border.width: 1
                            border.color: nightMode ? "#5CAA62" : "#C65A5A"

                            Behavior on color {
                                ColorAnimation { duration: 180 }
                            }

                            Rectangle {
                                id: switchKnob
                                width: 34
                                height: 34
                                radius: 17
                                y: 4
                                x: nightMode ? 48 : 4
                                color: "#FFFDF9"
                                border.width: 1
                                border.color: "#D8CFC7"

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    nightMode = !nightMode
                                    nightModeToggled(nightMode)
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 12
            }
        }
    }
}
