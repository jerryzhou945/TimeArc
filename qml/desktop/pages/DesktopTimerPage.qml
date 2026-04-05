import QtQuick
import QtQuick.Controls

Item {
    anchors.fill: parent

    function formatTime(totalSeconds) {
        var t = totalSeconds
        if (t === undefined || t === null)
            t = 0

        var h = Math.floor(t / 3600)
        var m = Math.floor((t % 3600) / 60)
        var s = t % 60

        function pad(n) {
            var text = n.toString()
            if (text.length < 2)
                text = "0" + text
            return text
        }

        return pad(h) + ":" + pad(m) + ":" + pad(s)
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: "#FFF7EF"
        border.width: 2
        border.color: "#D8C2AC"
    }

    Column {
        anchors.centerIn: parent
        spacing: 22

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "正在计时"
            color: "#8A654C"
            font.pixelSize: 18
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: timerManager ? timerManager.currentProject : "未选择项目"
            color: "#5B4031"
            font.pixelSize: 30
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: timerManager ? formatTime(timerManager.elapsedSeconds) : "00:00:00"
            color: "#6A4C3B"
            font.pixelSize: 84
            font.family: "Segoe UI"
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: timerManager
                  ? (timerManager.running ? "正在计时中" : "已暂停")
                  : "计时器未连接"
            color: "#9C806C"
            font.pixelSize: 16
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Rectangle {
                width: 128
                height: 54
                radius: 20
                color: "#EBD9C7"
                border.width: 1
                border.color: "#D8B99A"

                Text {
                    anchors.centerIn: parent
                    text: timerManager && timerManager.running ? "暂停" : "继续"
                    color: "#6A4C3B"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!timerManager)
                            return

                        if (timerManager.running)
                            timerManager.pauseTimer()
                        else
                            timerManager.resumeTimer()
                    }
                }
            }

            Rectangle {
                width: 128
                height: 54
                radius: 20
                color: "#DDB892"
                border.width: 1
                border.color: "#CDA57D"

                Text {
                    anchors.centerIn: parent
                    text: "结束"
                    color: "#FFFDF9"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (timerManager)
                            timerManager.stopAndCommit()
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("DesktopTimerPage loaded")
    }
}
