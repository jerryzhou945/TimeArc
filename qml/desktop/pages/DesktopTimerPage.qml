import QtQuick
import QtQuick.Controls

Item {
    anchors.fill: parent

    // =========================
    // 从 AppShell 传入的主题参数
    // 如果没传，就先用白天默认值
    // =========================
    property bool nightMode: false
    property color themeTextPrimary: "#4E342E"
    property color themeTextSecondary: "#9C806C"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#DDC9B5"
    property color themeAccentColor: "#E8C6A3"

    // =========================
    // 页面内部颜色
    // 白天：米色暖棕
    // 夜晚：淡蓝紫、雾感灰紫
    // =========================
    property color timerPanelColor: nightMode ? "#50577A" : "#FFF7EF"
    property color timerInnerCardColor: nightMode ? "#5A628B" : "#FFFDF9"
    property color timerBorderColor: themeBorderColor

    property color titleColor: themeTextSecondary
    property color projectColor: themeTextPrimary
    property color timeColor: nightMode ? "#EEF0FF" : "#6A4C3B"
    property color statusColor: themeTextSecondary

    property color pauseButtonColor: nightMode ? "#6770A8" : "#EBD9C7"
    property color pauseButtonBorder: nightMode ? "#7C86C8" : "#D8B99A"
    property color pauseButtonText: nightMode ? "#F8F7FF" : "#6A4C3B"

    property color stopButtonColor: nightMode ? "#8E93D8" : "#DDB892"
    property color stopButtonBorder: nightMode ? "#757ED0" : "#CDA57D"
    property color stopButtonText: "#FFFDF9"

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

    // =========================
    // 外层大面板
    // =========================
    Rectangle {
        anchors.fill: parent
        radius: 28
        color: timerPanelColor
        border.width: 2
        border.color: timerBorderColor
        opacity: nightMode ? 0.72 : 1.0
    }

    // 轻微高光层，让夜晚模式有一点玻璃感
    Rectangle {
        anchors.fill: parent
        radius: 28
        color: "#FFFFFF"
        opacity: nightMode ? 0.04 : 0.00
    }

    Column {
        anchors.centerIn: parent
        spacing: 22

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "正在计时"
            color: titleColor
            font.pixelSize: 18
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: timerManager ? timerManager.currentProject : "未选择项目"
            color: projectColor
            font.pixelSize: 30
            font.bold: true
        }

        Rectangle {
            width: 520
            height: 210
            radius: 26
            color: timerInnerCardColor
            border.width: 1
            border.color: nightMode ? "#7A82B0" : "#E6D6C5"
            opacity: nightMode ? 0.76 : 0.88

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 25
                color: "#FFFFFF"
                opacity: nightMode ? 0.04 : 0.08
                z: -1
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: timerManager ? formatTime(timerManager.elapsedSeconds) : "00:00:00"
                    color: timeColor
                    font.pixelSize: 84
                    font.family: "Segoe UI"
                    font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: timerManager
                          ? (timerManager.running ? "正在计时中" : "已暂停")
                          : "计时器未连接"
                    color: statusColor
                    font.pixelSize: 16
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Rectangle {
                width: 128
                height: 54
                radius: 20
                color: pauseButtonColor
                border.width: 1
                border.color: pauseButtonBorder

                Text {
                    anchors.centerIn: parent
                    text: timerManager && timerManager.running ? "暂停" : "继续"
                    color: pauseButtonText
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
                color: stopButtonColor
                border.width: 1
                border.color: stopButtonBorder

                Text {
                    anchors.centerIn: parent
                    text: "结束"
                    color: stopButtonText
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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: nightMode
                  ? "结束后会自动返回首页，并把这段夜晚时光累计到项目中。"
                  : "结束后会自动返回首页，并把本次时长累计到项目中。"
            color: statusColor
            font.pixelSize: 14
        }
    }

    Component.onCompleted: {
        console.log("DesktopTimerPage loaded")
    }
}
