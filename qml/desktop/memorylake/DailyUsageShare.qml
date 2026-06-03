import QtQuick
import "../components/AppVisual.js" as AppVisual

// Daily Usage Share：今日软件使用占比（甜甜圈 + 图例）。
// 切片来自 dailyCardService.memoryLakeDay().usageShare（前 4 app + 其他），QML 只渲染。
Rectangle {
    id: panel

    property MemoryLakeStyle style
    property var share: []          // [{name, appId, path, iconColors, percent, isOther}]
    property string total: ""

    // 解析为带颜色的切片：命名项用图标主色 / AppVisual 兜底；其他用中性灰。
    readonly property var slices: {
        var out = [];
        for (var i = 0; i < share.length; i++) {
            var s = share[i];
            var col;
            if (s.isOther) {
                col = style && style.night ? "#5C6577" : "#9AA1B0";
            } else if (s.iconColors && s.iconColors.length > 0) {
                col = s.iconColors[0];
            } else {
                col = AppVisual.appColor(s.appId, s.name, s.path);
            }
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

    radius: 18
    color: style ? style.cardBg : "#16181f"
    border.width: 1
    border.color: style ? style.cardBorder : "#2a2d36"
    clip: true

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
                }
                Text {
                    text: "今日软件使用占比"
                    color: style ? style.textPrimary : "#fff"
                    font.pixelSize: 15
                    font.bold: true
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: panel.total
                visible: panel.total.length > 0
                color: style ? style.textPrimary : "#fff"
                font.pixelSize: 18
                font.bold: true
            }
        }

        // 甜甜圈 + 图例
        Row {
            width: parent.width
            spacing: 14

            Canvas {
                id: pie
                width: 104
                height: 104
                anchors.verticalCenter: parent.verticalCenter
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
