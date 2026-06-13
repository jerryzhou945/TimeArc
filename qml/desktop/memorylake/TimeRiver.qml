import QtQuick

// 右栏「使用时间图 · 时间河流」：纵向时间轴 + 节点条 + 涟漪，跟随当前 APP。
// 纵轴固定 0–24 时（自上而下），节点 y 与轴共用同一时间窗（§3.6 反错配修复）；
// 节点横向长度表示单次会话时长。数据来自后端 buildRiverNodes：
//   app.times = [{ start:"HH:mm", end:"HH:mm", y:0..1(全天分数), dur:秒 }]。
Item {
    id: river

    property MemoryLakeStyle style
    property var app

    // 纵轴固定刻度：0–24 时，5 档；f = 全天分数，与节点 y 同一坐标系。
    readonly property var axisLabels: [
        { t: "00:00", f: 0.0 }, { t: "06:00", f: 0.25 },
        { t: "12:00", f: 0.5 }, { t: "18:00", f: 0.75 }, { t: "24:00", f: 1.0 }
    ]
    // 设计稿 .tree-axis / .time-node / .ripple 均以 left:52px 为基准
    readonly property int axisX: 52

    readonly property var nodes: app && app.times ? app.times : []

    function displayTime(raw) {
        if (!raw || raw === "")
            return "";
        var parts = raw.split(":");
        if (parts.length < 2)
            return raw;
        var h = parseInt(parts[0]);
        var m = parseInt(parts[1]);
        if (isNaN(h) || isNaN(m))
            return raw;
        var fmt = settingsRepository ? settingsRepository.getValue("time_format", "24") : "24";
        if (fmt !== "12")
            return raw;
        return Qt.formatTime(new Date(2000, 0, 1, h === 24 ? 0 : h, m), "h:mm AP");
    }

    // 全天分数 -> 轴可视区像素 y。轴线在 wrap 内上 26 / 下 30 内缩，节点与标签共用。
    function mapY(frac) {
        var top = 26;
        var avail = wrap.height - 56;
        var f = frac < 0 ? 0 : (frac > 1 ? 1 : frac);
        return top + avail * f;
    }

    function labelLane(index) {
        var node = nodes[index];
        if (!node)
            return 0;
        var y = mapY(node.y ? node.y : 0);
        var lane = 0;
        for (var i = index - 1; i >= 0; --i) {
            var prev = nodes[i];
            if (!prev)
                continue;
            var py = mapY(prev.y ? prev.y : 0);
            if (Math.abs(py - y) < 18)
                lane += 1;
        }
        return lane;
    }

    function labelY(nodeY, lane) {
        var offsets = [-24, -8, 8, 24];
        var y = nodeY + offsets[Math.min(lane, offsets.length - 1)];
        return Math.max(4, Math.min(wrap.height - 18, y));
    }

    Column {
        anchors.fill: parent
        spacing: 10

        // 标题
        Item {
            width: parent.width
            height: 18
            Text {
                anchors.left: parent.left
                text: "使用时间图 · 时间河流"
                color: river.style ? river.style.textPrimary : "#fff"
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: "纵轴 0–24 时"
                color: river.style ? river.style.textTertiary : "#888"
                font.pixelSize: 11
            }
        }

        // tree-wrap
        Rectangle {
            id: wrap
            width: parent.width
            height: parent.height - 18 - 10
            radius: 20
            color: river.style ? (river.style.night ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.25)) : "#0b1018"
            border.width: 1
            border.color: river.style ? river.style.cardBorder : "#ffffff10"
            clip: true

            // 竖向网格（四分）
            Row {
                anchors.fill: parent
                Repeater {
                    model: 4
                    delegate: Item {
                        width: wrap.width / 4
                        height: wrap.height
                        Rectangle {
                            width: 1; height: parent.height
                            color: Qt.rgba(1, 1, 1, river.style && river.style.night ? 0.035 : 0.06)
                        }
                    }
                }
            }

            // 时间轴：transparent → rgba(133,237,255,.38) → transparent
            Rectangle {
                x: river.axisX
                y: 26
                width: 1
                height: parent.height - 56
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(0.52, 0.93, 1.0, 0.38) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // 左侧时间标签（固定 0–24 时，与节点同窗）
            Repeater {
                model: river.axisLabels
                delegate: Text {
                    required property var modelData
                    x: 8
                    y: river.mapY(modelData.f) - height / 2
                    text: river.displayTime(modelData.t)
                    color: river.style ? river.style.textTertiary : "#888"
                    font.pixelSize: 10
                }
            }

            // 涟漪 + 节点
            Repeater {
                model: river.nodes
                delegate: Item {
                    required property int index
                    required property var modelData
                    anchors.fill: parent

                    readonly property real availW: wrap.width - river.axisX - 70
                    readonly property real nodeY: river.mapY(modelData.y ? modelData.y : 0)
                    // 横向长度按单次时长映射：约 2h 占满，按比例缩短，最短 20px。
                    readonly property real nodeW: Math.max(20, Math.min(availW,
                        availW * Math.min(1, (modelData.dur ? modelData.dur : 0) / 7200)))
                    readonly property int labelLane: river.labelLane(index)

                    // 涟漪
                    Rectangle {
                        property real r: 48 + index * 22
                        x: river.axisX - r / 2
                        y: nodeY - r / 2
                        width: r; height: r; radius: r / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(0.51, 0.94, 1.0, 0.14)
                    }

                    // 节点条：设计稿 .time-node 是 2px 细线（aqua .84 → violet .66）
                    Rectangle {
                        x: river.axisX
                        y: nodeY - 1.5
                        width: nodeW
                        height: 3
                        radius: 1.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: river.style ? Qt.rgba(river.style.aqua.r, river.style.aqua.g, river.style.aqua.b, 0.84) : "#82efff" }
                            GradientStop { position: 1; color: river.style ? Qt.rgba(river.style.violet.r, river.style.violet.g, river.style.violet.b, 0.66) : "#d87cff" }
                        }
                    }

                    // 节点圆点辉光（两层低透圆叠出柔晕）
                    Rectangle {
                        x: river.axisX - 14; y: nodeY - 14
                        width: 28; height: 28; radius: 14
                        color: river.style ? Qt.rgba(river.style.aqua.r, river.style.aqua.g, river.style.aqua.b, 0.08) : "#82efff14"
                    }
                    Rectangle {
                        x: river.axisX - 9; y: nodeY - 9
                        width: 18; height: 18; radius: 9
                        color: river.style ? Qt.rgba(river.style.aqua.r, river.style.aqua.g, river.style.aqua.b, 0.16) : "#82efff28"
                    }

                    // 节点圆点 rgba(220,248,250,.92)
                    Rectangle {
                        x: river.axisX - 5
                        y: nodeY - 5
                        width: 10; height: 10; radius: 5
                        color: river.style ? Qt.rgba(0.863, 0.973, 0.98, 0.92) : "#dffaff"
                    }

                    // 标签
                    Text {
                        visible: labelLane < 4
                        x: Math.min(river.axisX + nodeW + 10 + labelLane * 8, wrap.width - width - 8)
                        y: river.labelY(nodeY, labelLane)
                        width: 92
                        text: river.displayTime(modelData.start) + "–" + river.displayTime(modelData.end)
                        color: river.style ? river.style.textSecondary : "#bbb"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            // 空态：当前应用今天没有可展示的使用时段。
            Text {
                anchors.centerIn: parent
                visible: river.nodes.length === 0
                text: "今天没有该应用的使用时段"
                color: river.style ? river.style.textTertiary : "#888"
                font.pixelSize: 12
            }
        }
    }
}
