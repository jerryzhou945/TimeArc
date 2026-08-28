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
        // 重入守卫：toDataURL() 会同步逼出一次绘制，那次绘制又发 painted —— 不挡住就是
        // 无限递归（实测 "RangeError: Maximum call stack size exceeded"）。
        property bool exporting: false
        onPainted: {
            if (tile.exporting) return;
            tile.exporting = true;
            tiled.source = tile.toDataURL();
            tile.exporting = false;
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
