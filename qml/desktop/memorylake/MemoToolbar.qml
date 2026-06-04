import QtQuick

// 备忘工具条（v88 .memo-toolbar）。居中悬浮玻璃药丸，overlay 开时从上方 10px 滑入。
// 工具 note|text|pen|eraser 互斥，再点当前工具取消(→none)；退出键触发关闭。
// active = 招牌 aqua→violet 135° 渐变 + 近黑图标；hover 抬升 6px + 放大 1.06 + aqua 洗背；
// 退出键 hover 转破坏红。详见 docs/memory-lake-memo-render-pipeline-replication.md §1.2 / 功能文 §2.2。
Item {
    id: bar

    property MemoryLakeStyle style
    property bool shown: false            // overlay 开 → 滑入
    property string currentTool: "pen"
    signal exitRequested()

    function toggleTool(t) { currentTool = (currentTool === t) ? "none" : t; }

    readonly property var tools: [
        { kind: "note",   label: "创建便签" },
        { kind: "text",   label: "文字" },
        { kind: "pen",    label: "画笔" },
        { kind: "eraser", label: "橡皮擦" }
    ]

    implicitWidth: pill.width
    implicitHeight: pill.height

    // 入场：滑入 + 淡入（transform .28s bezier(.2,.8,.2,1) / opacity .24s）。
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    property real slideY: shown ? 0 : -10
    Behavior on slideY {
        NumberAnimation { duration: 280; easing.type: Easing.Bezier
            easing.bezierCurve: bar.style ? bar.style.easeSoft : [0.2, 0.8, 0.2, 1, 1, 1] }
    }
    transform: Translate { y: bar.slideY }

    Rectangle {
        id: pill
        width: row.width + 16
        height: 48
        radius: 12
        // 设计稿 V53：上深下更深竖渐变玻璃 + aqua 描边 + 顶内高光。
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(28 / 255, 32 / 255, 42 / 255, 0.94) }
            GradientStop { position: 1; color: Qt.rgba(16 / 255, 19 / 255, 28 / 255, 0.92) }
        }
        border.width: 1
        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.14)
        antialiasing: true

        // 顶沿 1px 内高光（玻璃斜面）。
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right
                      topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
            height: 1; color: Qt.rgba(1, 1, 1, 0.08)
        }

        Row {
            id: row
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            // —— 4 个互斥工具 ——
            Repeater {
                model: bar.tools
                delegate: Item {
                    id: tbtn
                    required property var modelData
                    readonly property string kind: modelData.kind
                    readonly property bool active: bar.currentTool === kind
                    width: 38; height: 38
                    anchors.verticalCenter: parent.verticalCenter

                    // hover 抬升 + 放大
                    transform: [
                        Translate { y: tHover.containsMouse ? -6 : 0
                            Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } },
                        Scale {
                            origin.x: 19; origin.y: 19
                            xScale: tHover.containsMouse ? 1.06 : 1.0
                            yScale: tHover.containsMouse ? 1.06 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 140 } }
                            Behavior on yScale { NumberAnimation { duration: 140 } }
                        }
                    ]

                    Rectangle {
                        id: tbg
                        anchors.fill: parent
                        radius: 8
                        antialiasing: true
                        visible: tbtn.active || tHover.containsMouse
                        gradient: tbtn.active ? activeGrad : null
                        color: tbtn.active ? "transparent"
                                           : Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.10)
                        border.width: tbtn.active ? 0 : 1
                        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.18)
                        Gradient {
                            id: activeGrad
                            // 招牌 aqua→violet（竖直近似 135°，38px 尺度可忽略斜向差）
                            GradientStop { position: 0; color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.94) }
                            GradientStop { position: 1; color: Qt.rgba(155 / 255, 139 / 255, 255 / 255, 0.92) }
                        }
                    }

                    MemoToolGlyph {
                        anchors.centerIn: parent
                        kind: tbtn.kind
                        // active 时近黑图标压在亮渐变上；否则亮灰。
                        glyphColor: tbtn.active ? Qt.rgba(4 / 255, 8 / 255, 14 / 255, 0.94)
                                                : Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.86)
                    }

                    MouseArea {
                        id: tHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.toggleTool(tbtn.kind)
                    }
                }
            }

            // 分隔
            Rectangle {
                width: 1; height: 26; radius: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.10)
            }

            // —— 退出 ——
            Item {
                width: exitText.width + 22; height: 38
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    visible: eHover.containsMouse
                    color: Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.22)
                }
                Text {
                    id: exitText
                    anchors.centerIn: parent
                    text: "退出"
                    font.pixelSize: 14
                    color: eHover.containsMouse ? "#FFD2D2" : Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.86)
                }
                MouseArea {
                    id: eHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.exitRequested()
                }
            }
        }
    }
}
