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

    // —— 多页模型：每页 owns 标签 + 对象 + 画布 PNG。pagesData 为纯数据，pageLabels 单独驱动 UI 绑定。
    property var pagesData: [{ label: "Page 1", objects: [], canvas: "" }]
    property int currentPage: 0
    property int _pageSeq: 1
    property var pageLabels: ["Page 1"]

    function _refreshLabels() {
        var ls = [];
        for (var i = 0; i < pagesData.length; i++) ls.push(pagesData[i].label);
        pageLabels = ls;
    }
    // 当前对象层序列化为纯数组（供存档 + 撤回快照共用）。
    function _snapshotObjects() {
        var objs = [];
        for (var i = 0; i < objectModel.count; i++) {
            var o = objectModel.get(i);
            objs.push({ t: o.otype, x: o.ox, y: o.oy, w: o.ow, h: o.oh,
                        ti: o.otitle, co: o.ocontent, tx: o.otext,
                        ts: o.ots || 0, done: o.odone === true, due: o.odue || 0 });
        }
        return objs;
    }
    // 把对象数组装回模型（供装载页 + 撤回还原共用）。
    function _applyRecords(objs) {
        objectModel.clear();
        var a = objs || [];
        for (var i = 0; i < a.length; i++) {
            var o = a[i];
            objectModel.append({ otype: o.t, ox: o.x, oy: o.y, ow: o.w, oh: o.h,
                                 otitle: o.ti || "", ocontent: o.co || "", otext: o.tx || "输入文字",
                                 ots: o.ts || 0, odone: o.done === true, odue: o.due || 0 });
        }
        memo.selectedObject = -1;
    }
    // 把当前 live 状态（对象 + 墨迹）写回当前页记录。
    function _writeCurrent() {
        pagesData[currentPage] = { label: pagesData[currentPage].label,
                                   objects: _snapshotObjects(), canvas: inkCanvas.exportDataURL() };
    }
    // 把某页记录装载进 live 状态。
    function _applyPage(p) {
        _applyRecords((p && p.objects) ? p.objects : []);
        inkCanvas.loadFromDataURL((p && p.canvas) ? p.canvas : "");
    }

    function switchPage(i) {
        if (i === currentPage || i < 0 || i >= pagesData.length) return;
        _writeCurrent();
        currentPage = i;
        _applyPage(pagesData[i]);
        scheduleSave();
        memo._histReset();
    }
    function addPage() {
        _writeCurrent();
        memo._pageSeq += 1;
        pagesData.push({ label: "Page " + memo._pageSeq, objects: [], canvas: "" });
        currentPage = pagesData.length - 1;
        _refreshLabels();
        _applyPage(pagesData[currentPage]);
        scheduleSave();
        memo._histReset();
    }
    function deletePage(i) {
        if (pagesData.length <= 1 || i < 0 || i >= pagesData.length) return;   // 保底留 1 页
        if (i !== currentPage) _writeCurrent();
        pagesData.splice(i, 1);
        if (currentPage === i) currentPage = Math.min(i, pagesData.length - 1);
        else if (currentPage > i) currentPage -= 1;
        _refreshLabels();
        _applyPage(pagesData[currentPage]);
        scheduleSave();
        memo._histReset();
    }

    // 序列化整篇（多页）→ store。debounce 见 saveTimer。
    function saveDoc() {
        if (!store) return;
        _writeCurrent();
        store.setValue(memo.docKey, JSON.stringify({ v: 2, pages: pagesData, current: currentPage }));
        saveStatus.flash("笔迹已保存");
    }
    function loadDoc() {
        if (!store) return;
        var raw = store.getValue(memo.docKey, "");
        if (!raw || raw.length === 0) return;
        var doc;
        try { doc = JSON.parse(raw); } catch (e) { return; }
        if (doc.pages && doc.pages.length > 0) {
            pagesData = doc.pages;
            currentPage = Math.max(0, Math.min(doc.current || 0, pagesData.length - 1));
        } else {   // v1 单文档兼容
            pagesData = [{ label: "Page 1", objects: doc.objects || [], canvas: doc.canvas || "" }];
            currentPage = 0;
        }
        memo._pageSeq = pagesData.length;
        _refreshLabels();
        _applyPage(pagesData[currentPage]);
    }
    function scheduleSave() { if (store) saveTimer.restart(); }

    Timer { id: saveTimer; interval: 600; repeat: false; onTriggered: memo.saveDoc() }

    // —— 撤回 / 重做（Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y）——
    // 按当前页做线性快照历史（对象数组 + 墨迹 dataURL）。每次提交型变更后记一帧；切页/打开重置。
    // 编辑文本框时 Ctrl+Z 归 TextArea 自身撤销（覆盖层未持焦，不会走到这里）。
    property var _hist: []
    property int _histAt: -1
    property bool _restoring: false
    readonly property int _histMax: 40

    function _snapshot() { return { objects: _snapshotObjects(), canvas: inkCanvas.exportDataURL() }; }
    function _histReset() { _hist = [_snapshot()]; _histAt = 0; }
    function _histRecord() {
        if (_restoring) return;
        if (_histAt < _hist.length - 1) _hist = _hist.slice(0, _histAt + 1);   // 丢弃 redo 尾
        _hist.push(_snapshot());
        if (_hist.length > _histMax) _hist.shift();
        _histAt = _hist.length - 1;
    }
    function _histApply(s) {
        _restoring = true;
        _applyRecords(s.objects);
        inkCanvas.loadFromDataURL(s.canvas || "");
        _restoring = false;
    }
    function undo() {
        if (_histAt <= 0) return;
        _histAt -= 1;
        _histApply(_hist[_histAt]);
        scheduleSave();
    }
    function redo() {
        if (_histAt >= _hist.length - 1) return;
        _histAt += 1;
        _histApply(_hist[_histAt]);
        scheduleSave();
    }

    // —— 对象创建/删除（内存模型；持久化切片接 C++ MemoStore）——
    function createSticky(px, py) {
        var w = 310, h = 285;
        var W = objectLayerHost.width, H = objectLayerHost.height;
        var x = Math.max(8, Math.min(px - 110, W - w - 8));
        var y = Math.max(84, Math.min(py - 22, H - h - 8));
        objectModel.append({ otype: "sticky", ox: x, oy: y, ow: w, oh: h,
                             otitle: "", ocontent: "", otext: "",
                             ots: new Date().getTime(), odone: false, odue: 0 });
        memo.selectedObject = objectModel.count - 1;
        memo.forceActiveFocus();
        memo.scheduleSave();
        memo._histRecord();
    }
    function createText(px, py) {
        objectModel.append({ otype: "text", ox: px, oy: py, ow: 240, oh: 0,
                             otitle: "", ocontent: "", otext: "输入文字",
                             ots: 0, odone: false, odue: 0 });
        memo.selectedObject = objectModel.count - 1;
        memo.forceActiveFocus();
        memo.scheduleSave();
        memo._histRecord();
    }
    function removeObject(i) {
        if (i < 0 || i >= objectModel.count) return;
        objectModel.remove(i);
        if (memo.selectedObject === i) memo.selectedObject = -1;
        else if (memo.selectedObject > i) memo.selectedObject -= 1;
        memo.scheduleSave();
        memo._histRecord();
    }

    // —— 选择工具：框选区域（笔迹 + 便签 + 文字）→ 复制 / 删除（移动/缩放见后续切片）——
    property var selObjs: []                       // 选中的对象下标
    property rect selRect: Qt.rect(0, 0, 0, 0)     // 选区矩形（对象层坐标）
    property bool selActive: false
    function _clearSelection() { selObjs = []; selActive = false; }
    function _rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }
    function _selectRegion(x, y, w, h) {
        var idxs = [];
        for (var i = 0; i < objectModel.count; i++) {
            var o = objectModel.get(i);
            if (_rectsOverlap(x, y, w, h, o.ox, o.oy, o.ow, o.oh)) idxs.push(i);
        }
        memo.selRect = Qt.rect(x, y, w, h);
        memo.selObjs = idxs;
        memo.selActive = true;
        memo.selectedObject = -1;                  // 单选与框选互斥
    }
    function _deleteSelection() {
        if (!selActive) return;
        if (selRect.width > 1 && selRect.height > 1)
            inkCanvas.clearRegion(selRect.x, selRect.y, selRect.width, selRect.height);
        var idxs = selObjs.slice().sort(function (a, b) { return b - a; });   // 降序删，下标不串
        for (var i = 0; i < idxs.length; i++) objectModel.remove(idxs[i]);
        memo.selectedObject = -1;
        _clearSelection();
        scheduleSave(); _histRecord();
    }
    function _copySelection() {
        if (!selActive) return;
        var dx = 28, dy = 28;
        var copies = [];                            // 先快照（append 会改下标/count）
        for (var k = 0; k < selObjs.length; k++) {
            var o = objectModel.get(selObjs[k]);
            copies.push({ otype: o.otype, ox: o.ox + dx, oy: o.oy + dy, ow: o.ow, oh: o.oh,
                          otitle: o.otitle, ocontent: o.ocontent, otext: o.otext,
                          ots: o.ots, odone: o.odone, odue: o.odue });
        }
        if (selRect.width > 1 && selRect.height > 1)     // 墨迹：选区像素 source-over 贴到偏移处
            inkCanvas.copyRegionTo(selRect.x, selRect.y, selRect.width, selRect.height,
                                   selRect.x + dx, selRect.y + dy, selRect.width, selRect.height);
        var base = objectModel.count;
        for (var j = 0; j < copies.length; j++) objectModel.append(copies[j]);
        var newIdxs = [];                            // 选区移到副本
        for (var n = 0; n < copies.length; n++) newIdxs.push(base + n);
        memo.selObjs = newIdxs;
        memo.selRect = Qt.rect(selRect.x + dx, selRect.y + dy, selRect.width, selRect.height);
        scheduleSave(); _histRecord();
    }

    // 工具提示文案（逐字对齐 v88 setMemoTool 16301-16307）。
    readonly property var toolHints: ({
        "none": "已取消当前工具。点击上方工具图标重新选择。",
        "select": "选择模式：在空白处拖出方框，框选笔迹/便签/文字；可一键复制、删除（移动/缩放后续支持）。",
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
            memo._histReset();   // 以当前页 live 状态作为撤回基线
        } else {
            memo.saveDoc();   // 关闭前强存（不丢笔迹/便签）
        }
    }

    focus: open
    // Esc 关闭；Del/Backspace 删除选中对象——仅当覆盖层（非文本框）持焦时触发，
    // 故编辑便签/文字时不劫持（焦点在 TextArea，键归它）。
    Keys.onPressed: function (e) {
        if (e.key === Qt.Key_Escape) {
            if (memo.selActive) memo._clearSelection();   // 先清框选，再次 Esc 才关闭
            else memo.open = false;
            e.accepted = true;
        } else if (e.key === Qt.Key_Z && (e.modifiers & Qt.ControlModifier)) {
            // Ctrl+Z 撤回 / Ctrl+Shift+Z 重做（编辑文本框时此处不触发，归 TextArea 自身撤销）。
            if (e.modifiers & Qt.ShiftModifier) memo.redo(); else memo.undo();
            e.accepted = true;
        } else if (e.key === Qt.Key_Y && (e.modifiers & Qt.ControlModifier)) {
            memo.redo();
            e.accepted = true;
        } else if (e.key === Qt.Key_C && (e.modifiers & Qt.ControlModifier) && memo.selActive) {
            memo._copySelection();
            e.accepted = true;
        } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
            if (memo.selActive) { memo._deleteSelection(); e.accepted = true; }
            else if (memo.selectedObject >= 0) { memo.removeObject(memo.selectedObject); e.accepted = true; }
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
            case "select": return Qt.ArrowCursor;
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
            onStrokeEnded: { memo.scheduleSave(); memo._histRecord(); }
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

        // 选择工具：空白处拖出框选矩形（起点落在对象上则归对象自身手势；命中靠几何相交）。
        MouseArea {
            id: marqueeArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: toolbar.currentTool === "select"
            property real sx: 0
            property real sy: 0
            onPressed: function (m) {
                memo._clearSelection();
                sx = m.x; sy = m.y;
                marquee.x = m.x; marquee.y = m.y; marquee.width = 0; marquee.height = 0;
                marquee.visible = true;
            }
            onPositionChanged: function (m) {
                marquee.x = Math.min(sx, m.x); marquee.y = Math.min(sy, m.y);
                marquee.width = Math.abs(m.x - sx); marquee.height = Math.abs(m.y - sy);
            }
            onReleased: function (m) {
                marquee.visible = false;
                if (marquee.width < 6 || marquee.height < 6) { memo._clearSelection(); return; }
                memo._selectRegion(marquee.x, marquee.y, marquee.width, marquee.height);
            }
            onCanceled: marquee.visible = false
        }

        // 包一层填充壳：Loader 把「壳」拉满覆盖层（壳是普通 Item，被拉伸无副作用），真正的
        // 便签/文字作为壳的子项、用自身 x/y/w/h 定位，不被 Loader 强制改尺寸。
        // 修 bug：有显式尺寸的 Loader 会把被加载项也拉成同尺寸 → 全屏/退全屏时便签暴涨、
        // 文字框创建即铺满。壳吸收拉伸后，对象保留自身几何，便签的 parent 仍是覆盖层级（钳制不变）。
        Component {
            id: stickyComp
            Item {
                anchors.fill: parent
                property alias inner: stickyInner
                StickyNote { id: stickyInner; style: memo.style }
            }
        }
        Component {
            id: textComp
            Item {
                anchors.fill: parent
                property alias inner: textInner
                TextLayer { id: textInner; style: memo.style }
            }
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
                // 真正的对象（壳内子项）；Connections/回写都走它，不走 Loader 自身。
                readonly property var obj: item ? item.inner : null
                onLoaded: {
                    var it = item.inner;
                    it.x = model.ox;
                    it.y = model.oy;
                    if (model.otype === "sticky") {
                        it.width = model.ow;
                        it.height = model.oh;
                        it.title = model.otitle;
                        it.content = model.ocontent;
                        it.createdMs = model.ots || 0;
                        it.done = model.odone === true;
                        it.due = model.odue || 0;
                    } else {
                        it.text = model.otext;
                        if (model.ow > 0) it.width = model.ow;
                        if (model.oh > 0) { it.heightFixed = true; it.height = model.oh; }
                    }
                    it.selected = Qt.binding(function () { return memo.selectedObject === ldr.index; });
                }
                Connections {
                    target: ldr.obj
                    ignoreUnknownSignals: true   // 文字层无 doneToggled，忽略以免告警
                    function onSelectRequested(grabFocus) {
                        memo.selectedObject = ldr.index;
                        if (grabFocus) memo.forceActiveFocus();
                    }
                    function onDoneToggled() {
                        objectModel.setProperty(ldr.index, "odone", ldr.obj.done);
                        memo.scheduleSave();
                        memo._histRecord();
                    }
                    function onDueEditRequested() {
                        duePicker.targetIndex = ldr.index;
                        duePicker.initialMs = ldr.obj.due;
                        duePicker.open = true;
                    }
                    function onGeometryCommitted() {
                        objectModel.setProperty(ldr.index, "ox", ldr.obj.x);
                        objectModel.setProperty(ldr.index, "oy", ldr.obj.y);
                        objectModel.setProperty(ldr.index, "ow", ldr.obj.width);
                        if (ldr.model.otype === "text")
                            objectModel.setProperty(ldr.index, "oh", ldr.obj.heightFixed ? ldr.obj.height : 0);
                        else
                            objectModel.setProperty(ldr.index, "oh", ldr.obj.height);
                        memo.scheduleSave();
                        memo._histRecord();
                    }
                    function onContentCommitted() {
                        if (ldr.model.otype === "sticky") {
                            objectModel.setProperty(ldr.index, "otitle", ldr.obj.title);
                            objectModel.setProperty(ldr.index, "ocontent", ldr.obj.content);
                        } else {
                            objectModel.setProperty(ldr.index, "otext", ldr.obj.text);
                        }
                        memo.scheduleSave();
                        memo._histRecord();
                    }
                    function onDeleteRequested() { memo.removeObject(ldr.index); }
                }
            }
        }

        // 框选橡皮筋（仅视觉；命中在 marqueeArea）。
        Rectangle {
            id: marquee
            visible: false
            z: 400
            color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.10)
            border.width: 1
            border.color: memo.style ? memo.style.glowCyan : "#8EDFFF"
        }

        // 选区框 + 复制/删除动作条。
        Item {
            id: selectionBox
            visible: memo.selActive && toolbar.currentTool === "select"
            x: memo.selRect.x; y: memo.selRect.y
            width: memo.selRect.width; height: memo.selRect.height
            z: 401

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.07)
                border.width: 1.5
                border.color: memo.style ? memo.style.glowCyan : "#8EDFFF"
            }
            Row {
                anchors { bottom: parent.top; bottomMargin: 8; right: parent.right }
                spacing: 6
                Rectangle {
                    width: copyT.implicitWidth + 22; height: 30; radius: 8
                    color: copyMa.containsMouse ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.20)
                                                : Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.22)
                    Text { id: copyT; anchors.centerIn: parent; text: "复制"
                           color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.92); font.pixelSize: 13 }
                    MouseArea { id: copyMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: memo._copySelection() }
                }
                Rectangle {
                    width: delT.implicitWidth + 22; height: 30; radius: 8
                    color: delMa.containsMouse ? Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.75)
                                               : Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1; border.color: Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.40)
                    Text { id: delT; anchors.centerIn: parent; text: "删除"
                           color: Qt.rgba(255 / 255, 235 / 255, 235 / 255, 0.95); font.pixelSize: 13 }
                    MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: memo._deleteSelection() }
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
        onPomodoroRequested: pomodoro.shown = !pomodoro.shown
        onCurrentToolChanged: if (currentTool !== "select") memo._clearSelection()
    }

    // 番茄钟浮窗 + 完成弹层。
    PomodoroWidget {
        id: pomodoro
        style: memo.style
        shown: false
        onCompleted: function (v) { pomodoroComplete.variant = v; pomodoroComplete.shown = true; }
    }
    PomodoroCompleteOverlay {
        id: pomodoroComplete
        style: memo.style
        onClosed: pomodoroComplete.shown = false
    }

    // 便签截止日期选择器（单例；由便签截止行触发，居中弹出）。
    MemoDatePicker {
        id: duePicker
        style: memo.style
        property int targetIndex: -1
        function _setDue(ms) {
            if (targetIndex < 0) return;
            objectModel.setProperty(targetIndex, "odue", ms);
            var d = objRepeater.itemAt(targetIndex);
            if (d && d.obj) d.obj.due = ms;
            memo.scheduleSave();
            memo._histRecord();
            open = false;
        }
        onDueSelected: function (ms) { _setDue(ms); }
        onDueCleared: _setDue(0)
        onDismissed: open = false
    }

    // 右上档案袋（多页切换）。
    MemoPageFolder {
        id: pageFolder
        anchors { right: parent.right; top: parent.top; rightMargin: 18; topMargin: 18 }
        style: memo.style
        pageLabels: memo.pageLabels
        currentIndex: memo.currentPage
        visible: memo.open
        opacity: memo.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
        onSwitchTo: function (i) { memo.switchPage(i); }
        onAddPageRequested: memo.addPage()
        onDeletePageRequested: function (i) { memo.deletePage(i); }
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
        anchors { top: parent.top; left: parent.left; topMargin: 30; leftMargin: 24 }
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
