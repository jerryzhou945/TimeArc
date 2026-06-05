import QtQuick
import QtQuick.Controls

// 便签（v88 .sticky-note）。扁平暖黄纸 #FFE6A3 + 接触软阴影；隐藏拖拽 header（hover/选中升起）；
// 标题 + 正文可编辑；4 把手缩放（左/右/下/右下角，**无上把手**，高度只向下长、顶边钉死）；
// autosize（>110 字 或 面积<72000 → 紧凑字号）；aqua 选中环；键盘删除（编辑字段时不劫持）。
// 拖动钳制 top≥84（让位工具条/档案袋）。位置/尺寸/内容变更回写 model（持久化切片接）。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §1.3 / 功能文 §2.4。
Item {
    id: note

    property MemoryLakeStyle style
    property bool selected: false
    property bool editing: false          // 正在编辑标题/正文 → 守卫键盘删除
    property string title: ""
    property string content: ""
    property bool done: false             // 待办完成态（左上打勾），供后续日历待做事项消费
    property double createdMs: 0          // 创建时间戳（epoch ms），0 = 旧便签无时间
    property double due: 0                 // 用户自选截止日期/时间（epoch ms），0 = 未设

    signal selectRequested(bool grabFocus)   // grabFocus=true（header/缩放）→ 让覆盖层接管键盘删除
    signal geometryCommitted()
    signal contentCommitted()
    signal deleteRequested()
    signal doneToggled()                  // 勾选/取消勾选 → 覆盖层回写 odone
    signal dueEditRequested()             // 点截止行 → 覆盖层弹出日期选择器

    z: 124
    width: 310
    height: 285

    readonly property real minW: 210
    readonly property real minH: 190
    readonly property real maxW: Math.min(520, parent ? parent.width - 40 : 520)
    readonly property real maxH: Math.min(620, parent ? parent.height - 120 : 620)
    readonly property bool compact: (title.length + content.length) > 110
                                    || (width * height) < 72000

    // 接触软阴影（::before 近似：低 alpha 实色块，左右内缩 16、下探 9）。
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: -9
        color: Qt.rgba(0, 0, 0, 0.22)
    }

    Rectangle {
        id: paper
        anchors.fill: parent
        color: note.style ? note.style.stickyPaper : "#FFE6A3"
        antialiasing: true
        border.width: note.selected ? 2 : 0
        border.color: note.style ? note.style.memoSelectRing : Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.58)

        Column {
            anchors.fill: parent

            // 拖拽 header（默认透明，hover/选中升到 .22）。
            Rectangle {
                id: header
                width: parent.width
                height: 36
                color: Qt.rgba(0, 0, 0, (note.selected || headerMouse.containsMouse) ? 0.22 : 0.0)
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: headerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeAllCursor
                    drag.target: note
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 8
                    drag.maximumX: (note.parent ? note.parent.width : note.width) - note.width - 8
                    drag.minimumY: 8        // 顶栏改为灵动岛自动隐藏，顶部空间开放可拖
                    drag.maximumY: (note.parent ? note.parent.height : note.height) - note.height - 8
                    onPressed: note.selectRequested(true)
                    onReleased: note.geometryCommitted()
                }
            }

            // 标题
            TextField {
                id: titleField
                width: parent.width
                leftPadding: 16; rightPadding: 16; topPadding: 6
                background: null
                text: note.title
                placeholderText: "标题"
                color: note.style ? note.style.stickyInk : "#1E1E1E"
                placeholderTextColor: Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.4)
                font.pixelSize: note.compact ? 19 : 24
                font.weight: Font.ExtraBold
                font.strikeout: note.done       // 完成态：标题划线
                onActiveFocusChanged: { note.editing = activeFocus; if (activeFocus) note.selectRequested(false) }
                onTextChanged: note.title = text
                onEditingFinished: note.contentCommitted()
            }

            // 正文
            ScrollView {
                width: parent.width
                height: parent.height - header.height - titleField.height - dateRow.height
                clip: true
                TextArea {
                    id: bodyArea
                    text: note.content
                    leftPadding: 16; rightPadding: 16
                    background: null
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    color: note.done ? Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.45)
                                     : (note.style ? note.style.stickyInk : "#1E1E1E")
                    placeholderText: "写点什么…"
                    placeholderTextColor: Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.4)
                    font.pixelSize: note.compact ? 15 : 18
                    onActiveFocusChanged: { note.editing = activeFocus; if (activeFocus) note.selectRequested(false) }
                    onTextChanged: note.content = text
                    onEditingFinished: note.contentCommitted()
                }
            }

            // 截止日期与时间（点开小日历自选；供日历 / 首页今日事项后续同步）。
            Text {
                id: dateRow
                width: parent.width
                leftPadding: 16; rightPadding: 16; bottomPadding: 10
                text: note.due > 0
                      ? "截止 " + Qt.formatDateTime(new Date(note.due), "yyyy-MM-dd  HH:mm")
                      : "＋ 设置截止时间"
                color: note.due > 0 ? Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.66)
                                    : Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.42)
                font.pixelSize: 12
                font.underline: dateMa.containsMouse
                horizontalAlignment: Text.AlignLeft
                MouseArea {
                    id: dateMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { note.selectRequested(true); note.dueEditRequested(); }
                }
            }
        }

        // 完成打勾（左上角；始终可见，点击切换完成态）。完成 → 标题划线 + 正文淡化 + 绿勾。
        Rectangle {
            id: doneBox
            width: 22; height: 22; radius: 6
            anchors { top: parent.top; left: parent.left; topMargin: 7; leftMargin: 7 }
            color: note.done ? (note.style ? note.style.pomodoroLeaf : "#5FBF6B")
                             : Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.10)
            border.width: 1.5
            border.color: note.done ? (note.style ? note.style.pomodoroLeafDark : "#3E8F4E")
                                    : Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.42)
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "✓"; visible: note.done
                color: "#FFFFFF"; font.pixelSize: 15; font.weight: Font.Bold
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { note.done = !note.done; note.selectRequested(true); note.doneToggled(); }
            }
        }

        // 可见 × 删除（选中时显示；统一删除入口，配合键盘 Del/Backspace，功能文 §2.4【应当】）。
        Rectangle {
            visible: note.selected
            width: 22; height: 22; radius: 11
            anchors { top: parent.top; right: parent.right; topMargin: 7; rightMargin: 7 }
            color: delMouse.containsMouse ? Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.85)
                                          : Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.55)
            Text { anchors.centerIn: parent; text: "×"; color: "#FFFFFF"; font.pixelSize: 15 }
            MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: note.deleteRequested()
            }
        }
    }

    // ===== 缩放把手：左 / 右 / 下 / 右下角（无上）=====
    // 公共：按下记起始几何 + 起始指针（父坐标），移动按 delta 改几何并钳制。
    QtObject {
        id: rs
        property real sx; property real sy; property real sw; property real sh
        property real px; property real py
    }
    function _begin(ma, mx, my) {
        var p = ma.mapToItem(note.parent, mx, my);
        rs.sx = note.x; rs.sy = note.y; rs.sw = note.width; rs.sh = note.height;
        rs.px = p.x; rs.py = p.y;
        note.selectRequested(true);
    }
    function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

    // 右
    MouseArea {
        width: 12; anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 36 }
        cursorShape: Qt.SizeHorCursor
        onPressed: function (m) { note._begin(this, m.x, m.y) }
        onPositionChanged: function (m) {
            var p = mapToItem(note.parent, m.x, m.y);
            note.width = note._clamp(rs.sw + (p.x - rs.px), note.minW, note.maxW);
        }
        onReleased: note.geometryCommitted()
    }
    // 下
    MouseArea {
        height: 12; anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        cursorShape: Qt.SizeVerCursor
        onPressed: function (m) { note._begin(this, m.x, m.y) }
        onPositionChanged: function (m) {
            var p = mapToItem(note.parent, m.x, m.y);
            note.height = note._clamp(rs.sh + (p.y - rs.py), note.minH, note.maxH);
        }
        onReleased: note.geometryCommitted()
    }
    // 右下角
    MouseArea {
        width: 18; height: 18; anchors { right: parent.right; bottom: parent.bottom }
        cursorShape: Qt.SizeFDiagCursor
        onPressed: function (m) { note._begin(this, m.x, m.y) }
        onPositionChanged: function (m) {
            var p = mapToItem(note.parent, m.x, m.y);
            note.width = note._clamp(rs.sw + (p.x - rs.px), note.minW, note.maxW);
            note.height = note._clamp(rs.sh + (p.y - rs.py), note.minH, note.maxH);
        }
        onReleased: note.geometryCommitted()
    }
    // 左（同时移左边：右边钉死）
    MouseArea {
        width: 12; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 36 }
        cursorShape: Qt.SizeHorCursor
        onPressed: function (m) { note._begin(this, m.x, m.y) }
        onPositionChanged: function (m) {
            var p = mapToItem(note.parent, m.x, m.y);
            var nw = note._clamp(rs.sw - (p.x - rs.px), note.minW, note.maxW);
            note.x = rs.sx + (rs.sw - nw);
            note.width = nw;
        }
        onReleased: note.geometryCommitted()
    }
}
