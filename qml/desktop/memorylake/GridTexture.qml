import QtQuick

// 网格纸纹（设计稿 .today-briefing::before / .today-items-compact::before / .daily-pie-panel::before）：
// 纵横发丝线交叉成「笔记本方格」底纹，整层低不透明。纯 Canvas 静态纹理（无 FBO / 无模块依赖 / 不随帧刷新）。
// 用法：盖在玻璃面板底色之上、内容之下；lineColor 自带 alpha（取 ml.gridLine 令牌），cell 为格距，
// textureOpacity 为整层不透明度（设计稿 .18~.45）。
Canvas {
    id: grid

    property color lineColor: "#ffffff"
    property int cell: 28
    property real textureOpacity: 0.18

    opacity: textureOpacity

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width, h = height;
        if (w <= 0 || h <= 0 || cell <= 0) return;
        ctx.lineWidth = 1;
        ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, lineColor.a);
        ctx.beginPath();
        for (var x = 0.5; x <= w; x += cell) { ctx.moveTo(x, 0); ctx.lineTo(x, h); }
        for (var y = 0.5; y <= h; y += cell) { ctx.moveTo(0, y); ctx.lineTo(w, y); }
        ctx.stroke();
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections { target: grid; function onLineColorChanged() { grid.requestPaint() } }
}
