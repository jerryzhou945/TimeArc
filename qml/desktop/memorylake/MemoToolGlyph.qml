import QtQuick

// 备忘工具图标。v88 里画笔是 CSS 伪元素（clip-path 铅笔，QML 无 filter 等价），其余是描边 SVG；
// 这里统一用 Canvas 手绘线描近似（pen/eraser/note）+ 字形 T（text），按 glyphColor 重着色
// （暗态亮灰 / active 近黑）。详见 docs/memory-lake-memo-render-pipeline-replication.md §1.2。
Item {
    id: g

    property string kind: "pen"          // select | pen | eraser | note | text
    property color glyphColor: "white"

    width: 20; height: 20

    Text {
        anchors.centerIn: parent
        visible: g.kind === "text"
        text: "T"
        font.pixelSize: 18
        font.bold: true
        color: g.glyphColor
    }

    Canvas {
        id: cv
        anchors.fill: parent
        visible: g.kind !== "text"
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var c = g.glyphColor;
            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, c.a);
            ctx.lineWidth = 1.8;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            var w = width, h = height;
            if (g.kind === "pen") {
                ctx.beginPath();
                ctx.moveTo(w * 0.72, h * 0.18);
                ctx.lineTo(w * 0.30, h * 0.60);
                ctx.lineTo(w * 0.20, h * 0.80);
                ctx.lineTo(w * 0.40, h * 0.70);
                ctx.lineTo(w * 0.82, h * 0.28);
                ctx.closePath();
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(w * 0.58, h * 0.32);
                ctx.lineTo(w * 0.68, h * 0.42);
                ctx.stroke();
            } else if (g.kind === "eraser") {
                ctx.save();
                ctx.translate(w * 0.5, h * 0.5);
                ctx.rotate(-0.5);
                ctx.translate(-w * 0.5, -h * 0.5);
                ctx.strokeRect(w * 0.26, h * 0.36, w * 0.48, h * 0.28);
                ctx.restore();
            } else if (g.kind === "select") {
                // 虚线框选 + 一支小箭头（“当鼠标框选”）。
                ctx.setLineDash([2.6, 2.2]);
                ctx.strokeRect(w * 0.20, h * 0.20, w * 0.46, h * 0.46);
                ctx.setLineDash([]);
                ctx.beginPath();
                ctx.moveTo(w * 0.50, h * 0.50);
                ctx.lineTo(w * 0.50, h * 0.86);
                ctx.lineTo(w * 0.59, h * 0.72);
                ctx.lineTo(w * 0.78, h * 0.74);
                ctx.closePath();
                ctx.stroke();
            } else if (g.kind === "note") {
                ctx.beginPath();
                ctx.moveTo(w * 0.24, h * 0.22);
                ctx.lineTo(w * 0.76, h * 0.22);
                ctx.lineTo(w * 0.76, h * 0.60);
                ctx.lineTo(w * 0.60, h * 0.78);
                ctx.lineTo(w * 0.24, h * 0.78);
                ctx.closePath();
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(w * 0.76, h * 0.60);
                ctx.lineTo(w * 0.60, h * 0.60);
                ctx.lineTo(w * 0.60, h * 0.78);
                ctx.stroke();
            } else if (g.kind === "clear") {
                // 垃圾桶（清空本页墨迹）。
                ctx.beginPath(); ctx.moveTo(w * 0.26, h * 0.30); ctx.lineTo(w * 0.74, h * 0.30); ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(w * 0.42, h * 0.30); ctx.lineTo(w * 0.44, h * 0.21);
                ctx.lineTo(w * 0.56, h * 0.21); ctx.lineTo(w * 0.58, h * 0.30); ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(w * 0.30, h * 0.35); ctx.lineTo(w * 0.345, h * 0.78);
                ctx.lineTo(w * 0.655, h * 0.78); ctx.lineTo(w * 0.70, h * 0.35); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(w * 0.44, h * 0.41); ctx.lineTo(w * 0.455, h * 0.72); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(w * 0.56, h * 0.41); ctx.lineTo(w * 0.545, h * 0.72); ctx.stroke();
            }
        }
        Component.onCompleted: requestPaint()
        onVisibleChanged: requestPaint()
        Connections {
            target: g
            function onGlyphColorChanged() { cv.requestPaint() }
            function onKindChanged() { cv.requestPaint() }
        }
    }
}
