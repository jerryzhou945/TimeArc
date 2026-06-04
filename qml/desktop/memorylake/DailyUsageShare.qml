import QtQuick
import QtQuick.Effects

// Daily Theme Share：今日主题使用占比（霓虹甜甜圈 + 图例 + 洞察）。
// v88 复刻（设计稿 .daily-pie-panel）：玻璃底 + aqua/violet 双角径向辉光 + 26px 方格底纹；
// 甜甜圈 = 真实占比 Canvas 扇区 + **0 0 32px 彩色霓虹外晕（MultiEffect）** + 呼吸光环 +
// 雕刻暗色中心孔（aqua 顶光）+ 中心总时数发光；图例点带同色霓虹辉光；底部洞察胶囊。
// 切片来自 dailyCardService.memoryLakeDay().usageShare：按本地分类器的**主题分类**(开发/社交/游戏/视频…)
// 汇总，前 4 类 + 其他；QML 只渲染（G10 不造假）。
Rectangle {
    id: panel

    property MemoryLakeStyle style
    property var share: []          // [{name, appId, path, iconColors, percent, isOther}]
    property string total: ""

    readonly property real gs: style ? style.glowStrength : 1.0

    // 扇区分类色（R2 / Cookbook §4.3）：按位次取 aqua/violet/gold/pink，其它取 slate；图例点与扇区共用同 color。
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
    // 洞察：由真实最高占比切片派生的事实标签（非 Mock）。
    readonly property string insightText: hasData && slices.length > 0
        ? ("今日主题：" + slices[0].name + " 占比最高（" + slices[0].percent + "%）") : ""

    onSlicesChanged: pie.requestPaint()

    radius: 22
    color: style ? (style.night ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.72)) : "#16181f"
    border.width: 1
    border.color: style ? (style.night ? Qt.rgba(1, 1, 1, 0.085) : Qt.rgba(0.40, 0.34, 0.28, 0.18)) : "#2a2d36"
    // 圆角裁切交给下方 RoundedFrame；clip:true 只裁矩形会让方格在圆角处戳出方角「色块」。
    clip: false
    antialiasing: true

    // 26px 方格底纹（设计稿 ::before grid）。霓虹质感由甜甜圈自身的彩色外晕承担，
    // **面板四角不再放径向光斑**（泛光修复）；方格用 RoundedFrame round-clip 收在圆角内。
    RoundedFrame {
        anchors.fill: parent
        radius: panel.radius
        GridTexture {
            anchors.fill: parent
            lineColor: panel.style ? panel.style.gridLine : Qt.rgba(1, 1, 1, 0.032)
            cell: 26
            textureOpacity: panel.style && !panel.style.night ? 0.45 : 0.2
        }
    }

    // 边缘光对：顶沿内高光 + 更亮底沿。左右内缩半径，不越圆角。
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 1; leftMargin: panel.radius; rightMargin: panel.radius }
        height: 1
        color: panel.style ? (panel.style.night ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.55))
                           : Qt.rgba(1, 1, 1, 0.05)
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
        spacing: 10

        // 标题行：kicker/title 左 + 总时数 pill 右
        Item {
            width: parent.width
            height: 40
            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: "Daily Theme Share"
                    color: panel.style ? panel.style.glowCyan : "#8EDFFF"
                    font.pixelSize: 11
                    font.weight: 800
                    font.letterSpacing: 0.55
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    text: "今日主题使用占比"
                    color: panel.style ? panel.style.textPrimary : "#fff"
                    font.pixelSize: 16
                    font.weight: 800
                    font.letterSpacing: -0.38
                }
            }
            // 总时数 pill（设计稿 .daily-pie-total）
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: panel.total.length > 0
                width: Math.max(60, pillT.implicitWidth + 18)
                height: 36
                radius: 14
                color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.10) : Qt.rgba(0.56, 0.87, 1, 0.10)
                border.width: 1
                border.color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.15) : Qt.rgba(0.56, 0.87, 1, 0.15)
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                    height: 1; color: Qt.rgba(1, 1, 1, 0.06)
                }
                Text {
                    id: pillT
                    anchors.centerIn: parent
                    text: panel.total
                    color: panel.style ? panel.style.textPrimary : "#fff"
                    font.pixelSize: 16; font.weight: 900
                    font.features: { "tnum": 1 }
                }
            }
        }

        // 甜甜圈 + 图例
        Row {
            width: parent.width
            spacing: 14

            // ===== 霓虹甜甜圈 =====
            Item {
                id: donutBox
                width: 118
                height: 118
                anchors.verticalCenter: parent.verticalCenter

                readonly property real cx: width / 2
                readonly property real cy: height / 2
                readonly property real rOuter: width / 2 - 3
                readonly property real rInner: rOuter * 0.70

                // (1) 整体 aqua 柔晕（设计稿 0 0 32px rgba(142,223,255,.12) 外辉光的底色）
                GlowCircle {
                    anchors.centerIn: parent
                    width: parent.width * 1.35; height: parent.height * 1.35
                    glowColor: panel.style ? panel.style.glowCyan : "#8EDFFF"
                    glowOpacity: 0.16 * panel.gs
                    visible: panel.hasData
                }

                // (2) 彩色霓虹外晕：MultiEffect 模糊一份甜甜圈扇区，按扇区色外溢成霓虹（夜开昼弱）
                MultiEffect {
                    anchors.fill: pie
                    source: pie
                    visible: panel.hasData && panel.gs > 0.6
                    opacity: 0.85
                    blurEnabled: true; blur: 1.0; blurMax: 28; autoPaddingEnabled: true
                }

                // (3) 呼吸光环（设计稿 .daily-pie-ring，scale .98↔1.035 / opacity .42↔.78，2.8s）
                Rectangle {
                    id: ring
                    anchors.centerIn: parent
                    width: parent.width + 16; height: parent.height + 16
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.14) : Qt.rgba(0.56, 0.87, 1, 0.14)
                    visible: panel.hasData
                    SequentialAnimation on scale {
                        running: ring.visible && panel.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.98; to: 1.035; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.035; to: 0.98; duration: 1400; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on opacity {
                        running: ring.visible && panel.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.42; to: 0.78; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.78; to: 0.42; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }

                // (4) 扇区（真实占比）。layer.enabled 供 MultiEffect 取样；透明孔在 destination-out 打出。
                Canvas {
                    id: pie
                    anchors.fill: parent
                    layer.enabled: true
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var cx = donutBox.cx, cy = donutBox.cy;
                        var r = donutBox.rOuter, inner = donutBox.rInner;
                        var trackCol = style ? style.trackBg : "#ffffff14";
                        var totalPct = 0;
                        for (var i = 0; i < panel.slices.length; i++)
                            totalPct += panel.slices[i].percent;
                        if (totalPct <= 0) {
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                            ctx.fillStyle = trackCol; ctx.fill();
                            ctx.globalCompositeOperation = "destination-out";
                            ctx.beginPath(); ctx.arc(cx, cy, inner, 0, 2 * Math.PI); ctx.fill();
                            ctx.globalCompositeOperation = "source-over";
                            return;
                        }
                        var start = -Math.PI / 2;
                        for (var j = 0; j < panel.slices.length; j++) {
                            var frac = panel.slices[j].percent / totalPct;
                            if (frac <= 0) continue;
                            var end = start + frac * 2 * Math.PI;
                            ctx.beginPath(); ctx.moveTo(cx, cy);
                            ctx.arc(cx, cy, r, start, end); ctx.closePath();
                            ctx.fillStyle = panel.slices[j].color; ctx.fill();
                            start = end;
                        }
                        ctx.globalCompositeOperation = "destination-out";
                        ctx.beginPath(); ctx.arc(cx, cy, inner, 0, 2 * Math.PI); ctx.fill();
                        ctx.globalCompositeOperation = "source-over";
                    }
                }

                // (5) 外缘 1px 描边（设计稿 0 0 0 1px white .07）
                Rectangle {
                    anchors.centerIn: parent
                    width: donutBox.rOuter * 2 + 2; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    visible: panel.hasData
                }

                // (6) 雕刻中心孔：暗色竖渐变 + 顶部 aqua 高光 + 内沿 1px 高光（设计稿 ::before）
                Rectangle {
                    id: hole
                    anchors.centerIn: parent
                    width: donutBox.rInner * 2; height: width; radius: width / 2
                    clip: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: panel.style ? panel.style.donutHoleTop : "#141822" }
                        GradientStop { position: 1; color: panel.style ? panel.style.donutHoleBottom : "#0A0D15" }
                    }
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.065)
                    visible: panel.hasData
                    // 顶部 aqua 光源（radial 50% 40%）
                    GlowCircle {
                        width: parent.width * 1.1; height: parent.height * 1.1
                        x: parent.width / 2 - width / 2
                        y: parent.height * 0.40 - height / 2
                        glowColor: panel.style ? panel.style.glowCyan : "#8EDFFF"
                        glowOpacity: 0.14 * panel.gs
                    }
                    // 内沿顶部 1px 高光
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 2; leftMargin: 8; rightMargin: 8 }
                        height: 1; color: Qt.rgba(1, 1, 1, 0.07)
                    }
                }

                // (7) 中心总时数发光副本（夜开）+ crisp 主字
                Text {
                    id: glowSrc
                    anchors.centerIn: parent
                    text: panel.total
                    color: panel.style ? panel.style.glowCyan : "#8EDFFF"
                    font.pixelSize: 21; font.weight: 900; font.letterSpacing: -0.55
                    font.features: { "tnum": 1 }
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: glowSrc
                    source: glowSrc
                    visible: panel.style && panel.style.night && panel.total.length > 0
                    blurEnabled: true; blur: 1.0; blurMax: 18; autoPaddingEnabled: true
                }
                Text {
                    anchors.centerIn: parent
                    text: panel.total
                    visible: panel.total.length > 0
                    color: panel.style ? panel.style.textPrimary : "#fff"
                    font.pixelSize: 21; font.weight: 900; font.letterSpacing: -0.55
                    font.features: { "tnum": 1 }
                }
            }

            // ===== 图例 =====
            Column {
                width: parent.width - 118 - 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: panel.slices
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 26
                        radius: 9
                        color: panel.style ? (panel.style.night ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.45)) : "#00000022"
                        border.width: 1
                        border.color: panel.style ? (panel.style.night ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(0.40, 0.34, 0.28, 0.12)) : "#ffffff0d"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 9
                            spacing: 8
                            // 霓虹图例点（设计稿 .pie-dot box-shadow 0 0 10px currentColor）
                            Item {
                                width: 9; height: 9
                                anchors.verticalCenter: parent.verticalCenter
                                GlowCircle {
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    glowColor: modelData.color
                                    glowOpacity: 0.6 * panel.gs
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 9; height: 9; radius: 4.5
                                    color: modelData.color
                                }
                            }
                            Text {
                                width: parent.width - 9 - 8 - pctText.implicitWidth - 8
                                text: modelData.name
                                color: panel.style ? panel.style.textPrimary : "#fff"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: pctText
                                text: modelData.percent + "%"
                                color: panel.style ? panel.style.textSecondary : "#bbb"
                                font.pixelSize: 10; font.weight: 700
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Text {
                    visible: !panel.hasData
                    text: "暂无占比数据"
                    color: panel.style ? panel.style.textTertiary : "#888"
                    font.pixelSize: 12
                }
            }
        }

        // 底部洞察胶囊（设计稿 .daily-pie-insight）
        Rectangle {
            width: parent.width
            height: 44
            radius: 16
            visible: panel.insightText.length > 0
            color: panel.style ? (panel.style.night ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.4)) : "#00000020"
            border.width: 1
            border.color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.11) : Qt.rgba(0.56, 0.87, 1, 0.11)
            // 135° aqua→violet 浅染
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: panel.style ? Qt.rgba(panel.style.glowCyan.r, panel.style.glowCyan.g, panel.style.glowCyan.b, 0.09 * panel.gs) : Qt.rgba(0.56, 0.87, 1, 0.09) }
                    GradientStop { position: 1; color: panel.style ? Qt.rgba(panel.style.violet.r, panel.style.violet.g, panel.style.violet.b, 0.075 * panel.gs) : Qt.rgba(0.61, 0.55, 1, 0.075) }
                }
            }
            Text {
                anchors.fill: parent
                anchors.margins: 11
                verticalAlignment: Text.AlignVCenter
                text: panel.insightText
                color: panel.style ? panel.style.textSecondary : "#bbb"
                font.pixelSize: 11
                lineHeight: 1.4
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
