import QtQuick
import "../../shared/I18n.js" as I18n
import "../components/PlatformCursor.js" as Cursor

// 便签截止日期/时间选择器（点开的小日历 + 24h 时:分）。自绘月历网格，不依赖 labs 日历模块，
// 主题与备忘暗色 chrome 一致。打开时定位到 initialMs（0=当前）。选定→dueSelected(ms)；清除→dueCleared()。
// 由 MemoOverlay 单例挂载、居中弹出；点遮罩外部关闭。详见 .harness/rules/04-ui-conventions.md §8。
Item {
    id: dp

    property MemoryLakeStyle style
    property string languageMode: "zh"
    property bool open: false
    property double initialMs: 0
    signal dueSelected(double ms)
    signal dueCleared()
    signal dismissed()

    anchors.fill: parent
    visible: open
    z: 4000

    // 展示中的年/月 + 选中的日/时/分
    property int _y: 2026
    property int _m: 0
    property int _d: 1
    property int _hh: 18
    property int _mm: 0

    function _initFrom(ms) {
        var dt = (ms && ms > 0) ? new Date(ms) : new Date();
        _y = dt.getFullYear(); _m = dt.getMonth(); _d = dt.getDate();
        if (ms && ms > 0) { _hh = dt.getHours(); _mm = dt.getMinutes(); }
        else { _hh = 18; _mm = 0; }
    }
    onOpenChanged: if (open) _initFrom(initialMs)
    onInitialMsChanged: if (open) _initFrom(initialMs)   // 与 open 赋值顺序无关

    function _daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
    function _firstWeekday(y, m) { return (new Date(y, m, 1).getDay() + 6) % 7; }   // 周一首列
    function _prevMonth() { if (_m === 0) { _m = 11; _y -= 1; } else _m -= 1; }
    function _nextMonth() { if (_m === 11) { _m = 0; _y += 1; } else _m += 1; }
    function _two(n) { return (n < 10 ? "0" : "") + n; }
    function _commit() { dp.dueSelected(new Date(_y, _m, _d, _hh, _mm, 0, 0).getTime()); }
    function _monthLabel() {
        if (I18n.langKey(languageMode) === "en") {
            var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            return months[_m] + " " + _y
        }
        return I18n.yearMonth(languageMode, new Date(_y, _m, 1))
    }
    function _weekLabels() {
        return I18n.weekdaysNarrow(languageMode)
    }

    readonly property color _ink: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.92)
    readonly property color _muted: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.5)
    readonly property color _aqua: dp.style ? dp.style.glowCyan : "#8EDFFF"
    readonly property color _violet: dp.style ? dp.style.violet : "#9B8BFF"

    // 24h 时:分 步进框（可键入 / 点 +-）。
    component TimeBox: Rectangle {
        id: tb
        property int from: 0
        property int to: 59
        property int value: 0
        signal valueModified(int v)
        function _clamp(v) { return Math.max(from, Math.min(to, (isNaN(v) ? from : v))); }
        function _commitVal(v) { var c = _clamp(v); tb.valueModified(c); inp.text = dp._two(c); }
        width: 64; height: 32; radius: 9
        color: Qt.rgba(1, 1, 1, 0.055)
        border.width: 1
        border.color: inp.activeFocus ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.45)
                                      : Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.12)
        onValueChanged: if (!inp.activeFocus) inp.text = dp._two(tb.value)
        TextInput {
            id: inp
            anchors { left: parent.left; right: tbCol.left; top: parent.top; bottom: parent.bottom; leftMargin: 8 }
            color: dp._ink; horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
            font.pixelSize: 14; selectByMouse: true; inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: tb.from; top: tb.to }
            Component.onCompleted: text = dp._two(tb.value)
            onEditingFinished: tb._commitVal(parseInt(inp.text))
        }
        Column {
            id: tbCol
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 3; topMargin: 2; bottomMargin: 2 }
            width: 16; spacing: 2
            Rectangle {
                width: 16; height: (parent.height - 2) / 2; radius: 5
                color: upMa.pressed ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.22)
                      : upMa.containsMouse ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                Text { anchors.centerIn: parent; text: "+"; color: dp._ink; font.pixelSize: 11 }
                MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Cursor.button(); onClicked: tb._commitVal(tb.value + 1) }
            }
            Rectangle {
                width: 16; height: (parent.height - 2) / 2; radius: 5
                color: dnMa.pressed ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.22)
                      : dnMa.containsMouse ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                Text { anchors.centerIn: parent; text: "−"; color: dp._ink; font.pixelSize: 11 }
                MouseArea { id: dnMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Cursor.button(); onClicked: tb._commitVal(tb.value - 1) }
            }
        }
    }

    // 遮罩：点外部关闭。
    MouseArea { anchors.fill: parent; onClicked: dp.dismissed() }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.28) }

    Rectangle {
        id: card
        width: 312
        anchors.centerIn: parent
        height: col.implicitHeight + 28
        radius: 16
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(31 / 255, 36 / 255, 48 / 255, 0.98) }
            GradientStop { position: 1; color: Qt.rgba(14 / 255, 18 / 255, 28 / 255, 0.98) }
        }
        border.width: 1
        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.18)
        antialiasing: true
        MouseArea { anchors.fill: parent }   // 吞卡内点击，避免穿到遮罩

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: 14; rightMargin: 14; topMargin: 14 }
            spacing: 10

            // ‹ 年月 ›
            Item {
                width: parent.width; height: 28
                Rectangle {
                    width: 28; height: 28; radius: 8; anchors.left: parent.left
                    color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    Text { anchors.centerIn: parent; text: "‹"; color: dp._ink; font.pixelSize: 18 }
                    MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Cursor.button(); onClicked: dp._prevMonth() }
                }
                Text {
                    anchors.centerIn: parent
                    text: dp._monthLabel()
                    color: dp._ink; font.pixelSize: 15; font.weight: Font.DemiBold
                }
                Rectangle {
                    width: 28; height: 28; radius: 8; anchors.right: parent.right
                    color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    Text { anchors.centerIn: parent; text: "›"; color: dp._ink; font.pixelSize: 18 }
                    MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Cursor.button(); onClicked: dp._nextMonth() }
                }
            }

            // 周标题。
            Row {
                width: parent.width
                Repeater {
                    model: dp._weekLabels()
                    delegate: Text {
                        required property string modelData
                        width: col.width / 7; horizontalAlignment: Text.AlignHCenter
                        text: modelData; color: dp._muted; font.pixelSize: 11
                    }
                }
            }

            // 日网格 6x7。
            Grid {
                width: parent.width; columns: 7
                Repeater {
                    model: 42
                    delegate: Item {
                        id: cell
                        required property int index
                        width: col.width / 7; height: 30
                        readonly property int dayNum: cell.index - dp._firstWeekday(dp._y, dp._m) + 1
                        readonly property bool valid: dayNum >= 1 && dayNum <= dp._daysInMonth(dp._y, dp._m)
                        readonly property bool sel: valid && dayNum === dp._d
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28; height: 26; radius: 8
                            visible: cell.valid
                            color: cell.sel ? dp._aqua
                                  : (dayMa.containsMouse ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.12) : "transparent")
                            Text {
                                anchors.centerIn: parent
                                text: cell.valid ? cell.dayNum : ""
                                color: cell.sel ? Qt.rgba(4 / 255, 8 / 255, 14 / 255, 0.95) : dp._ink
                                font.pixelSize: 13; font.weight: cell.sel ? Font.Bold : Font.Normal
                            }
                            MouseArea {
                                id: dayMa; anchors.fill: parent; enabled: cell.valid
                                hoverEnabled: true; cursorShape: Cursor.button()
                                onClicked: dp._d = cell.dayNum
                            }
                        }
                    }
                }
            }

            // 时间 时:分（24h）。
            Row {
                width: parent.width; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t(dp.languageMode, "Time"); color: dp._muted; font.pixelSize: 12 }
                TimeBox { from: 0; to: 23; value: dp._hh; onValueModified: (v) => dp._hh = v }
                Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; color: dp._ink; font.pixelSize: 16 }
                TimeBox { from: 0; to: 59; value: dp._mm; onValueModified: (v) => dp._mm = v }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "24h"; color: dp._muted; font.pixelSize: 11 }
            }

            // 清除 / 确定。
            Item {
                width: parent.width; height: 36
                Rectangle {
                    width: 72; height: 34; radius: 10; anchors.left: parent.left
                    color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
                    Text { anchors.centerIn: parent; text: I18n.t(dp.languageMode, "Clear"); color: dp._ink; font.pixelSize: 14 }
                    MouseArea { id: clearMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Cursor.button(); onClicked: dp.dueCleared() }
                }
                Rectangle {
                    width: 96; height: 34; radius: 10; anchors.right: parent.right
                    gradient: Gradient {
                        GradientStop { position: 0; color: dp._aqua }
                        GradientStop { position: 1; color: dp._violet }
                    }
                    Text { anchors.centerIn: parent; text: I18n.t(dp.languageMode, "OK")
                           color: Qt.rgba(4 / 255, 8 / 255, 14 / 255, 0.94); font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Cursor.button(); onClicked: dp._commit() }
                }
            }
        }
    }
}
