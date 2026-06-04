import QtQuick
import QtQuick.Controls

// 番茄钟浮窗（v88 .pomodoro-widget）。计时状态机 idle→running(收缩成像素番茄)→paused(展开)→
// complete(展开+弹层)；1Hz；分[1,180]/秒[0,59]；横向填充进度条（非环形，对齐 v88）。
// 开始约 180ms 收缩成番茄；点番茄=暂停+展开。运行态描边辉光脉冲。可拖动并钳制在覆盖层内。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §1.6 / 功能文 §2.7。
Item {
    id: pomo

    property MemoryLakeStyle style
    property bool shown: false
    property int total: 25 * 60
    property int remain: 25 * 60
    property bool running: false
    property bool compact: false
    property string title: "专注一会儿"

    signal completed(string variant)

    width: compact ? 104 : 278
    height: compact ? 116 : bodyCol.implicitHeight + 28
    x: 200
    y: 96
    visible: shown && opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.Bezier
        easing.bezierCurve: pomo.style ? pomo.style.easeSnappy : [0.18, 0.9, 0.2, 1, 1, 1] } }
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.Bezier
        easing.bezierCurve: pomo.style ? pomo.style.easeSnappy : [0.18, 0.9, 0.2, 1, 1, 1] } }

    readonly property int mm: Math.floor(remain / 60)
    readonly property int ss: remain % 60
    function _two(n) { return (n < 10 ? "0" : "") + n; }
    readonly property string timeText: _two(mm) + ":" + _two(ss)
    readonly property real progress: total > 0 ? (1 - remain / total) : 0

    function _clampMin(v) { return Math.max(1, Math.min(180, v)); }
    function _clampSec(v) { return Math.max(0, Math.min(59, v)); }
    function startTimer() { if (running) return; if (remain <= 0) remain = total; running = true; }
    function pauseTimer() { running = false; }
    function resetTimer() { running = false; compact = false; remain = total; }
    function setMinutes(m) { var s = remain % 60; total = _clampMin(m) * 60 + (running ? 0 : _clampSec(s)); if (!running) remain = total; }
    function setSeconds(s) { var mnt = Math.floor((running ? total : remain) / 60); total = mnt * 60 + _clampSec(s); if (!running) remain = total; }
    function _pickVariant() {
        var v = ["FOCUS COMPLETE", "GOOD SESSION", "MEMORY SAVED", "WELL DONE"];
        return v[Math.floor(Math.random() * v.length)];
    }

    Timer {
        interval: 1000; repeat: true; running: pomo.running
        onTriggered: {
            pomo.remain = Math.max(0, pomo.remain - 1);
            if (pomo.remain === 0) {
                pomo.running = false;
                pomo.compact = false;
                pomo.completed(pomo._pickVariant());   // 单一探测器（功能文 G7/C13）
            }
        }
    }
    // 开始后约 180ms 收缩成番茄（功能文 §2.7）。
    Timer { id: collapseT; interval: 180; onTriggered: if (pomo.running) pomo.compact = true; }
    onRunningChanged: { if (running) collapseT.restart(); else if (remain > 0) compact = false; }

    // ===== 玻璃卡（展开态主体 / 紧凑态外壳）=====
    Rectangle {
        id: card
        anchors.fill: parent
        radius: pomo.compact ? 22 : 20
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(31 / 255, 36 / 255, 48 / 255, 0.94) }
            GradientStop { position: 1; color: Qt.rgba(14 / 255, 18 / 255, 28 / 255, 0.92) }
        }
        border.width: 1
        border.color: pomo.running ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.34)
                                    : Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.14)
        antialiasing: true

        // 运行态描边辉光脉冲（6 套 keyframe 的代表：aura/呼吸）。
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.5)
            visible: pomo.running
            opacity: 0.0
            SequentialAnimation on opacity {
                running: pomo.running
                loops: Animation.Infinite
                NumberAnimation { from: 0.0; to: 0.5; duration: 1400; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.5; to: 0.0; duration: 1400; easing.type: Easing.InOutQuad }
            }
        }

        // 顶沿 1px 内高光。
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right
                      topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
            height: 1; color: Qt.rgba(1, 1, 1, 0.08)
        }

        // 拖动（拖空白处移动；钳制在父覆盖层内）。
        DragHandler {
            target: pomo
            xAxis.minimum: 8
            xAxis.maximum: (pomo.parent ? pomo.parent.width : pomo.width) - pomo.width - 8
            yAxis.minimum: 72
            yAxis.maximum: (pomo.parent ? pomo.parent.height : pomo.height) - pomo.height - 8
        }

        // ===== 紧凑态：像素番茄 + 小时间 =====
        Column {
            id: compactCol
            anchors.centerIn: parent
            visible: pomo.compact
            spacing: 4
            PixelTomato {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64
                style: pomo.style
                // 待机轻微抖动（待机 tech-wiggle 近似）。
                SequentialAnimation on rotation {
                    running: pomo.compact && pomo.running
                    loops: Animation.Infinite
                    NumberAnimation { from: -2; to: 2; duration: 550 }
                    NumberAnimation { from: 2; to: -2; duration: 550 }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pomo.timeText
                color: Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.94)
                font.pixelSize: 16; font.weight: Font.DemiBold
            }
        }
        // 点番茄=暂停+展开（独立命中层，不放进 Column）。
        MouseArea {
            anchors.fill: parent
            visible: pomo.compact
            enabled: pomo.compact
            cursorShape: Qt.PointingHandCursor
            onClicked: { pomo.pauseTimer(); pomo.compact = false; }
        }

        // ===== 展开态主体 =====
        Column {
            id: bodyCol
            visible: !pomo.compact
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: 16; rightMargin: 16; topMargin: 14 }
            spacing: 10

            Text {
                width: parent.width
                text: pomo.title
                color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.62)
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pomo.timeText
                color: Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.96)
                font.pixelSize: 40
                font.weight: Font.Bold
                font.letterSpacing: pomo.running ? 2 : 0
                Behavior on font.letterSpacing { NumberAnimation { duration: 500 } }
            }
            // 横向进度条（#9FE7EE→#9B8BFF）。
            Rectangle {
                width: parent.width; height: 8; radius: 4
                color: Qt.rgba(1, 1, 1, 0.06)
                Rectangle {
                    width: parent.width * pomo.progress; height: parent.height; radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: pomo.style ? pomo.style.aqua : "#9FE7EE" }
                        GradientStop { position: 1; color: pomo.style ? pomo.style.violet : "#9B8BFF" }
                    }
                    Behavior on width { NumberAnimation { duration: 220 } }
                }
            }
            // 分/秒输入（仅未运行时可改）。
            Row {
                spacing: 8
                visible: !pomo.running
                anchors.horizontalCenter: parent.horizontalCenter
                Row {
                    spacing: 4
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "分"
                           color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.55); font.pixelSize: 12 }
                    SpinBox {
                        id: minBox
                        from: 1; to: 180; value: Math.floor(pomo.total / 60)
                        onValueModified: pomo.setMinutes(value)
                        implicitWidth: 92
                    }
                }
                Row {
                    spacing: 4
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "秒"
                           color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.55); font.pixelSize: 12 }
                    SpinBox {
                        id: secBox
                        from: 0; to: 59; value: pomo.total % 60
                        onValueModified: pomo.setSeconds(value)
                        implicitWidth: 92
                    }
                }
            }
            // 控制按钮。
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                bottomPadding: 4
                Rectangle {
                    width: 96; height: 34; radius: 10
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.94) }
                        GradientStop { position: 1; color: Qt.rgba(155 / 255, 139 / 255, 255 / 255, 0.92) }
                    }
                    Text { anchors.centerIn: parent; text: pomo.running ? "进行中" : "开始"
                           color: Qt.rgba(4 / 255, 8 / 255, 14 / 255, 0.94); font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: pomo.running ? pomo.pauseTimer() : pomo.startTimer()
                    }
                }
                Rectangle {
                    width: 72; height: 34; radius: 10
                    color: resetH.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
                    Text { anchors.centerIn: parent; text: "重置"
                           color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.82); font.pixelSize: 14 }
                    MouseArea { id: resetH; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: pomo.resetTimer() }
                }
            }
        }
    }
}
