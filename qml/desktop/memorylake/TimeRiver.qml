import QtQuick

// 右栏「使用时间图 · 时间河流」：纵向时间轴 + 节点条 + 涟漪 + 刻度，跟随当前 APP。
// 1:1 对应设计稿 .time-tree / .tree-wrap / .time-node / .ripple。
Item {
    id: river

    property MemoryLakeStyle style
    property var app

    readonly property var axisLabels: [
        { t: "10:00", y: 0.18 }, { t: "16:00", y: 0.42 },
        { t: "20:00", y: 0.66 }, { t: "24:00", y: 0.86 }
    ]
    readonly property var ruler: ["10:00", "14:00", "18:00", "22:00"]
    // 设计稿 .tree-axis / .time-node / .ripple 均以 left:52px 为基准
    readonly property int axisX: 52

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
                text: "几点到几点"
                color: river.style ? river.style.textTertiary : "#888"
                font.pixelSize: 11
            }
        }

        // tree-wrap
        Rectangle {
            id: wrap
            width: parent.width
            height: parent.height - 18 - 10 - 18 - 10
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

            // 左侧时间标签
            Repeater {
                model: river.axisLabels
                delegate: Text {
                    required property var modelData
                    x: 10
                    y: wrap.height * modelData.y - height / 2
                    text: modelData.t
                    color: river.style ? river.style.textTertiary : "#888"
                    font.pixelSize: 10
                }
            }

            // 涟漪 + 节点
            Repeater {
                model: river.app ? river.app.times : []
                delegate: Item {
                    required property int index
                    required property var modelData
                    anchors.fill: parent

                    readonly property real nodeY: wrap.height * (modelData[3] / 100)
                    readonly property real nodeW: Math.min(modelData[2], wrap.width - river.axisX - 70)

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

                    // 节点圆点辉光（近似 box-shadow 0 0 18px rgba(130,239,255,.42)；
                    // 无原生外发光，用两层低透圆叠出柔晕，避开逐节点 MultiEffect 开销）
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
                        x: river.axisX + nodeW + 10
                        y: nodeY - 8
                        text: modelData[0] + "–" + modelData[1]
                        color: river.style ? river.style.textSecondary : "#bbb"
                        font.pixelSize: 11
                    }
                }
            }
        }

        // 底部刻度
        Row {
            width: parent.width
            height: 18
            Repeater {
                model: river.ruler
                delegate: Text {
                    required property int index
                    required property var modelData
                    width: wrap.width / 4
                    text: modelData
                    color: river.style ? river.style.textTertiary : "#888"
                    font.pixelSize: 10
                    horizontalAlignment: index === 0 ? Text.AlignLeft
                                                     : (index === 3 ? Text.AlignRight : Text.AlignHCenter)
                }
            }
        }
    }
}
