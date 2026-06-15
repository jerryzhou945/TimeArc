import QtQuick
import QtQuick.Controls
import "../components/I18n.js" as I18n

// 文字层（v88 .memo-text-layer）。暗玻璃卡 + 可编辑文本；默认点击=落光标编辑，**按住 Alt 拖动**
// （DragHandler acceptedModifiers，非 Alt 时事件归 TextArea 编辑——避开 v88 reload 后不可拖的回归）；
// 自带可见 × 删除（与便签不同，不隐藏）；选中环统一 aqua（修 v88 旧蓝）。无位置钳制、无缩放把手。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §1.4 / 功能文 §2.5。
Item {
    id: tl

    property MemoryLakeStyle style
    property string languageMode: "zh"
    property bool selected: false
    property bool editing: false
    property string text: "输入文字"
    property bool heightFixed: false      // 手动拖高后高度固定；否则随内容自适应

    signal selectRequested(bool grabFocus)
    signal geometryCommitted()
    signal contentCommitted()
    signal deleteRequested()

    z: 123
    width: 220
    height: Math.max(36, edit.contentHeight + 20)

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 10
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(35 / 255, 40 / 255, 52 / 255, 0.88) }
            GradientStop { position: 1; color: Qt.rgba(18 / 255, 22 / 255, 32 / 255, 0.86) }
        }
        border.width: tl.selected ? 2 : 1
        border.color: tl.selected ? (tl.style ? tl.style.memoSelectRing : Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.58))
                                   : Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
        antialiasing: true
        clip: true                       // 手动缩小后裁掉溢出文字，不外溢

        TextArea {
            id: edit
            anchors.fill: parent
            leftPadding: 12; rightPadding: 38; topPadding: 10; bottomPadding: 10
            background: null
            text: tl.text
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            color: Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.94)
            font.pixelSize: 18
            onActiveFocusChanged: { tl.editing = activeFocus; if (activeFocus) tl.selectRequested(false) }
            onTextChanged: tl.text = text
            onEditingFinished: tl.contentCommitted()
        }

        // Alt 拖动（与 TextArea 编辑共存：仅 Alt 手势激活，非 Alt 点击归编辑）。
        DragHandler {
            target: tl
            acceptedModifiers: Qt.AltModifier
            cursorShape: Qt.SizeAllCursor
            onActiveChanged: {
                if (active) tl.selectRequested(true);
                else tl.geometryCommitted();
            }
        }

        // 可见 × 删除（右上）。
        Rectangle {
            width: 22; height: 22; radius: 11
            anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 6 }
            color: delMouse.containsMouse ? Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.35) : Qt.rgba(0, 0, 0, 0.20)
            Text { anchors.centerIn: parent; text: "×"; color: "#EAF2FF"; font.pixelSize: 15 }
            MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tl.deleteRequested()
            }
        }
    }

    // ===== 缩放把手：右 / 下 / 右下角（修 v88 文字框不可调整大小）=====
    // 宽始终显式；高默认随内容自适应，手动拖下/右下后固定（heightFixed）并由覆盖层持久化。
    QtObject {
        id: rs
        property real sx; property real sy; property real sw; property real sh
        property real px; property real py
    }
    function _begin(ma, mx, my) {
        var p = ma.mapToItem(tl.parent, mx, my);
        rs.sx = tl.x; rs.sy = tl.y; rs.sw = tl.width; rs.sh = tl.height;
        rs.px = p.x; rs.py = p.y;
        tl.selectRequested(true);
    }
    function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    readonly property real maxW: tl.parent ? tl.parent.width - 16 : 1200
    readonly property real maxH: tl.parent ? tl.parent.height - 16 : 800

    // 右（仅改宽，避开右上 × 按钮）
    MouseArea {
        width: 12; anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 34 }
        cursorShape: Qt.SizeHorCursor
        onPressed: function (m) { tl._begin(this, m.x, m.y) }
        onPositionChanged: function (m) {
            var p = mapToItem(tl.parent, m.x, m.y);
            tl.width = tl._clamp(rs.sw + (p.x - rs.px), 120, tl.maxW);
        }
        onReleased: tl.geometryCommitted()
    }
    // 下（改高 → 固定）
    MouseArea {
        height: 12; anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        cursorShape: Qt.SizeVerCursor
        onPressed: function (m) { tl._begin(this, m.x, m.y) }
        onPositionChanged: function (m) {
            var p = mapToItem(tl.parent, m.x, m.y);
            tl.heightFixed = true;
            tl.height = tl._clamp(rs.sh + (p.y - rs.py), 36, tl.maxH);
        }
        onReleased: tl.geometryCommitted()
    }
    // 右下角（改宽 + 改高）
    MouseArea {
        width: 18; height: 18; anchors { right: parent.right; bottom: parent.bottom }
        cursorShape: Qt.SizeFDiagCursor
        onPressed: function (m) { tl._begin(this, m.x, m.y) }
        onPositionChanged: function (m) {
            var p = mapToItem(tl.parent, m.x, m.y);
            tl.width = tl._clamp(rs.sw + (p.x - rs.px), 120, tl.maxW);
            tl.heightFixed = true;
            tl.height = tl._clamp(rs.sh + (p.y - rs.py), 36, tl.maxH);
        }
        onReleased: tl.geometryCommitted()
    }
}
