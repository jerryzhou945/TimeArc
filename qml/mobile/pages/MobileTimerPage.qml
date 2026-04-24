import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property var theme
    property var shell
    property string selectedTag: "学习"
    property var categories: ["学习", "工作", "运动", "娱乐", "阅读", "社交", "生活", "其他"]

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 30
        clip: true

        Column {
            id: contentColumn
            width: parent.width - (theme ? theme.pageMargin * 2 : 36)
            x: theme ? theme.pageMargin : 18
            y: theme ? theme.topSafe + 8 : 22
            spacing: 18

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
                        onClicked: shell ? shell.goBack("home") : undefined
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "手动项目计时"
                    color: theme ? theme.textPrimary : "#123A35"
                    font.pixelSize: 19
                    font.bold: true
                }

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: theme ? theme.accentGreenSoft : "#CFE3D2"

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: theme ? theme.textPrimary : "#123A35"
                        font.pixelSize: 22
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (projectManager)
                                projectManager.addProject("新项目", root.selectedTag)
                        }
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "选择一个项目开始计时"
                color: theme ? theme.textMuted : "#93A297"
                font.pixelSize: 13
            }

            Flow {
                width: parent.width
                spacing: 10
                rowSpacing: 10

                Repeater {
                    model: root.categories

                    MobileCategoryPill {
                        theme: root.theme
                        text: modelData
                        iconText: theme ? theme.tagIcon(modelData) : "•"
                        selected: root.selectedTag === modelData
                        onClicked: root.selectedTag = modelData
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 14

                Repeater {
                    model: shell ? (shell.refreshTick, shell.projectItems().filter(function(item) { return root.selectedTag === "其他" ? true : item.tag === root.selectedTag })) : []

                    MobileProjectCard {
                        theme: root.theme
                        width: parent.width
                        projectName: modelData.name
                        tag: modelData.tag
                        timeText: "今日 " + (shell ? shell.secondsToDisplay(modelData.todaySeconds) : "0m")
                        onStartRequested: function(name, tag) {
                            if (shell)
                                shell.startProject(name, tag)
                        }
                        onOpenRequested: function(name, tag) {
                            if (shell)
                                shell.openProject(name, tag)
                        }
                    }
                }
            }
        }
    }
}
