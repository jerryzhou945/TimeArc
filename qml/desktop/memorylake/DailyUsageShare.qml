import QtQuick
import QtQuick.Effects

// Daily Usage Share：今日软件使用占比（甜甜圈 + 图例）。
// 切片来自 dailyCardService.memoryLakeDay().usageShare（前 4 app + 其他），QML 只渲染。
Rectangle {
    id: panel

    property MemoryLakeStyle style
    property var share: []          // [{name, appId, path, iconColors, percent, isOther}]
    property string total: ""

    // 扇区分类色（R2 / Cookbook §4.3）：按位次取 aqua/violet/gold/pink，其它取 slate；
    // 图例点与扇区共用同一 color，严格对齐。全部取自 ml 令牌（G1）。
    readonly property var sharePalette: style ? [style.aqua, style.violet, style.shareGold, style.sharePink]
                                              : ["#9FE7EE", "#9B8BFF", "#FFE6A3", "#FF7A9A"]
    readonly property var slices: {
        var out = [];
        for (var i = 0; i < share.length; i++) {
            var s = share[i];
            var col = s.isOther ? (style ? style.shareOther : "#6F7C91")
                                : sharePalette[Math.min(i, sharePalette.length - 1)];
            out.push({ name: s.name, percent: s.percent, color: col });
        }
        return out;
    }
    readonly property bool hasData: {
        for (var i = 0; i < slices.length; i++)
            if (slices[i].percent > 0) return true;
        return false;
    }

    onSlicesChanged: pie.requestPaint()

    radius: style ? style.radiusCard : 18
    color: style ? style.cardBg : "#16181f"
    border.width: 1
    border.color: style ? style.cardBorder : "#2a2d36"
    clip: true

    // 边缘光对（R4/L4）：顶沿内高光 + 更亮底沿，静止无投影。左右内缩半径，不越出圆角拐角。
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 1; leftMargin: panel.radius; rightMargin: panel.radius }
        height: 1
        color: panel.style ? (panel.style.night ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(1, 1, 1, 0.55))
                           : Qt.rgba(1, 1, 1, 0.035)
    }
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                  bottomMargin: 1; leftMargin: panel.radius; rightMargin: panel.radius }
        height: 1
        color: panel.style ? panel.style.panelBorderStrong : Qt.rgba(1, 1, 1, 0.13)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // 标题行
        Item {
            width: parent.width
            height: 38
            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: "Daily Usage Share"
                    color: style ? style.aqua : "#9FE7EE"
                    font.pixelSize: 11
                    opacity: 0.85
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.0
                }
                Text {
                    text: "今日软件使用占比"
                    color: style ? style.textPrimary : "#fff"
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }

        // 甜甜圈 + 图例
        Row {
            width: parent.width
            spacing: 14

            // 甜甜圈 + 中心总时数（R2：aqua 发光 + tabular-nums，夜开昼关）。
            // 注：项目未链接 Qt5Compat，发光改用已在用的 QtQuick.Effects.MultiEffect 模糊一份 aqua 文字副本
            // 充当辉光（X5 意图：发光文字夜开昼关），避免改动 frozen 的顶层 CMakeLists 引入 Qt5Compat。
            Item {
                width: 104
                height: 104
                anchors.verticalCenter: parent.verticalCenter

                // aqua 文字副本（隐藏，仅供 MultiEffect 取样）
                Text {
                    id: glowSrc
                    anchors.centerIn: parent
                    text: panel.total
                    color: panel.style ? panel.style.aqua : "#9FE7EE"
                    font.pixelSize: 17; font.weight: 900; font.letterSpacing: -1
                    font.features: { "tnum": 1 }
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: glowSrc
                    source: glowSrc
                    visible: panel.style && panel.style.night && panel.total.length > 0
                    blurEnabled: true; blur: 1.0; blurMax: 20; autoPaddingEnabled: true
                }

            Canvas {
                id: pie
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var cx = width / 2, cy = height / 2;
                    var r = width / 2 - 2, inner = r * 0.6;
                    var trackCol = style ? style.trackBg : "#ffffff14";
                    var totalPct = 0;
                    for (var i = 0; i < panel.slices.length; i++)
                        totalPct += panel.slices[i].percent;
                    if (totalPct <= 0) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.fillStyle = trackCol;
                        ctx.fill();
                        ctx.globalCompositeOperation = "destination-out";
                        ctx.beginPath();
                        ctx.arc(cx, cy, inner, 0, 2 * Math.PI);
                        ctx.fill();
                        ctx.globalCompositeOperation = "source-over";
                        return;
                    }
                    var start = -Math.PI / 2;
                    for (var j = 0; j < panel.slices.length; j++) {
                        var frac = panel.slices[j].percent / totalPct;
                        if (frac <= 0) continue;
                        var end = start + frac * 2 * Math.PI;
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.arc(cx, cy, r, start, end);
                        ctx.closePath();
                        ctx.fillStyle = panel.slices[j].color;
                        ctx.fill();
                        start = end;
                    }
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.beginPath();
                    ctx.arc(cx, cy, inner, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.globalCompositeOperation = "source-over";
                }
            }

            // 中心总时数（crisp，叠在甜甜圈透明孔上、辉光之上，weight 900 + tabular-nums）
            Text {
                anchors.centerIn: parent
                text: panel.total
                visible: panel.total.length > 0
                color: panel.style ? panel.style.textPrimary : "#fff"
                font.pixelSize: 17; font.weight: 900; font.letterSpacing: -1
                font.features: { "tnum": 1 }
            }
            }

            Column {
                width: parent.width - 104 - 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Repeater {
                    model: panel.slices
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            width: parent.width - 10 - 8 - pctText.implicitWidth - 8
                            text: modelData.name
                            color: style ? style.textPrimary : "#fff"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: pctText
                            text: modelData.percent + "%"
                            color: style ? style.textSecondary : "#bbb"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Text {
                    visible: !panel.hasData
                    text: "暂无占比数据"
                    color: style ? style.textTertiary : "#888"
                    font.pixelSize: 12
                }
            }
        }
    }
}
