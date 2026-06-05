import QtQuick

// 柔光圆：平滑径向渐变（Canvas 一次绘制 → 纹理缓存）。
// 取代旧的「实心圆 + MultiEffect 模糊」——后者中心是一块平的实心盘、只有边缘被模糊，读作
// 「带毛边的硬盘」而非柔光，且大半径高斯模糊会出现一圈圈 banding（一层一层）。
// 径向渐变：中心最亮 → 边缘透明，自然柔和、无 banding、尺寸精确可控、无 FBO、静态缓存。
Item {
    id: glow

    property color glowColor: "#9FE7EE"
    property real glowOpacity: 0.18
    property real blurAmount: 1.0   // 兼容旧调用点签名（已不再使用）

    Canvas {
        id: cv
        anchors.fill: parent
        opacity: glow.glowOpacity
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height;
            if (w <= 0 || h <= 0) return;
            var cx = w / 2, cy = h / 2;
            var rmax = Math.max(w, h) / 2;
            if (rmax <= 0) return;
            var c = glow.glowColor;
            var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, rmax);
            // 平滑衰减（中心实 → 半程 → 边缘透明），无硬盘感
            g.addColorStop(0.0,  Qt.rgba(c.r, c.g, c.b, 1.0));
            g.addColorStop(0.40, Qt.rgba(c.r, c.g, c.b, 0.52));
            g.addColorStop(0.72, Qt.rgba(c.r, c.g, c.b, 0.13));
            g.addColorStop(1.0,  Qt.rgba(c.r, c.g, c.b, 0.0));
            ctx.fillStyle = g;
            // 非正方时按宽高把圆形渐变压成椭圆，使其在四边都恰好淡出到透明（不硬裁）
            ctx.save();
            ctx.translate(cx, cy);
            ctx.scale(w / (2 * rmax), h / (2 * rmax));
            ctx.translate(-cx, -cy);
            ctx.fillRect(cx - rmax, cy - rmax, 2 * rmax, 2 * rmax);
            ctx.restore();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: glow; function onGlowColorChanged() { cv.requestPaint() } }
    }
}
