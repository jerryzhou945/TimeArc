import QtQuick

// 黑板点阵底纹（设计稿 .memo-overlay 背景层 radial-gradient 白点 10.5% / 1px / 24px 平铺）。
// 盖在近黑黑板底之上、透明墨水 Canvas 之下；点要硬边（关 antialiasing），dotColor 自带 alpha
// （取 memoDotColor 令牌）。详见 docs/memory-lake-memo-render-pipeline-replication.md §4.2。
//
// 实现：同 GridTexture——只画**一个点**再平铺。原先每次尺寸变化都要画满 (w/pitch)×(h/pitch)
// 个圆弧：1920×1080 的黑板 pitch=24 就是 3600 个 arc，而且 resize 的每一帧都重来。
// 点位与旧实现一致：瓦片中心 (pitch/2, pitch/2)，平铺后即 pitch/2 + k*pitch。
Item {
    id: dots

    property color dotColor: Qt.rgba(1, 1, 1, 0.105)
    property real pitch: 24
    property real dotRadius: 1

    Canvas {
        id: tile
        width: Math.max(1, dots.pitch)
        height: Math.max(1, dots.pitch)
        visible: false
        antialiasing: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;
            ctx.fillStyle = Qt.rgba(dots.dotColor.r, dots.dotColor.g,
                                    dots.dotColor.b, dots.dotColor.a);
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, dots.dotRadius, 0, Math.PI * 2);
            ctx.fill();
        }
        // 快照必须**离开绘制周期**再取。toDataURL() 内部会 flush 并 delete 掉
        // QQuickContext2DCommandBuffer；在 onPainted 里同步调用，就是在
        // QQuickCanvasItem::updatePolish() 正在跑的这一轮里把它删掉，等这一轮自己再
        // flush 一次就是对同一块内存第二次 delete —— ASan 明确报 double-free，实测
        // 启动约四成概率崩溃（尤其当 AppKit 正开着嵌套模态循环时）。
        // Qt.callLater 把取快照推到本轮 polish/render 之后，两次 flush 不再交叠。
        // 见 journal/errors/20260828-073721-C-quick-canvas-double-free.md。
        //
        // 重入守卫仍然需要、且必须留在 onPainted 里（同步判断）：toDataURL() 会同步逼出
        // 一次绘制，那次绘制又发 painted。若把判断挪进 exportTile()，等它被调用时标志
        // 已经复位，就又成了无限递归（实测 "RangeError: Maximum call stack size exceeded"）。
        property bool exporting: false
        function exportTile() {
            tile.exporting = true;
            tiled.source = tile.toDataURL();
            tile.exporting = false;
        }
        onPainted: {
            if (tile.exporting) return;
            Qt.callLater(tile.exportTile);
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: dots
            function onDotColorChanged() { tile.requestPaint() }
            function onDotRadiusChanged() { tile.requestPaint() }
        }
    }

    Image {
        id: tiled
        anchors.fill: parent
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        smooth: false
    }
}
