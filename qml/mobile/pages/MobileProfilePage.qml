import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell
    property var rows: [
        { title: "分类管理", icon: "♧", action: "" },
        { title: "标签管理", icon: "◇", action: "" },
        { title: "应用管理", icon: "▣", action: "" },
        { title: "数据导出", icon: "⇩", action: "" },
        { title: "回收站", icon: "⌫", action: "" },
        { title: "关于 TimeArc", icon: "ⓘ", action: "" }
    ]

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
                height: 58
                spacing: 12

                Rectangle {
                    width: 50
                    height: 50
                    radius: 25
                    color: theme ? theme.accentGreenSoft : "#CFE3D2"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "T"; color: theme ? theme.textPrimary : "#123A35"; font.pixelSize: 22; font.bold: true }
                }

                Column {
                    width: parent.width - 50 - 12 - 42
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Row {
                        spacing: 8
                        Text { text: "TimeArc 用户"; color: theme ? theme.textPrimary : "#123A35"; font.pixelSize: 17; font.bold: true }
                        Rectangle {
                            width: 34
                            height: 18
                            radius: 9
                            color: theme ? theme.accentGreen : "#8FBEA3"
                            Text { anchors.centerIn: parent; text: "Pro"; color: "#FFFFFF"; font.pixelSize: 10; font.bold: true }
                        }
                    }

                    Text {
                        text: "让时间产生价值"
                        color: theme ? theme.textSecondary : "#6E8076"
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: theme ? theme.panelGlass : "#FFFDF9"
                    border.width: 1
                    border.color: theme ? theme.softStroke : "#EEE6D8"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "⚙"; color: theme ? theme.textPrimary : "#123A35"; font.pixelSize: 17 }
                    MouseArea { anchors.fill: parent; onClicked: shell ? shell.openSettingsPage() : undefined }
                }
            }

            Text {
                text: "数据概览"
                color: theme ? theme.textPrimary : "#123A35"
                font.pixelSize: 16
                font.bold: true
            }

            Grid {
                width: parent.width
                columns: 2
                rowSpacing: 12
                columnSpacing: 12

                MobileStatCard { theme: root.theme; width: (parent.width - 12) / 2; height: 74; title: "总计时长"; value: shell ? shell.secondsToDisplay(shell.yearTotalSeconds() > 0 ? shell.yearTotalSeconds() : 128 * 3600 + 36 * 60) : "128h 36m"; iconText: "Σ"; accentColor: theme ? theme.accentGreenSoft : "#CFE3D2" }
                MobileStatCard { theme: root.theme; width: (parent.width - 12) / 2; height: 74; title: "连续记录"; value: "23 天"; iconText: "•"; accentColor: theme ? theme.accentCream : "#F1E5BD" }
                MobileStatCard { theme: root.theme; width: (parent.width - 12) / 2; height: 74; title: "记忆数量"; value: "156 条"; iconText: "◌"; accentColor: theme ? theme.accentBlue : "#A9CCD5" }
                MobileStatCard { theme: root.theme; width: (parent.width - 12) / 2; height: 74; title: "项目数量"; value: shell ? shell.projectItems().length + " 个" : "12 个"; iconText: "□"; accentColor: theme ? theme.accentLavender : "#CFC6DD" }
            }

            Text {
                text: "更多功能"
                color: theme ? theme.textPrimary : "#123A35"
                font.pixelSize: 16
                font.bold: true
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 288
                padding: 0
                shadowOpacity: 0.06

                Column {
                    anchors.fill: parent

                    MobileProfileRow {
                        theme: root.theme
                        width: parent.width
                        title: "统计详情"
                        iconText: "▥"
                        onClicked: shell ? shell.openStatsPage() : undefined
                    }

                    Repeater {
                        model: root.rows
                        MobileProfileRow {
                            theme: root.theme
                            width: parent.width
                            title: modelData.title
                            iconText: modelData.icon
                        }
                    }
                }
            }
        }
    }

    component MobileProfileRow: Item {
        property var theme
        property string title: ""
        property string iconText: ""
        signal clicked()

        height: 41

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                width: 22
                text: iconText
                color: theme ? theme.textSecondary : "#6E8076"
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                width: parent.width - 48
                text: title
                color: theme ? theme.textPrimary : "#123A35"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "›"
                color: theme ? theme.textMuted : "#93A297"
                font.pixelSize: 20
                anchors.verticalCenter: parent.verticalCenter
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
            opacity: 0.6
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }
}
