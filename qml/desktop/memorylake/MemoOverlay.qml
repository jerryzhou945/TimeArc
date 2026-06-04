import QtQuick
import QtQuick.Effects

// 备忘黑板·模态覆盖层（v88 #memoOverlay）。
// **入口是动作不是路由**：盖在首页之上、底层页面原样保留，关闭后退回原处，全程不换页
// （功能文 §2.1 / 验收 C0）。本切片（F-B1 / M-B1）只搭壳 + 黑板底 + 三层分离骨架
// （背景层 / 透明墨水层 host / 对象层 host）；工具条 / 画布 / 便签 / 番茄由后续切片填充。
// 黑板恒暗（G10），不随昼夜；点阵画在底层。
// 美术见 docs/memory-lake-memo-render-pipeline-replication.md §1.1/§4.1/§4.2。
Item {
    id: memo

    // 记忆湖色板（单一令牌源，G1）。由 Shell 注入。
    property MemoryLakeStyle style
    // 身后首页快照源（M0：QML 无实时 backdrop-filter，截首页快照重模糊当黑板磨砂底）。
    property Item backdropSource: null

    // 开合状态（动作）。开合唯一动画 = opacity .26s ease（功能文 §2.1 / C0）。
    property bool open: false

    // 当前选中对象下标（-1 = 无）。
    property int selectedObject: -1

    // UI 私有持久化后端（Shell 注入 settingsRepository；通用 key-value，非服务磁盘契约）。
    // 解耦：组件不直接引用全局 context property，store 为空时（如独立预览）静默跳过。
    property var store: null
    readonly property string docKey: "memoryLakeMemoDoc"
    property bool _loaded: false

    // 序列化整篇备忘（对象 + 墨迹 PNG dataURL）→ store。debounce 见 saveTimer。
    function saveDoc() {
        if (!store) return;
        var objs = [];
        for (var i = 0; i < objectModel.count; i++) {
            var o = objectModel.get(i);
            objs.push({ t: o.otype, x: o.ox, y: o.oy, w: o.ow, h: o.oh,
                        ti: o.otitle, co: o.ocontent, tx: o.otext });
        }
        var doc = { v: 1, objects: objs, canvas: inkCanvas.exportDataURL() };
        store.setValue(memo.docKey, JSON.stringify(doc));
        saveStatus.flash("笔迹已保存");
    }
    function loadDoc() {
        if (!store) return;
        var raw = store.getValue(memo.docKey, "");
        if (!raw || raw.length === 0) return;
        var doc;
        try { doc = JSON.parse(raw); } catch (e) { return; }
        objectModel.clear();
        var objs = doc.objects || [];
        for (var i = 0; i < objs.length; i++) {
            var o = objs[i];
            objectModel.append({ otype: o.t, ox: o.x, oy: o.y, ow: o.w, oh: o.h,
                                 otitle: o.ti || "", ocontent: o.co || "", otext: o.tx || "输入文字" });
        }
        memo.selectedObject = -1;
        if (doc.canvas) inkCanvas.loadFromDataURL(doc.canvas);
    }
    function scheduleSave() { if (store) saveTimer.restart(); }

    Timer { id: saveTimer; interval: 600; repeat: false; onTriggered: memo.saveDoc() }

    // —— 对象创建/删除（内存模型；持久化切片接 C++ MemoStore）——
    function createSticky(px, py) {
        var w = 310, h = 285;
        var W = objectLayerHost.width, H = objectLayerHost.height;
        var x = Math.max(8, Math.min(px - 110, W - w - 8));
        var y = Math.max(84, Math.min(py - 22, H - h - 8));
        objectModel.append({ otype: "sticky", ox: x, oy: y, ow: w, oh: h,
                             otitle: "", ocontent: "", otext: "" });
        memo.selectedObject = objectModel.count - 1;
        memo.forceActiveFocus();
        memo.scheduleSave();
    }
    function createText(px, py) {
        objectModel.append({ otype: "text", ox: px, oy: py, ow: 220, oh: 40,
                             otitle: "", ocontent: "", otext: "输入文字" });
        memo.selectedObject = objectModel.count - 1;
        memo.forceActiveFocus();
        memo.scheduleSave();
    }
    function removeObject(i) {
        if (i < 0 || i >= objectModel.count) return;
        objectModel.remove(i);
        if (memo.selectedObject === i) memo.selectedObject = -1;
        else if (memo.selectedObject > i) memo.selectedObject -= 1;
        memo.scheduleSave();
    }

    // 工具提示文案（逐字对齐 v88 setMemoTool 16301-16307）。
    readonly property var toolHints: ({
        "none": "已取消当前工具。点击上方工具图标重新选择。",
        "note": "便签模式：点击画布创建白色便签，便签可拖动、可编辑、可左右上下拉伸。",
        "text": "文字模式：点击画布添加文本，输入后可继续编辑。",
        "pen": "画笔模式：按住鼠标在灰色蒙版上自由绘图。",
        "eraser": "橡皮擦模式：按住鼠标擦除画笔痕迹。"
    })

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }

    // 开启时抓一张首页快照（重模糊底）并取得焦点（Esc 关闭）。
    onOpenChanged: {
        if (open) {
            if (homeShot.sourceItem)
                homeShot.scheduleUpdate();
            if (!memo._loaded) { memo.loadDoc(); memo._loaded = true; }   // 首次打开恢复存档
            toolbar.currentTool = "pen";   // 每次打开默认画笔（功能文 §2.1）
            memo.forceActiveFocus();
        } else {
            memo.saveDoc();   // 关闭前强存（不丢笔迹/便签）
        }
    }

    focus: open
    // Esc 关闭；Del/Backspace 删除选中对象——仅当覆盖层（非文本框）持焦时触发，
    // 故编辑便签/文字时不劫持（焦点在 TextArea，键归它）。
    Keys.onPressed: function (e) {
        if (e.key === Qt.Key_Escape) {
            memo.open = false;
            e.accepted = true;
        } else if ((e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace)
                   && memo.selectedObject >= 0) {
            memo.removeObject(memo.selectedObject);
            e.accepted = true;
        }
    }

    // 模态：拦截一切落向首页的输入。后续切片的工具/画布/对象层叠在此之上各自接管命中。
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        // 光标随工具（note→copy 近似 DragCopy / text→IBeam / none→Arrow / pen·eraser 由墨水层置 Cross）。
        cursorShape: {
            switch (toolbar.currentTool) {
            case "text": return Qt.IBeamCursor;
            case "note": return Qt.DragCopyCursor;
            case "none": return Qt.ArrowCursor;
            default: return Qt.CrossCursor;
            }
        }
        onClicked: memo.forceActiveFocus()
    }

    // ===== L0 身后首页快照 + 重模糊（M0；等效 backdrop-filter blur(10px)）=====
    ShaderEffectSource {
        id: homeShot
        anchors.fill: parent
        sourceItem: memo.backdropSource
        live: false          // 静态快照：进入备忘时抓一帧，期间首页不再实时重绘
        hideSource: false
        visible: false        // 仅作纹理源，重模糊结果由下面的 MultiEffect 呈现
    }
    MultiEffect {
        anchors.fill: parent
        source: homeShot
        visible: memo.backdropSource !== null
        blurEnabled: true
        blur: 1.0
        blurMax: memo.style ? memo.style.memoBackdropBlurMax : 40
    }

    // ===== L1 近黑竖渐变 + 角落辅光对 + 10% 黑罩 =====
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: memo.style ? memo.style.memoBoardTop
                                                             : Qt.rgba(9 / 255, 11 / 255, 18 / 255, 0.82) }
            GradientStop { position: 1.0; color: memo.style ? memo.style.memoBoardBottom
                                                             : Qt.rgba(6 / 255, 8 / 255, 14 / 255, 0.86) }
        }
    }
    // 左上 aqua 辅光（设计稿 18% 12% @6%）：GlowCircle 圆心落在该百分点、向内自然淡出到透明。
    GlowCircle {
        readonly property real d: Math.max(memo.width, memo.height) * 0.70
        width: d; height: d
        x: memo.width * 0.18 - d / 2
        y: memo.height * 0.12 - d / 2
        glowColor: memo.style ? memo.style.glowCyan : "#8EDFFF"
        glowOpacity: memo.style ? memo.style.memoGlowAquaOpacity : 0.06
    }
    // 右下 violet 辅光（设计稿 76% 72% @5.5%）。
    GlowCircle {
        readonly property real d: Math.max(memo.width, memo.height) * 0.72
        width: d; height: d
        x: memo.width * 0.76 - d / 2
        y: memo.height * 0.72 - d / 2
        glowColor: memo.style ? memo.style.violet : "#9B8BFF"
        glowOpacity: memo.style ? memo.style.memoGlowVioletOpacity : 0.055
    }
    // 整体 10% 黑罩（::before rgba(0,0,0,.10)）。
    Rectangle {
        anchors.fill: parent
        color: memo.style ? memo.style.memoScrim : Qt.rgba(0, 0, 0, 0.10)
    }

    // ===== L2 黑板点阵（白点 10.5% / 24px 平铺）=====
    MemoDotTexture {
        anchors.fill: parent
        dotColor: memo.style ? memo.style.memoDotColor : Qt.rgba(1, 1, 1, 0.105)
        pitch: memo.style ? memo.style.memoDotPitch : 24
        dotRadius: memo.style ? memo.style.memoDotRadius : 1
    }

    // ===== 三层分离骨架（G3 / §5.2）=====
    // z 次序：透明墨水层（画笔/橡皮 destination-out，只擦墨水不擦点阵/便签）→ 对象层（便签 z 高于文字）。
    Item {
        id: inkLayerHost
        anchors.fill: parent
        MemoInkCanvas {
            id: inkCanvas
            anchors.fill: parent
            style: memo.style
            tool: toolbar.currentTool
            onStrokeEnded: memo.scheduleSave()
        }
    }
    Item {
        id: objectLayerHost
        anchors.fill: parent

        ListModel { id: objectModel }

        // 创建/取消选中层（在对象之下、墨水之上）：note/text 工具点空白→建对象；none→点空白取消选中；
        // pen/eraser 时禁用，让点击落到墨水层绘制。
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: toolbar.currentTool === "note" || toolbar.currentTool === "text"
                     || toolbar.currentTool === "none"
            onClicked: function (m) {
                if (toolbar.currentTool === "note") memo.createSticky(m.x, m.y);
                else if (toolbar.currentTool === "text") memo.createText(m.x, m.y);
                else memo.selectedObject = -1;
            }
        }

        Component {
            id: stickyComp
            StickyNote { style: memo.style }
        }
        Component {
            id: textComp
            TextLayer { style: memo.style }
        }

        Repeater {
            id: objRepeater
            model: objectModel
            delegate: Loader {
                id: ldr
                required property int index
                required property var model
                anchors.fill: parent
                sourceComponent: model.otype === "text" ? textComp : stickyComp
                onLoaded: {
                    item.x = model.ox;
                    item.y = model.oy;
                    if (model.otype === "sticky") {
                        item.width = model.ow;
                        item.height = model.oh;
                        item.title = model.otitle;
                        item.content = model.ocontent;
                    } else {
                        item.text = model.otext;
                    }
                    item.selected = Qt.binding(function () { return memo.selectedObject === ldr.index; });
                }
                Connections {
                    target: ldr.item
                    function onSelectRequested(grabFocus) {
                        memo.selectedObject = ldr.index;
                        if (grabFocus) memo.forceActiveFocus();
                    }
                    function onGeometryCommitted() {
                        objectModel.setProperty(ldr.index, "ox", ldr.item.x);
                        objectModel.setProperty(ldr.index, "oy", ldr.item.y);
                        if (ldr.model.otype === "sticky") {
                            objectModel.setProperty(ldr.index, "ow", ldr.item.width);
                            objectModel.setProperty(ldr.index, "oh", ldr.item.height);
                        }
                        memo.scheduleSave();
                    }
                    function onContentCommitted() {
                        if (ldr.model.otype === "sticky") {
                            objectModel.setProperty(ldr.index, "otitle", ldr.item.title);
                            objectModel.setProperty(ldr.index, "ocontent", ldr.item.content);
                        } else {
                            objectModel.setProperty(ldr.index, "otext", ldr.item.text);
                        }
                        memo.scheduleSave();
                    }
                    function onDeleteRequested() { memo.removeObject(ldr.index); }
                }
            }
        }
    }   // F-B4/F-B5 便签 + 文字层

    // ===== Chrome：工具条 + 提示胶囊 =====
    MemoToolbar {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 22
        style: memo.style
        shown: memo.open
        onExitRequested: memo.open = false
    }

    Rectangle {
        id: hintPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        height: 34
        width: hintText.implicitWidth + 28
        radius: 17
        color: Qt.rgba(0, 0, 0, 0.30)
        border.width: 1
        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.14)
        opacity: memo.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
        Text {
            id: hintText
            anchors.centerIn: parent
            text: memo.toolHints[toolbar.currentTool] || ""
            color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.80)
            font.pixelSize: 13
        }
    }

    // 保存状态胶囊（右上）。flash 后回落到 .72 走真实淡出（修 v88 硬切，C11）。
    Rectangle {
        id: saveStatus
        property bool flashOn: false
        function flash(t) { saveStatusText.text = t; flashOn = true; fadeTimer.restart(); }
        anchors { top: parent.top; right: parent.right; topMargin: 30; rightMargin: 24 }
        height: 30
        width: saveStatusText.implicitWidth + 24
        radius: 15
        visible: memo.open && (memo.store !== null)
        color: Qt.rgba(0, 0, 0, 0.30)
        border.width: 1
        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.14)
        opacity: memo.open ? (flashOn ? 1.0 : 0.72) : 0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Text {
            id: saveStatusText
            anchors.centerIn: parent
            text: "笔迹会自动保存"
            color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.80)
            font.pixelSize: 12
        }
        Timer {
            id: fadeTimer
            interval: 1100
            onTriggered: { saveStatus.flashOn = false; saveStatusText.text = "笔迹会自动保存"; }
        }
    }
}
