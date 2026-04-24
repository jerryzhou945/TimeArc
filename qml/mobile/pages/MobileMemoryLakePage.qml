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
        contentHeight: contentColumn.height + 28
        clip: true

        Column {
            id: contentColumn
            width: parent.width - (theme ? theme.pageMargin * 2 : 36)
            x: theme ? theme.pageMargin : 18
            y: theme ? theme.topSafe + 10 : 24
            spacing: 16

            Text {
                text: "记忆湖"
                color: theme ? theme.textPrimary : "#123A35"
                font.pixelSize: 24
                font.bold: true
            }

            MobileMemoryLakeCard {
                theme: root.theme
                width: parent.width
                height: Math.min(430, root.height - 210)
                totalText: shell ? shell.secondsToDisplay(shell.todayTotalSeconds()) : "4h 31m"
                changeText: "+12% 较昨日"
                progress: shell ? Math.min(1, shell.todayTotalSeconds() / (8 * 3600)) : 0.54
            }

            MobileSoftCard {
                theme: root.theme
                width: parent.width
                height: 96
                padding: 18

                Row {
                    anchors.fill: parent

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: "今日收获"
                            color: theme ? theme.textPrimary : "#123A35"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Row {
                            spacing: 24

                            Text {
                                text: "+2 条记忆"
                                color: theme ? theme.accentGreenDeep : "#4D8D73"
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                text: "+1 条成长"
                                color: theme ? theme.accentGreenDeep : "#4D8D73"
                                font.pixelSize: 20
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: theme ? theme.textSecondary : "#6E8076"
                        font.pixelSize: 28
                    }
                }
            }
        }
    }
}
