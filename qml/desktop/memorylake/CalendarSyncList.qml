import QtQuick
import "../../shared/I18n.js" as I18n

// Calendar Sync：今日事项（与日历页同步，读 calendarManager.savedTodos 的今天 key）。
// v88 复刻（设计稿 .today-items-compact）：玻璃底 + 左上 aqua 径向底光 + 右上**蓝色霓虹照射** +
// 24px「笔记本方格」底纹 + 右上角霓虹点；事项行为 v88 圆角行（霜底 + 发丝边 + 渐变勾选框）。
// 只读展示 + 「日历」跳转按钮；不在此编辑，编辑仍在日历页。
Rectangle {
    id: panel

    property MemoryLakeStyle style
    property string languageMode: "zh"
    signal openCalendar()

    readonly property real gs: style ? style.glowStrength : 1.0

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

    function cloneTodo(todo) {
        var out = {};
        for (var key in todo)
            out[key] = todo[key];
        return out;
    }

    function toggleDoneAt(index) {
        if (!calendarManager || !calendarManager.savedTodos
                || calendarManager.savedTodos === "")
            return;
        try {
            var map = JSON.parse(calendarManager.savedTodos);
            var arr = map[todayKey];
            if (!arr || index < 0 || index >= arr.length)
                return;
            var next = [];
            for (var i = 0; i < arr.length; i++)
                next.push(cloneTodo(arr[i]));
            next[index].done = !(next[index].done === true);
            map[todayKey] = next;
            calendarManager.setSavedTodos(JSON.stringify(map));
        } catch (e) {}
    }

    function displayTime(raw) {
        if (!raw || raw === "")
            return "--:--";
        var parts = raw.split(":");
        if (parts.length < 2)
            return raw;
        var h = parseInt(parts[0]);
        var m = parseInt(parts[1]);
        if (isNaN(h) || isNaN(m))
            return raw;
        var fmt = settingsRepository ? settingsRepository.getValue("time_format", "24") : "24";
        return fmt === "12" ? Qt.formatTime(new Date(2000, 0, 1, h, m), "h:mm AP") : raw;
    }

    Component.onCompleted: reload()
    Connections {
        target: calendarManager
        function onCalendarDataChanged() { panel.reload() }
    }

    radius: 22
    color: style ? (style.night ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.72)) : "#16181f"
    border.width: 1
    border.color: style ? (style.night ? Qt.rgba(1, 1, 1, 0.085) : Qt.rgba(0.40, 0.34, 0.28, 0.18)) : "#2a2d36"
    // 圆角裁切交给下方 RoundedFrame；clip:true 只裁矩形会让方格/底光在圆角处戳出方角「色块」。
    clip: false
    antialiasing: true

    // —— 圆角裁切的底光层（蓝色霓虹底光 + 笔记本方格 + 霓虹点）：round-clip 收在圆角内，杜绝角落方块。——
    RoundedFrame {
        anchors.fill: parent
        radius: panel.radius

        // 蓝色霓虹底光（设计稿 radial glowCyan「衬托照射」）：一团居上柔光，**居中均匀漫射**，不在角落扎块。
        GlowCircle {
            readonly property real d: panel.width * 1.15
            width: d; height: d
            x: panel.width * 0.5 - d / 2
            y: -d * 0.5
            glowColor: panel.style ? panel.style.glowCyan : "#8EDFFF"
            glowOpacity: 0.12 * panel.gs
        }

        // 24px「笔记本方格」底纹（设计稿 ::before grid；用户要求方格可见）。
        GridTexture {
            anchors.fill: parent
            lineColor: panel.style && !panel.style.night ? Qt.rgba(0.20, 0.26, 0.34, 0.06)
                                                          : Qt.rgba(1, 1, 1, 0.05)
            cell: 24
            textureOpacity: 0.6
        }

        // 右上角霓虹点（设计稿 ::after 6px glowCyan + 小柔晕）：小晕，收在圆角内。
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 16
            anchors.topMargin: 16
            width: 7; height: 7
            visible: panel.style ? panel.style.night : true
            GlowCircle {
                anchors.centerIn: parent
                width: 20; height: 20
                glowColor: panel.style ? panel.style.glowCyan : "#8EDFFF"
                glowOpacity: 0.32 * panel.gs
            }
            Rectangle {
                anchors.centerIn: parent
                width: 7; height: 7; radius: 3.5
                color: panel.style ? panel.style.glowCyan : "#8EDFFF"
            }
        }
    }

    // 顶沿内高光 + 更亮底沿（玻璃边缘光对）。左右内缩半径，不越圆角拐角。
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 1; leftMargin: panel.radius; rightMargin: panel.radius }
        height: 1
        color: panel.style ? (panel.style.night ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.55))
                           : Qt.rgba(1, 1, 1, 0.05)
    }
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                  bottomMargin: 1; leftMargin: panel.radius; rightMargin: panel.radius }
        height: 1
        color: panel.style ? panel.style.panelBorderStrong : Qt.rgba(1, 1, 1, 0.13)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // 标题行（v88 kicker / title / sub + 「日历」按钮）
        Item {
            width: parent.width
            height: 42
            Column {
                anchors.left: parent.left
                anchors.right: openBtn.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: "Calendar Sync"
                    color: panel.style ? panel.style.glowCyan : "#8EDFFF"
                    font.pixelSize: 11
                    font.weight: 800
                    font.letterSpacing: 0.55
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    text: I18n.t(panel.languageMode, "Today's Items")
                    color: panel.style ? panel.style.textPrimary : "#fff"
                    font.pixelSize: 18
                    font.weight: 800
                    font.letterSpacing: -0.35
                }
                Text {
                    text: I18n.t(panel.languageMode, "Today · Synced with Calendar")
                    color: panel.style ? panel.style.textTertiary : "#888"
                    font.pixelSize: 11
                }
            }
            Rectangle {
                id: openBtn
                anchors.right: parent.right
                anchors.top: parent.top
                width: 48
                height: 32
                radius: 12
                color: openHover.hovered
                    ? (panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.14) : Qt.rgba(0.56, 0.87, 1, 0.14))
                    : (panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.08) : Qt.rgba(0.56, 0.87, 1, 0.08))
                border.width: 1
                border.color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.16) : Qt.rgba(0.56, 0.87, 1, 0.16)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    anchors.centerIn: parent
                    text: I18n.t(panel.languageMode, "Calendar")
                    color: panel.style ? panel.style.accentText : "#9ef1ff"
                    font.pixelSize: 11
                    font.weight: 800
                }
                HoverHandler { id: openHover }
                TapHandler { onTapped: panel.openCalendar() }
            }
        }

        // 事项列表（v88 .todo-item：圆角行 + 渐变勾选框 + 划线完成态）
        Column {
            width: parent.width
            spacing: 8

            Repeater {
                model: panel.items
                delegate: Rectangle {
                    id: rowBg
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 50
                    radius: 15
                    color: rowHover.hovered
                        ? (panel.style ? Qt.rgba(1, 1, 1, panel.style.night ? 0.055 : 0.5) : "#ffffff0e")
                        : (panel.style ? (panel.style.night ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.5)) : "#00000028")
                    border.width: 1
                    border.color: panel.style ? (panel.style.night ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(0.40, 0.34, 0.28, 0.14)) : "#ffffff10"
                    Behavior on color { ColorAnimation { duration: 160 } }
                    transform: Translate { y: rowHover.hovered ? -1 : 0 }
                    HoverHandler { id: rowHover }

                    // v88 .todo-item 三栏：[勾选框 | 文案(标题+副标) | 时间]。
                    // 勾选框（左）：未完成 = 发丝边空框（白 .06 底）；完成 = 135° aqua→violet 渐变 + ✓。
                    Rectangle {
                        id: check
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 8
                        color: panel.style ? Qt.rgba(1, 1, 1, 0.06) : "#ffffff10"
                        border.width: rowBg.modelData.done ? 0 : 1
                        border.color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.22) : Qt.rgba(0.56, 0.87, 1, 0.22)
                        gradient: rowBg.modelData.done ? doneGrad : null
                        Gradient {
                            id: doneGrad
                            GradientStop { position: 0; color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.86) : Qt.rgba(0.56, 0.87, 1, 0.86) }
                            GradientStop { position: 1; color: panel.style ? Qt.rgba(panel.style.violet.r, panel.style.violet.g, panel.style.violet.b, 0.82) : Qt.rgba(0.61, 0.55, 1, 0.82) }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: rowBg.modelData.done
                            text: "✓"
                            color: Qt.rgba(0.016, 0.031, 0.055, 0.92)
                            font.pixelSize: 13
                            font.weight: 900
                        }
                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: panel.toggleDoneAt(rowBg.index)
                        }
                    }

                    // 时间（右，aqua；无则 --:--，对齐 v88 .todo-time）
                    Text {
                        id: rowTime
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: displayTime(rowBg.modelData.time)
                        color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.78) : Qt.rgba(0.62, 0.90, 0.93, 0.78)
                        font.pixelSize: 10
                        font.weight: 760
                    }

                    // 文案（中，填满 check↔time）：标题 + 副标(tag，对齐 v88 .todo-copy small)
                    Column {
                        anchors.left: check.right
                        anchors.right: rowTime.left
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            width: parent.width
                            text: rowBg.modelData.text
                            color: rowBg.modelData.done
                                ? (panel.style ? panel.style.textTertiary : "#999")
                                : (panel.style ? panel.style.textPrimary : "#fff")
                            font.pixelSize: 12
                            font.weight: 700
                            font.strikeout: rowBg.modelData.done
                            elide: Text.ElideRight
                        }
                        TagChip {
                            tag: rowBg.modelData.tag ? rowBg.modelData.tag : "Other"
                            style: panel.style
                            languageMode: panel.languageMode
                        }
                    }
                }
            }

            Text {
                visible: panel.items.length === 0
                width: parent.width
                    text: I18n.t(panel.languageMode, "No items today · Add them in Calendar")
                color: panel.style ? panel.style.textTertiary : "#888"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }
}
