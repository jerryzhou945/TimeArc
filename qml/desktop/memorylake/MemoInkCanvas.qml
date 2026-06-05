import QtQuick

// 黑板手绘墨水层（v88 .memo-canvas）。透明 Canvas，盖在点阵之上、对象层之下。
// 1:1 对齐 v88 栈式栅格模型（无矢量）：每个 pointermove 一段 moveTo→lineTo→stroke（无平滑/无缓冲）。
// 画笔 source-over 暖粉笔黄 #FFEC96@.96 lineWidth 4；橡皮 destination-out lineWidth 28（只擦墨水，
// 点阵是独立背景层、便签是独立对象层，故橡皮不伤它们）。round cap/join。
// 命中靠 tool 守卫：仅 pen/eraser 时 MouseArea 接管；note/text/none 时禁用以让点击落到对象层创建路径。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §4.3 / 功能文 §2.3。
Canvas {
    id: ink

    property MemoryLakeStyle style
    property string tool: "pen"      // pen | eraser | note | text | none
    // 一次落笔→抬笔算一笔；抬笔时发信号（持久化切片接：节流存 PNG）。
    signal strokeEnded()

    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative
    antialiasing: true

    property real lastX: 0
    property real lastY: 0
    property bool drawing: false

    function strokeSeg(x, y) {
        var ctx = getContext("2d");
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.globalCompositeOperation = (tool === "eraser") ? "destination-out" : "source-over";
        var c = style ? style.memoInk : Qt.rgba(1, 236 / 255, 150 / 255, 0.96);
        ctx.strokeStyle = (tool === "eraser") ? "rgba(0,0,0,1)" : Qt.rgba(c.r, c.g, c.b, c.a);
        ctx.lineWidth = (tool === "eraser") ? (style ? style.memoEraserWidth : 28)
                                            : (style ? style.memoPenWidth : 4);
        ctx.beginPath();
        ctx.moveTo(lastX, lastY);
        ctx.lineTo(x, y);
        ctx.stroke();
        lastX = x;
        lastY = y;
        ink.markDirty(Qt.rect(0, 0, width, height));
    }

    function clearAll() {
        var ctx = getContext("2d");
        ctx.reset();
        ink.markDirty(Qt.rect(0, 0, width, height));
    }

    // —— 选择工具：矩形区域操作（删除 / 复制；移动缩放复用回贴）——
    // 清除一块矩形区域的墨迹（一键删除选区）。
    function clearRegion(x, y, w, h) {
        var ctx = getContext("2d");
        ctx.clearRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
        ink.markDirty(Qt.rect(0, 0, width, height));
    }
    // 把全幅快照的源矩形 (sx,sy,sw,sh) 以 source-over 贴到目标矩形 (dx,dy,dw,dh)（可缩放）。
    // 关键：用 toDataURL 全幅快照 + drawImage 取源矩形，而非 getImageData——FBO 上 getImageData
    // 读不到 GPU 像素（实测返回空），但 toDataURL 能（与存档同路径）。
    property var _pendingStamps: []
    function _drawStamp(s) {
        var ctx = getContext("2d");
        ctx.globalCompositeOperation = "source-over";
        ctx.drawImage(s.url, s.sx, s.sy, s.sw, s.sh, s.dx, s.dy, s.dw, s.dh);
        ink.markDirty(Qt.rect(0, 0, width, height));
    }
    // 从指定全幅快照 url 的源矩形贴到目标矩形（移动/缩放回贴用：源是抬起前的快照）。
    function stampRegion(url, sx, sy, sw, sh, dx, dy, dw, dh) {
        if (!url || sw < 1 || sh < 1) return;
        var s = { url: url, sx: sx, sy: sy, sw: sw, sh: sh, dx: dx, dy: dy, dw: dw, dh: dh };
        if (ink.isImageLoaded(url)) _drawStamp(s);
        else { ink._pendingStamps.push(s); ink.loadImage(url); }
    }
    // 复制：以当前全幅快照为源。
    function copyRegionTo(sx, sy, sw, sh, dx, dy, dw, dh) {
        stampRegion(ink.toDataURL("image/png"), sx, sy, sw, sh, dx, dy, dw, dh);
    }

    // 持久化：导出当前位图 dataURL（持久化切片存盘用）。
    function exportDataURL() {
        return ink.toDataURL("image/png");
    }

    // 持久化：从 dataURL 恢复本页墨迹（identity 拉伸到全幅，对齐 v88 loadMemoCanvasForPage）。
    property string _pendingUrl: ""
    function loadFromDataURL(url) {
        clearAll();
        if (!url || url.length === 0) return;
        ink._pendingUrl = url;
        ink.loadImage(url);
    }
    onImageLoaded: {
        if (ink._pendingUrl.length > 0 && ink.isImageLoaded(ink._pendingUrl)) {
            var ctx = getContext("2d");
            ctx.globalCompositeOperation = "source-over";
            ctx.drawImage(ink._pendingUrl, 0, 0, width, height);
            ink.markDirty(Qt.rect(0, 0, width, height));
        }
        // 待贴图（复制/移动/缩放回贴）。
        if (ink._pendingStamps.length > 0) {
            var remain = [];
            for (var i = 0; i < ink._pendingStamps.length; i++) {
                var s = ink._pendingStamps[i];
                if (ink.isImageLoaded(s.url)) _drawStamp(s);
                else remain.push(s);
            }
            ink._pendingStamps = remain;
        }
    }

    MouseArea {
        anchors.fill: parent
        // 仅画笔/橡皮接管命中；其余工具禁用，让点击穿透到对象层（便签/文字创建）。
        enabled: ink.tool === "pen" || ink.tool === "eraser"
        cursorShape: Qt.CrossCursor
        onPressed: function (e) {
            ink.drawing = true;
            ink.lastX = e.x;
            ink.lastY = e.y;
            // 单点也落一个点（moveTo 到自身略偏移再 stroke），与 v88 即时绘一致。
            ink.strokeSeg(e.x + 0.01, e.y + 0.01);
        }
        onPositionChanged: function (e) { if (ink.drawing) ink.strokeSeg(e.x, e.y); }
        onReleased: { if (ink.drawing) { ink.drawing = false; ink.strokeEnded(); } }
        onCanceled: { if (ink.drawing) { ink.drawing = false; ink.strokeEnded(); } }
    }
}
