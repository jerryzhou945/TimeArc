import QtQuick

// 网格纸纹（设计稿 .today-briefing::before / .today-items-compact::before / .daily-pie-panel::before）：
// 纵横发丝线交叉成「笔记本方格」底纹，整层低不透明。用法不变：盖在玻璃面板底色之上、内容之下；
// lineColor 自带 alpha（取 ml.gridLine 令牌），cell 为格距，textureOpacity 为整层不透明度（设计稿 .18~.45）。
//
// 实现：只画**一格**，再交给 Image.Tile 平铺。原先是一张铺满的 Canvas，每次 onWidthChanged /
// onHeightChanged 都重画整幅——全屏面板 cell=26 时是上百条线，而且 resize 的每一帧都来一次。
// 现在尺寸变化对绘制是零成本（平铺由渲染器做），只有 cell / lineColor 变了才重画那一格。
// 落点与旧实现一致：瓦片内左沿 / 上沿各一条 0.5px 线，平铺后即 x = 0.5, cell+0.5, … 与
// 旧的 `for (x = 0.5; x <= w; x += cell)` 逐格对齐。
Item {
    id: grid

    property color lineColor: "#ffffff"
    property int cell: 28
    property real textureOpacity: 0.18

    opacity: textureOpacity

    Canvas {
        id: tile
        width: Math.max(1, grid.cell)
        height: Math.max(1, grid.cell)
        visible: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;
            ctx.lineWidth = 1;
            ctx.strokeStyle = Qt.rgba(grid.lineColor.r, grid.lineColor.g,
                                      grid.lineColor.b, grid.lineColor.a);
            ctx.beginPath();
            ctx.moveTo(0.5, 0); ctx.lineTo(0.5, height);
            ctx.moveTo(0, 0.5); ctx.lineTo(width, 0.5);
            ctx.stroke();
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
        Connections { target: grid; function onLineColorChanged() { tile.requestPaint() } }
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
