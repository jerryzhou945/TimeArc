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
                        ti: o.otitle, co: o.ocontent, tx: o.otext, sg: o.osign || "",
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
                                 osign: o.sg || "",
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
        _clearSelection();           // 选区是按页的；切页清掉（剪贴板 _clip 保留，供跨页粘贴）
        scheduleSave();
        memo._histReset();
        memo.forceActiveFocus();     // 切页后仍可 Ctrl+V 粘贴到新页
    }
    function addPage() {
        if (pagesData.length >= 10) return;   // 最多 10 页（与 MemoPageFolder.maxPages 一致）
        _writeCurrent();
        memo._pageSeq += 1;
        pagesData.push({ label: "Page " + memo._pageSeq, objects: [], canvas: "" });
        currentPage = pagesData.length - 1;
        _refreshLabels();
        _applyPage(pagesData[currentPage]);
        _clearSelection();
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
        _clearSelection();
        scheduleSave();
        memo._histReset();
    }
    // 重命名某页（只改标签，不动该页对象/墨迹；空名忽略）。当前页的 label 由 _writeCurrent 透传保留。
    function renamePage(i, name) {
        if (i < 0 || i >= pagesData.length) return;
        var n = ("" + name).trim();
        if (n.length === 0 || n === pagesData[i].label) return;
        pagesData[i].label = n;
        _refreshLabels();
        scheduleSave();
    }

    // 序列化整篇（多页）→ store。debounce 见 saveTimer。
    function saveDoc() {
        if (!store) return;
        if (_selDragging) return;   // 手势中画布暂缺一块（墨迹浮起），别存到缺口；提交后会再存
        _writeCurrent();
        store.setValue(memo.docKey, JSON.stringify({ v: 2, pages: pagesData, current: currentPage,
                                                     pen: { pw: toolbar.penWidth, ew: toolbar.eraserWidth,
                                                            color: "" + toolbar.inkColor } }));
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
        // 笔宽（gap #3）：恢复用户选档（缺省保持 style 默认）。
        if (doc.pen) {
            if (typeof doc.pen.pw === "number") toolbar.penWidth = doc.pen.pw;
            if (typeof doc.pen.ew === "number") toolbar.eraserWidth = doc.pen.ew;
            if (typeof doc.pen.color === "string" && doc.pen.color.length > 0) toolbar.inkColor = doc.pen.color;
        }
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
        var y = Math.max(8, Math.min(py - 22, H - h - 8));   // 顶部开放（灵动岛顶栏）
        objectModel.append({ otype: "sticky", ox: x, oy: y, ow: w, oh: h,
                             otitle: "", ocontent: "", otext: "", osign: "",
                             ots: new Date().getTime(), odone: false, odue: 0 });
        memo.selectedObject = objectModel.count - 1;
        memo.forceActiveFocus();
        memo.scheduleSave();
        memo._histRecord();
    }
    function createText(px, py) {
        objectModel.append({ otype: "text", ox: px, oy: py, ow: 240, oh: 0,
                             otitle: "", ocontent: "", otext: "输入文字", osign: "",
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
    // gap #4：清空本页墨迹（仅手绘层；便签/文字保留）。存盘 + 入撤销栈（Ctrl+Z 可恢复）。
    function clearCurrentCanvas() {
        memo._clearSelection();
        inkCanvas.clearAll();
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
        // 钳进画布：靠边或把框拉出边缘时，越界的快照/清除/贴图会采样到图像外 → 出现"原本没有的笔迹"。
        var W = objectLayerHost.width, H = objectLayerHost.height;
        if (x < 0) { w += x; x = 0; }
        if (y < 0) { h += y; y = 0; }
        if (x + w > W) w = W - x;
        if (y + h > H) h = H - y;
        if (w < 1 || h < 1) { _clearSelection(); return; }
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
    // —— 剪贴板：复制(Ctrl+C)与粘贴(Ctrl+V)分离，可跨页；复制按钮 = 复制+就地粘贴 ——
    // 存「全幅墨迹快照 + 源矩形 + 对象(相对选区原点)」。跨页因 MemoOverlay 常驻而保留。
    property var _clip: null

    function _copyToClipboard() {
        if (!selActive) return;
        var objs = [];
        for (var i = 0; i < selObjs.length; i++) {
            var o = objectModel.get(selObjs[i]);
            objs.push({ otype: o.otype, dx: o.ox - selRect.x, dy: o.oy - selRect.y, ow: o.ow, oh: o.oh,
                        otitle: o.otitle, ocontent: o.ocontent, otext: o.otext,
                        ots: o.ots, odone: o.odone, odue: o.odue });
        }
        var hasInk = selRect.width > 1 && selRect.height > 1;
        memo._clip = { objs: objs, inkUrl: hasInk ? inkCanvas.exportDataURL() : "",
                       sx: selRect.x, sy: selRect.y, sw: selRect.width, sh: selRect.height };
        if (store) saveStatus.flash("已复制 " + objs.length + " 项");
    }

    // 选一个不出界的落点：右→下→左→上 依次试，都放不下再钳进画布。
    function _pasteOrigin(w, h, sX, sY) {
        var W = objectLayerHost.width, H = objectLayerHost.height, gap = 24;
        var cands = [ { x: sX + w + gap, y: sY }, { x: sX, y: sY + h + gap },
                      { x: sX - w - gap, y: sY }, { x: sX, y: sY - h - gap } ];
        for (var i = 0; i < cands.length; i++) {
            var c = cands[i];
            if (c.x >= 8 && c.y >= 8 && c.x + w <= W - 8 && c.y + h <= H - 8) return c;
        }
        return { x: Math.max(8, Math.min(sX + gap, W - w - 8)),
                 y: Math.max(8, Math.min(sY + gap, H - h - 8)) };
    }
    function _pasteClipboard() {
        if (!_clip) return;
        var w = _clip.sw, h = _clip.sh;
        var dst = _pasteOrigin(w, h, _clip.sx, _clip.sy);
        if (_clip.inkUrl && _clip.inkUrl.length > 0 && w > 1 && h > 1)   // 墨迹：源矩形 source-over 贴到落点
            inkCanvas.stampRegion(_clip.inkUrl, _clip.sx, _clip.sy, w, h, dst.x, dst.y, w, h);
        var base = objectModel.count;
        for (var j = 0; j < _clip.objs.length; j++) {
            var ob = _clip.objs[j];
            objectModel.append({ otype: ob.otype, ox: dst.x + ob.dx, oy: dst.y + ob.dy, ow: ob.ow, oh: ob.oh,
                                 otitle: ob.otitle, ocontent: ob.ocontent, otext: ob.otext,
                                 ots: ob.ots, odone: ob.odone, odue: ob.odue });
        }
        var newIdxs = [];                            // 选区落到新粘贴的这组对象（拖动的是它们，不是原内容）
        for (var n = 0; n < _clip.objs.length; n++) newIdxs.push(base + n);
        memo.selObjs = newIdxs;
        memo.selRect = Qt.rect(dst.x, dst.y, w, h);
        memo.selActive = true;
        memo.selectedObject = -1;
        scheduleSave(); _histRecord();
    }
    // 复制按钮 = 复制 + 立即粘贴（就地、不丢、不重叠）。
    function _copySelection() { if (selActive) { _copyToClipboard(); _pasteClipboard(); } }

    // —— 选区移动 / 缩放（含浮动墨迹：抬起→拖动→回贴）——
    property bool _selDragging: false
    property bool _floatCleared: false             // 源区是否已清（待浮层 Ready 才清，避免拖动瞬间消失）
    property string _floatUrl: ""                  // 抬起前全幅快照（贴回用）
    property rect _floatSrc: Qt.rect(0, 0, 0, 0)   // 抬起的源矩形
    property rect _boxStart: Qt.rect(0, 0, 0, 0)   // 手势起始盒子
    property var _objStart: []                     // 起始各对象几何
    function _liveObj(idx) { var it = objRepeater.itemAt(idx); return (it && it.obj) ? it.obj : null; }
    function _beginSelGesture() {
        if (!selActive) return;
        _boxStart = Qt.rect(selRect.x, selRect.y, selRect.width, selRect.height);
        _objStart = [];
        for (var i = 0; i < selObjs.length; i++) {
            var o = objectModel.get(selObjs[i]);
            _objStart.push({ idx: selObjs[i], ox: o.ox, oy: o.oy, ow: o.ow, oh: o.oh });
        }
        _floatSrc = Qt.rect(selRect.x, selRect.y, selRect.width, selRect.height);
        _floatUrl = inkCanvas.exportDataURL();     // 抬起前快照
        inkCanvas.loadImage(_floatUrl);            // 预载：提交时同步贴回，且不依赖浮层缓存
        _floatCleared = false;                     // 源区等浮层 Ready 再清（见 floatInk.onStatusChanged）
        _selDragging = true;
    }
    function _applyMove(dgx, dgy) {
        // 钳制盒子留在画布内（不让墨迹被拖出边缘 → 越界回贴产生伪影）；对象按实际位移走。
        var W = objectLayerHost.width, H = objectLayerHost.height;
        var nx = Math.max(0, Math.min(_boxStart.x + dgx, Math.max(0, W - _boxStart.width)));
        var ny = Math.max(0, Math.min(_boxStart.y + dgy, Math.max(0, H - _boxStart.height)));
        var adx = nx - _boxStart.x, ady = ny - _boxStart.y;
        memo.selRect = Qt.rect(nx, ny, _boxStart.width, _boxStart.height);
        for (var i = 0; i < _objStart.length; i++) {
            var s = _objStart[i], ob = _liveObj(s.idx);
            if (ob) { ob.x = s.ox + adx; ob.y = s.oy + ady; }
        }
    }
    function _applyScale(nw, nh) {
        var W = objectLayerHost.width, H = objectLayerHost.height;
        nw = Math.max(40, Math.min(nw, W - _boxStart.x));   // 不越右/下边
        nh = Math.max(40, Math.min(nh, H - _boxStart.y));
        var fx = nw / _boxStart.width, fy = nh / _boxStart.height;
        memo.selRect = Qt.rect(_boxStart.x, _boxStart.y, nw, nh);
        for (var i = 0; i < _objStart.length; i++) {
            var s = _objStart[i], ob = _liveObj(s.idx);
            if (!ob) continue;
            ob.x = _boxStart.x + (s.ox - _boxStart.x) * fx;
            ob.y = _boxStart.y + (s.oy - _boxStart.y) * fy;
            ob.width = Math.max(60, s.ow * fx);
            if (ob.heightFixed !== undefined) { ob.heightFixed = true; ob.height = Math.max(36, s.oh * fy); }
            else ob.height = Math.max(48, s.oh * fy);
        }
    }
    function _commitSelGesture() {
        if (!_selDragging) return;
        // 浮层若未及时触发清源但快照已载，则此刻同步完成"抬起"（修极快拖动时墨迹不动/丢失）。
        if (!_floatCleared && _floatUrl.length > 0 && _floatSrc.width > 1
                && inkCanvas.isImageLoaded(_floatUrl)) {
            inkCanvas.clearRegion(_floatSrc.x, _floatSrc.y, _floatSrc.width, _floatSrc.height);
            _floatCleared = true;
        }
        if (_floatCleared && _floatSrc.width > 1 && selRect.width > 1)   // 同步贴回（已预载）
            inkCanvas.stampRegion(_floatUrl, _floatSrc.x, _floatSrc.y, _floatSrc.width, _floatSrc.height,
                                  selRect.x, selRect.y, selRect.width, selRect.height);
        for (var i = 0; i < selObjs.length; i++) {
            var ob = _liveObj(selObjs[i]);
            if (!ob) continue;
            objectModel.setProperty(selObjs[i], "ox", ob.x);
            objectModel.setProperty(selObjs[i], "oy", ob.y);
            objectModel.setProperty(selObjs[i], "ow", ob.width);
            if (objectModel.get(selObjs[i]).otype === "text")
                objectModel.setProperty(selObjs[i], "oh", ob.heightFixed ? ob.height : 0);
            else
                objectModel.setProperty(selObjs[i], "oh", ob.height);
        }
        _selDragging = false;
        _floatCleared = false;
        _floatUrl = "";
        scheduleSave(); _histRecord();
    }

    // 工具提示文案（逐字对齐 v88 setMemoTool 16301-16307）。
    readonly property var toolHints: ({
        "none": "已取消当前工具。点击上方工具图标重新选择。",
        "select": "选择模式：框选笔迹/便签/文字；拖选框移动、拖右下角缩放；复制键就地复制，Ctrl+C 复制 / Ctrl+V 粘贴(可跨页)，Del 删除。",
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
            memo._copyToClipboard();   // 仅复制，不粘贴
            e.accepted = true;
        } else if (e.key === Qt.Key_V && (e.modifiers & Qt.ControlModifier) && memo._clip) {
            memo._pasteClipboard();    // 粘贴（可跨页）
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

    // ===== 逻辑画板（参考分辨率 1920x1080）+ 等比缩放铺满窗口 =====
    // 内容（墨迹/对象/点阵）都在 1920x1080 逻辑坐标里绘制并存储（坐标稳定、可持久化、所有复制/选区
    // 逻辑不变）；整块画板按 min(W/1920,H/1080) 等比缩放并居中——窗口越大画板越大（支持 >1920 全屏），
    // 始终 16:9 不变形，非 16:9 窗口留黑边。鼠标事件经缩放变换自动映射回逻辑坐标，故逻辑无需改动。
    readonly property int boardW: 1920
    readonly property int boardH: 1080
    readonly property real boardFit: Math.min(width / boardW, height / boardH)

    Item {
        id: board
        width: memo.boardW
        height: memo.boardH
        transformOrigin: Item.TopLeft
        scale: memo.boardFit
        x: (memo.width - memo.boardW * memo.boardFit) / 2
        y: (memo.height - memo.boardH * memo.boardFit) / 2

    // ===== L2 黑板点阵（白点 10.5% / 24px 平铺）=====
    MemoDotTexture {
        x: 0; y: 0; width: memo.boardW; height: memo.boardH
        dotColor: memo.style ? memo.style.memoDotColor : Qt.rgba(1, 1, 1, 0.105)
        pitch: memo.style ? memo.style.memoDotPitch : 24
        dotRadius: memo.style ? memo.style.memoDotRadius : 1
    }

    // ===== 三层分离骨架（G3 / §5.2）=====
    // z 次序：透明墨水层（画笔/橡皮 destination-out，只擦墨水不擦点阵/便签）→ 对象层（便签 z 高于文字）。
    Item {
        id: inkLayerHost
        x: 0; y: 0; width: memo.boardW; height: memo.boardH
        MemoInkCanvas {
            id: inkCanvas
            anchors.fill: parent
            style: memo.style
            tool: toolbar.currentTool
            penColor: toolbar.inkColor        // gap #2
            penWidth: toolbar.penWidth        // gap #3
            eraserWidth: toolbar.eraserWidth  // gap #3
            onStrokeEnded: { memo.scheduleSave(); memo._histRecord(); }
        }
    }
    Item {
        id: objectLayerHost
        x: 0; y: 0; width: memo.boardW; height: memo.boardH

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

        // 浮动墨迹：移动/缩放选区时显示被抬起的那块（在对象之下，与真实墨迹同层级）。
        Image {
            id: floatInk
            visible: memo._selDragging && memo._floatUrl.length > 0
            source: memo._floatUrl
            sourceClipRect: memo._floatSrc
            x: memo.selRect.x; y: memo.selRect.y
            width: memo.selRect.width; height: memo.selRect.height
            smooth: true
            cache: false
            // 浮层就绪后才清源区：拖动瞬间画布仍有墨迹、浮层无缝盖上，避免"消失"。
            onStatusChanged: {
                if (status === Image.Ready && memo._selDragging && !memo._floatCleared) {
                    inkCanvas.clearRegion(memo._floatSrc.x, memo._floatSrc.y,
                                          memo._floatSrc.width, memo._floatSrc.height);
                    memo._floatCleared = true;
                }
            }
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
                        it.author = model.osign || "";
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
                            objectModel.setProperty(ldr.index, "osign", ldr.obj.author);
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

            // 移动：拖盒子主体（带着选中对象 + 浮动墨迹一起走）。
            MouseArea {
                id: moveMa
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeAllCursor
                property real gx0: 0
                property real gy0: 0
                onPressed: function (m) {
                    var p = mapToItem(objectLayerHost, m.x, m.y);
                    gx0 = p.x; gy0 = p.y;
                    memo._beginSelGesture();
                }
                onPositionChanged: function (m) {
                    var p = mapToItem(objectLayerHost, m.x, m.y);
                    memo._applyMove(p.x - gx0, p.y - gy0);
                }
                onReleased: memo._commitSelGesture()
                onCanceled: memo._commitSelGesture()
            }
            // 缩放：右下角把手（对象 + 浮动墨迹按比例缩放）。
            MouseArea {
                width: 22; height: 22
                anchors { right: parent.right; bottom: parent.bottom }
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeFDiagCursor
                onPressed: function (m) { memo._beginSelGesture(); }
                onPositionChanged: function (m) {
                    var p = mapToItem(objectLayerHost, m.x, m.y);
                    memo._applyScale(p.x - memo._boxStart.x, p.y - memo._boxStart.y);
                }
                onReleased: memo._commitSelGesture()
                onCanceled: memo._commitSelGesture()
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.92)
                    border.width: 1; border.color: Qt.rgba(4 / 255, 8 / 255, 14 / 255, 0.5)
                }
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
    }   // board（逻辑画板：1920x1080 等比缩放居中）

    // ===== Chrome：工具条 + 档案袋（灵动岛：默认藏起只露小边，鼠标靠近顶部再冒出）=====
    // 顶栏是否展开：开启状态下，档案袋展开中、或鼠标靠近顶部（且非绘制/框选手势）时显示。
    // topHover = 顶部空白感应区；toolbar.barHovered = 悬在工具条本身（工具条现置于 topZone 之上，
    // 移到条上时 topZone 收不到 hover，需 barHovered 维持展开，否则一靠近按钮就收起）。
    readonly property bool chromeShown: open && (pageFolder.openState
                                        || ((topHover.hovered || toolbar.barHovered)
                                            && !inkCanvas.drawing && !_selDragging))

    // 顶部悬停感应区：被动 HoverHandler，不拦点击/拖动，让顶部空间仍可画/拖。
    Item {
        id: topZone
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 78
        z: 4500
        HoverHandler { id: topHover }
    }

    MemoToolbar {
        id: toolbar
        // 置于顶部感应区 topZone(z4500) 之上：否则 topZone 接管 hover，按钮收不到 → 悬停无高光
        // （历史 bug：悬停无动效、按下才显且卡死）。弹层(番茄/日期)再叠到工具条之上。
        z: 4520
        anchors.horizontalCenter: parent.horizontalCenter
        // 收起时上移、只露 10px 提示边；靠近顶部冒出到 y=14。
        y: memo.chromeShown ? 14 : -(height - 10)
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        style: memo.style
        shown: memo.open
        revealed: memo.chromeShown
        onExitRequested: memo.open = false
        onPomodoroRequested: pomodoro.shown = !pomodoro.shown
        onClearRequested: clearConfirm.open = true
        onCurrentToolChanged: if (currentTool !== "select") memo._clearSelection()
    }

    // 番茄钟浮窗 + 完成弹层。
    PomodoroWidget {
        id: pomodoro
        z: 4540               // 叠在工具条(z4520)之上
        style: memo.style
        store: memo.store     // gap #10：番茄状态持久化（单独键 memoryLakeMemoPomodoro）
        shown: false
        onCompleted: function (v) { pomodoroComplete.variant = v; pomodoroComplete.shown = true; }
    }
    PomodoroCompleteOverlay {
        id: pomodoroComplete
        z: 4560               // 全屏庆祝，必须盖过工具条
        style: memo.style
        onClosed: pomodoroComplete.shown = false
    }

    // 便签截止日期选择器（单例；由便签截止行触发，居中弹出）。
    MemoDatePicker {
        id: duePicker
        z: 4560               // 居中弹层，盖过工具条
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

    // 清空确认（gap #4）：危险动作二次确认（撤销可恢复，仍给一道保险）。
    Item {
        id: clearConfirm
        anchors.fill: parent
        z: 4570
        property bool open: false
        visible: open || opacity > 0.01
        opacity: open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.34)
            MouseArea { anchors.fill: parent; onClicked: clearConfirm.open = false }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 300; height: 150; radius: 16
            gradient: Gradient {
                GradientStop { position: 0; color: memo.style ? memo.style.memoBoardTop : Qt.rgba(0.035, 0.043, 0.07, 0.97) }
                GradientStop { position: 1; color: memo.style ? memo.style.memoBoardBottom : Qt.rgba(0.024, 0.031, 0.055, 0.98) }
            }
            border.width: 1
            border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
            MouseArea { anchors.fill: parent }   // 拦截穿透
            Column {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 14
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: "清空本页墨迹？"
                    color: Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.94)
                    font.pixelSize: 16; font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "仅清当前页手绘，便签 / 文字保留。可 Ctrl+Z 撤销。"
                    color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.55); font.pixelSize: 12
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Rectangle {
                        width: 96; height: 34; radius: 10
                        color: cancelH.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
                        Text { anchors.centerIn: parent; text: "取消"; color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.82); font.pixelSize: 14 }
                        MouseArea { id: cancelH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: clearConfirm.open = false }
                    }
                    Rectangle {
                        width: 96; height: 34; radius: 10
                        color: clearGoH.containsMouse ? Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.85) : Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.55)
                        Text { anchors.centerIn: parent; text: "清空"; color: "#FFFFFF"; font.pixelSize: 14; font.weight: Font.DemiBold }
                        MouseArea { id: clearGoH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { memo.clearCurrentCanvas(); clearConfirm.open = false } }
                    }
                }
            }
        }
    }

    // 右上档案袋（多页切换）。
    MemoPageFolder {
        id: pageFolder
        z: 4520               // 同工具条，置于 topZone 之上，hover/点击不被顶部感应区吞掉
        anchors { right: parent.right; rightMargin: 18 }
        // 灵动岛：收起时上移只露 10px（前盖 48 高 → -38），展开/靠近顶部时落到 y=18。
        y: memo.chromeShown ? 18 : -38
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        style: memo.style
        pageLabels: memo.pageLabels
        currentIndex: memo.currentPage
        visible: memo.open
        opacity: memo.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
        onSwitchTo: function (i) { memo.switchPage(i); }
        onAddPageRequested: memo.addPage()
        onDeletePageRequested: function (i) { memo.deletePage(i); }
        onRenamePageRequested: function (i, name) { memo.renamePage(i, name); }
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
