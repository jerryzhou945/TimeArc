import QtQuick

// 黑板点阵底纹（设计稿 .memo-overlay 背景层 radial-gradient 白点 10.5% / 1px / 24px 平铺）。
// 复用 GridTexture 的「Canvas 静态纹理」结构，把纵横交叉发丝线换成填充圆点。盖在近黑黑板底之上、
// 透明墨水 Canvas 之下；点要硬边（关 antialiasing），dotColor 自带 alpha（取 memoDotColor 令牌）。
// 纯 Canvas 静态纹理：无 FBO / 无模块依赖 / 不随帧刷新。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §4.2。
Canvas {
    id: dots

    property color dotColor: Qt.rgba(1, 1, 1, 0.105)
    property real pitch: 24
    property real dotRadius: 1

    antialiasing: false

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width, h = height;
        if (w <= 0 || h <= 0 || pitch <= 0) return;
        ctx.fillStyle = Qt.rgba(dotColor.r, dotColor.g, dotColor.b, dotColor.a);
        for (var y = pitch / 2; y < h; y += pitch) {
            for (var x = pitch / 2; x < w; x += pitch) {
                ctx.beginPath();
                ctx.arc(x, y, dotRadius, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections { target: dots; function onDotColorChanged() { dots.requestPaint() } }
}
