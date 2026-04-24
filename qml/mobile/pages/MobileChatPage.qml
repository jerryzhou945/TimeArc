import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell
    property int tabIndex: 0
    property var chats: [
        { title: "TimeArc 助手", summary: "你好！我是你的 TimeArc 助手...", time: "09:41", tag: "AI", icon: "⌂" },
        { title: "学习计划讨论", summary: "你：明天开始准备英语考试", time: "昨天", tag: "项目", icon: "□" },
        { title: "读书笔记整理", summary: "AI：根据你的阅读记录，我帮你...", time: "05/20", tag: "记忆", icon: "▣" },
        { title: "健身计划", summary: "你：这个计划安排得怎么样？", time: "05/19", tag: "项目", icon: "◇" }
    ]

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 28
        clip: true

        Column {
            id: contentColumn
            width: parent.width - (theme ? theme.pageMargin * 2 : 36)
            x: theme ? theme.pageMargin : 18
            y: theme ? theme.topSafe + 10 : 24
            spacing: 16

            Item {
                width: parent.width
                height: 44

                Text {
                    text: "聊天"
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 24
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
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
                        text: "+"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 21
                    }
                }
            }

            Row {
                width: parent.width
                height: 44
                spacing: 10

                Rectangle {
                    width: parent.width - 54
                    height: 44
                    radius: 22
                    color: theme ? theme.panelGlass : "#FFFDF9"
                    border.width: 1
                    border.color: theme ? theme.softStroke : "#EEE6D8"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕  搜索聊天"
                        color: theme ? theme.textMuted : "#93A297"
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: theme ? theme.accentGreenSoft : "#CFE3D2"

                    Text {
                        anchors.centerIn: parent
                        text: "＋"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 18
                    }
                }
            }

            MobileSegmentedControl {
                theme: root.theme
                width: parent.width
                height: 42
                options: ["全部", "AI 助手", "项目", "记忆"]
                currentIndex: root.tabIndex
                onChanged: function(index) { root.tabIndex = index }
            }

            Column {
                width: parent.width
                spacing: 12

                Repeater {
                    model: root.chats.filter(function(item) {
                        if (root.tabIndex === 0) return true
                        if (root.tabIndex === 1) return item.tag === "AI"
                        if (root.tabIndex === 2) return item.tag === "项目"
                        return item.tag === "记忆"
                    })

                    MobileSoftCard {
                        theme: root.theme
                        width: parent.width
                        height: 78
                        padding: 13
                        shadowOpacity: 0.07

                        Row {
                            anchors.fill: parent
                            spacing: 12

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 16
                                color: theme ? theme.chatColor(modelData.tag) : "#CFE3D2"
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    color: theme ? theme.textPrimary : "#123A35"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 44 - 12 - 48
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        width: parent.width - 52
                                        text: modelData.title
                                        color: theme ? theme.textPrimary : "#123A35"
                                        font.pixelSize: 15
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 44
                                        height: 20
                                        radius: 10
                                        color: theme ? theme.accentGreenSoft : "#CFE3D2"
                                        visible: modelData.tag.length > 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.tag
                                            color: theme ? theme.accentGreenDeep : "#4D8D73"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.summary
                                    color: theme ? theme.textSecondary : "#6E8076"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                width: 48
                                text: modelData.time
                                color: theme ? theme.textMuted : "#93A297"
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                                anchors.top: parent.top
                                anchors.topMargin: 4
                            }
                        }
                    }
                }
            }
        }
    }
}
