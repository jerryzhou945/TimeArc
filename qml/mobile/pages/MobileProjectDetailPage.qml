import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell

    function projectName() {
        return shell && shell.selectedProject ? shell.selectedProject.name : "学习计划"
    }

    function projectTag() {
        return shell && shell.selectedProject ? shell.selectedProject.tag : "学习"
    }

    function todaySeconds() {
        return shell ? shell.todaySecondsForProject(projectName(), projectTag()) : 0
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 96
        clip: true

        Column {
            id: contentColumn
            width: parent.width - (theme ? theme.pageMargin * 2 : 36)
            x: theme ? theme.pageMargin : 18
            y: theme ? theme.topSafe + 8 : 22
            spacing: 20

            Row {
                width: parent.width
                height: 44

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: theme ? theme.panelGlass : "#FFFDF9"
                    border.width: 1
                    border.color: theme ? theme.softStroke : "#EEE6D8"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell ? shell.goBack("timer") : undefined
                    }
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
                        text: "…"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 18
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 86
                    height: 86
                    radius: 25
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: theme ? theme.tagColor(projectTag()) : "#CFE3D2"

                    Text {
                        anchors.centerIn: parent
                        text: theme ? theme.tagIcon(projectTag()) : "•"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 30
                        font.bold: true
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: projectName()
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 25
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: projectTag()
                    color: theme ? theme.textSecondary : "#6E8076"
                    font.pixelSize: 13
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "今日累计"
                    color: theme ? theme.textMuted : "#93A297"
                    font.pixelSize: 13
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: timerManager && timerManager.currentProject === projectName()
                          ? shell.formatTimer(timerManager.elapsedSeconds)
                          : (shell ? shell.secondsToDisplay(todaySeconds()) : "0m")
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 31
                    font.bold: true
                }
            }

            Row {
                width: parent.width
                spacing: 10

                MobileStatCard {
                    theme: root.theme
                    width: (parent.width - 20) / 3
                    height: 76
                    title: "本周累计"
                    value: shell ? shell.secondsToDisplay(todaySeconds()) : "0m"
                    iconText: "W"
                    accentColor: theme ? theme.accentGreenSoft : "#CFE3D2"
                }

                MobileStatCard {
                    theme: root.theme
                    width: (parent.width - 20) / 3
                    height: 76
                    title: "本月累计"
                    value: "0m"
                    iconText: "M"
                    accentColor: theme ? theme.accentCream : "#F1E5BD"
                }

                MobileStatCard {
                    theme: root.theme
                    width: (parent.width - 20) / 3
                    height: 76
                    title: "总计时长"
                    value: "0m"
                    iconText: "Σ"
                    accentColor: theme ? theme.accentBlue : "#A9CCD5"
                }
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 196
                padding: 18

                Column {
                    anchors.fill: parent
                    spacing: 18

                    Text {
                        text: "计时记录"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Item {
                        width: parent.width
                        height: 126

                        Rectangle {
                            width: 54
                            height: 66
                            radius: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            color: "transparent"
                            border.width: 1
                            border.color: theme ? theme.cardStroke : "#E6DDCE"

                            Text {
                                anchors.centerIn: parent
                                text: "≡"
                                color: theme ? theme.textMuted : "#93A297"
                                font.pixelSize: 24
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 86
                            text: "暂无记录"
                            color: theme ? theme.textSecondary : "#6E8076"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 108
                            text: "开始计时，记录你的专注时光吧"
                            color: theme ? theme.textMuted : "#93A297"
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    MobileGradientButton {
        theme: root.theme
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: theme ? theme.pageMargin : 18
        anchors.rightMargin: theme ? theme.pageMargin : 18
        anchors.bottomMargin: 18
        height: 54
        text: timerManager && timerManager.running && timerManager.currentProject === root.projectName() ? "计时中" : "开始计时"
        fromColor: theme ? theme.accentGreen : "#8FBEA3"
        toColor: theme ? theme.accentYellow : "#E7D98F"
        onClicked: shell ? shell.startProject(root.projectName(), root.projectTag()) : undefined
    }
}
