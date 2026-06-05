import QtQuick

// 像素番茄精灵（v88 .pixel-tomato）。v88 用 ~80 个 box-shadow 偏移在 8px 网格拼像素画，QML 无等价；
// 这里按手册「Canvas/Repeater<Rectangle> 在网格上重绘」的方案，程序化在 N×N 网格 fillRect 出
// 红身 + 高光 + 底暗 + 绿叶/茎，硬边（smooth/antialias off）。色取 MemoryLakeStyle 番茄令牌。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §4.6 / §5.3。
Canvas {
    id: tomato

    property MemoryLakeStyle style
    property int cells: 16

    readonly property color cBody: style ? style.pomodoroRed : "#FF5B5E"
    readonly property color cShade: style ? style.pomodoroRedDark : "#D8413F"
    readonly property color cHi: style ? style.pomodoroRedHi : "#FF9A8A"
    readonly property color cLeaf: style ? style.pomodoroLeaf : "#5FBF6B"
    readonly property color cLeafDark: style ? style.pomodoroLeafDark : "#3E8F4E"

    antialiasing: false

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var n = cells, cs = width / n;
        var cx = (n - 1) / 2.0, cy = n / 2.0 + 1.0;
        var rx = n * 0.44, ry = n * 0.40;
        function put(gx, gy, c) {
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, c.a);
            ctx.fillRect(Math.floor(gx * cs), Math.floor(gy * cs), Math.ceil(cs), Math.ceil(cs));
        }
        for (var gy = 0; gy < n; gy++) {
            for (var gx = 0; gx < n; gx++) {
                var dx = (gx - cx) / rx, dy = (gy - cy) / ry;
                var inBody = (dx * dx + dy * dy) <= 1.0;
                if (inBody) {
                    if (dx < -0.25 && dy < -0.10) put(gx, gy, cHi);        // 左上高光
                    else if (dy > 0.40) put(gx, gy, cShade);                // 底部暗
                    else put(gx, gy, cBody);
                }
            }
        }
        // 顶部绿叶 + 茎（在番茄上缘中央）。
        var lcx = Math.round(cx);
        put(lcx, 1, cLeafDark);                 // 茎
        put(lcx - 1, 2, cLeaf); put(lcx, 2, cLeafDark); put(lcx + 1, 2, cLeaf);
        put(lcx - 2, 3, cLeaf); put(lcx + 2, 3, cLeaf);
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCellsChanged: requestPaint()
    Component.onCompleted: requestPaint()
    Connections { target: tomato; function onCBodyChanged() { tomato.requestPaint() } }
}
