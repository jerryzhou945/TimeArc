import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell

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
                    anchors.centerIn: parent
                    text: "设置"
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            SettingsGroup {
                theme: root.theme
                width: parent.width
                title: "通用设置"
                rows: [
                    { title: "深色模式", value: "", toggle: true, checked: false, icon: "◐" },
                    { title: "通知设置", value: "", toggle: false, checked: false, icon: "♧" },
                    { title: "专注模式", value: "25 分钟", toggle: false, checked: false, icon: "◎" },
                    { title: "语言", value: "简体中文", toggle: false, checked: false, icon: "▣" }
                ]
            }

            SettingsGroup {
                theme: root.theme
                width: parent.width
                title: "记录设置"
                rows: [
                    { title: "自动记录", value: "", toggle: true, checked: true, icon: "◌" },
                    { title: "信任应用管理", value: "", toggle: false, checked: false, icon: "◇" },
                    { title: "自动分类规则", value: "", toggle: false, checked: false, icon: "□" }
                ]
            }

            SettingsGroup {
                theme: root.theme
                width: parent.width
                title: "数据"
                rows: [
                    { title: "数据备份", value: "", toggle: false, checked: false, icon: "⇧" },
                    { title: "数据同步", value: "", toggle: false, checked: false, icon: "↻" }
                ]
            }
        }
    }

    component SettingsGroup: Column {
        property var theme
        property string title: ""
        property var rows: []

        spacing: 8

        Text {
            text: parent.title
            color: parent.theme ? parent.theme.textPrimary : "#123A35"
            font.pixelSize: 14
            font.bold: true
        }

        MobileSoftCard {
            theme: parent.theme
            width: parent.width
            height: parent.rows.length * 48
            padding: 0
            shadowOpacity: 0.06

            Column {
                anchors.fill: parent

                Repeater {
                    model: rows

                    Item {
                        width: parent.width
                        height: 48
                        property bool rowChecked: modelData.checked

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12

                            Text {
                                width: 20
                                text: modelData.icon
                                color: theme ? theme.textSecondary : "#6E8076"
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: parent.width - 20 - 12 - 86
                                text: modelData.title
                                color: theme ? theme.textPrimary : "#123A35"
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: 86
                                height: 34
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    visible: !modelData.toggle
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.value.length > 0 ? modelData.value + "  ›" : "›"
                                    color: theme ? theme.textMuted : "#93A297"
                                    font.pixelSize: 12
                                }

                                Rectangle {
                                    visible: modelData.toggle
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 46
                                    height: 26
                                    radius: 13
                                    color: rowChecked ? (theme ? theme.accentGreen : "#8FBEA3") : (theme ? theme.toggleOff : "#E3DED3")

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        y: 2
                                        x: rowChecked ? parent.width - width - 2 : 2
                                        color: "#FFFDF7"

                                        Behavior on x {
                                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: rowChecked = !rowChecked
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            height: 1
                            color: theme ? theme.softStroke : "#EEE6D8"
                            opacity: index === rows.length - 1 ? 0 : 0.6
                        }
                    }
                }
            }
        }
    }
}
