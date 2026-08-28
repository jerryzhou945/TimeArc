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
