import QtQuick

// Calendar Sync：今日事项（与日历页同步，读 calendarManager.savedTodos 的今天 key）。
// 只读展示 + 「日历」跳转按钮；不在此编辑，编辑仍在日历页。
Rectangle {
    id: panel

    property MemoryLakeStyle style
    signal openCalendar()

    function pad2(n) { return (n < 10 ? "0" : "") + n }
    readonly property string todayKey: {
        var d = new Date();
        return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
    }

    property var items: []
    readonly property int remaining: {
        var n = 0;
        for (var i = 0; i < items.length; i++)
            if (!items[i].done) n++;
        return n;
    }

    function reload() {
        var out = [];
        if (calendarManager && calendarManager.savedTodos
                && calendarManager.savedTodos !== "") {
            try {
                var map = JSON.parse(calendarManager.savedTodos);
                var arr = map[todayKey];
                if (arr)
                    for (var i = 0; i < arr.length; i++) out.push(arr[i]);
            } catch (e) {}
        }
        items = out;
    }

    Component.onCompleted: reload()
    Connections {
        target: calendarManager
        function onCalendarDataChanged() { panel.reload() }
    }

    radius: style ? style.radiusCard : 18
    color: style ? style.cardBg : "#16181f"
    border.width: 1
    border.color: style ? style.cardBorder : "#2a2d36"
    clip: true

    // 边缘光对（R4/L4）：顶沿内高光 + 更亮底沿，静止无投影。左右内缩半径，不越出圆角拐角。
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 1; leftMargin: panel.radius; rightMargin: panel.radius }
        height: 1
        color: panel.style ? (panel.style.night ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(1, 1, 1, 0.55))
                           : Qt.rgba(1, 1, 1, 0.035)
    }
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                  bottomMargin: 1; leftMargin: panel.radius; rightMargin: panel.radius }
        height: 1
        color: panel.style ? panel.style.panelBorderStrong : Qt.rgba(1, 1, 1, 0.13)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // 标题行
        Item {
            width: parent.width
            height: 40
            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: "Calendar Sync"
                    color: style ? style.aqua : "#9FE7EE"
                    font.pixelSize: 11
                    opacity: 0.85
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.0
                }
                Text {
                    text: "今日事项"
                    color: style ? style.textPrimary : "#fff"
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    text: "今天 · 与日历同步"
                    color: style ? style.textTertiary : "#888"
                    font.pixelSize: 10
                }
            }
            Rectangle {
                id: openBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 28
                radius: 14
                color: openHover.hovered ? (style ? style.accentSoft : "#22303a")
                                         : "transparent"
                border.width: 1
                border.color: style ? style.accentSoftBorder : "#33505c"
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    anchors.centerIn: parent
                    text: "日历"
                    color: style ? style.accentText : "#9ef1ff"
                    font.pixelSize: 12
                    font.bold: true
                }
                HoverHandler { id: openHover }
                TapHandler { onTapped: panel.openCalendar() }
            }
        }

        // 事项列表
        Column {
            width: parent.width
            spacing: 8

            Repeater {
                model: panel.items
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 10
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.done ? (style ? style.aqua : "#9FE7EE")
                                              : "transparent"
                        border.width: 1
                        border.color: modelData.done
                                      ? (style ? style.aqua : "#9FE7EE")
                                      : (style ? style.cardBorder : "#444")
                        Text {
                            anchors.centerIn: parent
                            visible: modelData.done
                            text: "✓"
                            color: style && style.night ? "#05070D" : "#fff"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                    Text {
                        width: parent.width - 18 - 10
                        text: modelData.text
                        color: modelData.done ? (style ? style.textTertiary : "#888")
                                             : (style ? style.textPrimary : "#fff")
                        font.pixelSize: 13
                        font.strikeout: modelData.done
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Text {
                visible: panel.items.length === 0
                width: parent.width
                text: "今天还没有事项 · 去日历添加"
                color: style ? style.textTertiary : "#888"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }
}
