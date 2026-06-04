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
