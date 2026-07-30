import QtQuick
import "../components/I18n.js" as I18n
import "../components/PlatformCursor.js" as Cursor

// 备忘工具条（v88 .memo-toolbar）。居中悬浮玻璃药丸，overlay 开时从上方 10px 滑入。
// 工具 note|text|pen|eraser 互斥，再点当前工具取消(→none)；退出键触发关闭。
// active = 招牌 aqua→violet 135° 渐变 + 近黑图标；hover 抬升 6px + 放大 1.06 + aqua 洗背；
// 退出键 hover 转破坏红。详见 docs/memory-lake-memo-render-pipeline-replication.md §1.2 / 功能文 §2.2。
Item {
    id: bar

    property MemoryLakeStyle style
    property string languageMode: "zh"
    property bool shown: false            // overlay 开 → 滑入
    property bool revealed: true          // 灵动岛是否展开；收起时关闭悬停跟踪，
                                          // 避免栏体动画移出指针（无 hoverLeave）导致次高亮/抬升卡住
    property string currentTool: "pen"
    property bool canUndo: false
    property bool canRedo: false
    signal exitRequested()
    signal pomodoroRequested()
    signal clearRequested()                // gap #4：清空本页墨迹（由覆盖层弹确认）
    signal undoRequested()
    signal redoRequested()

    // 笔宽（gap #3）：默认取 style，工具条选档覆盖；笔/橡皮各一组「细/中/粗」预设。
    property real penWidth: style ? style.memoPenWidth : 4
    property real eraserWidth: style ? style.memoEraserWidth : 28
    readonly property var penWidths: [2.5, 4, 7]
    readonly property var eraserWidths: [16, 28, 44]
    // 笔色（gap #2）：默认暖粉笔黄，调板覆盖（橡皮无色）。
    property color inkColor: style ? style.memoInk : Qt.rgba(1, 236 / 255, 150 / 255, 0.96)

    // 鼠标是否悬在工具条上（供 Shell 维持灵动岛展开；工具条需置于顶部感应区 topZone 之上才生效）。
    // 含子弹层(subPop)，否则从条上移到选项弹层时灵动岛会收起、把弹层抽走。
    readonly property bool barHovered: pillHover.hovered || subPopHover.hovered

    function toggleTool(t) { currentTool = (currentTool === t) ? "none" : t; }

    readonly property var tools: [
        { kind: "select", label: "选择" },
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

        // 整条悬停感应（被动，不拦子按钮 hover）：维持灵动岛展开 + 解释为何工具条要在 topZone 之上。
        HoverHandler { id: pillHover }

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
                    readonly property bool hovered: tHover.containsMouse
                    width: 38; height: 38
                    anchors.verticalCenter: parent.verticalCenter

                    // hover 抬升 + 放大 **只作用在视觉层** tvisual：传感器 MouseArea 必须留在原位不被位移，
                    // 否则抬升把命中区从指针下移走、又收不到 hoverLeave → containsMouse 卡死 true，
                    // 点击后「抬升 + aqua 洗背」就印在按钮上不退（用户反馈的鬼影）。
                    Item {
                        id: tvisual
                        anchors.fill: parent
                        transform: [
                            Translate { y: tbtn.hovered ? -6 : 0
                                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } },
                            Scale {
                                origin.x: 19; origin.y: 19
                                xScale: tbtn.hovered ? 1.06 : 1.0
                                yScale: tbtn.hovered ? 1.06 : 1.0
                                Behavior on xScale { NumberAnimation { duration: 140 } }
                                Behavior on yScale { NumberAnimation { duration: 140 } }
                            }
                        ]

                        Rectangle {
                            id: tbg
                            anchors.fill: parent
                            radius: 8
                            antialiasing: true
                            visible: tbtn.active || tbtn.hovered
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
                    }

                    // 传感器留在 tbtn 原位（不随 tvisual 的抬升 transform 位移）：命中区恒定，
                    // 抬升不再把命中区从指针下移走 → 不卡高亮（用户反馈的「按下后印在上面」鬼影）。
                    MouseArea {
                        id: tHover
                        anchors.fill: parent
                        hoverEnabled: bar.revealed
                        cursorShape: Cursor.button()
                        onClicked: bar.toggleTool(tbtn.kind)
                    }
                }
            }

            // 更多工具（番茄钟）。
            Item {
                width: 38; height: 38
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent; radius: 8
                    visible: moreHover.containsMouse
                    color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.10)
                    border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.18)
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: 3
                        delegate: Rectangle { width: 4; height: 4; radius: 2
                            color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.86) }
                    }
                }
                MouseArea {
                    id: moreHover
                    anchors.fill: parent
                    hoverEnabled: bar.revealed
                    cursorShape: Cursor.button()
                    onClicked: bar.pomodoroRequested()
                }
            }

            // 清空本页墨迹（gap #4）：危险动作，红色悬停；点击由覆盖层弹确认。
            Item {
                width: 38; height: 38
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent; radius: 8
                    visible: clearHover.containsMouse
                    color: Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.22)
                }
                MemoToolGlyph {
                    anchors.centerIn: parent
                    kind: "clear"
                    glyphColor: clearHover.containsMouse ? "#FFD2D2"
                                                         : Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.80)
                }
                MouseArea {
                    id: clearHover
                    anchors.fill: parent
                    hoverEnabled: bar.revealed
                    cursorShape: Cursor.button()
                    onClicked: bar.clearRequested()
                }
            }

            // 撤销 / 重做：显式按钮，避免只靠快捷键发现。
            Item {
                width: 38; height: 38
                anchors.verticalCenter: parent.verticalCenter
                opacity: bar.canUndo ? 1.0 : 0.38
                Rectangle {
                    anchors.fill: parent; radius: 8
                    visible: undoHover.containsMouse && bar.canUndo
                    color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.10)
                    border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.18)
                }
                MemoToolGlyph {
                    anchors.centerIn: parent
                    kind: "undo"
                    glyphColor: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.86)
                }
                MouseArea {
                    id: undoHover
                    anchors.fill: parent
                    hoverEnabled: bar.revealed && bar.canUndo
                    cursorShape: bar.canUndo ? Cursor.button() : Qt.ArrowCursor
                    onClicked: if (bar.canUndo) bar.undoRequested()
                }
            }

            Item {
                width: 38; height: 38
                anchors.verticalCenter: parent.verticalCenter
                opacity: bar.canRedo ? 1.0 : 0.38
                Rectangle {
                    anchors.fill: parent; radius: 8
                    visible: redoHover.containsMouse && bar.canRedo
                    color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.10)
                    border.width: 1; border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.18)
                }
                MemoToolGlyph {
                    anchors.centerIn: parent
                    kind: "redo"
                    glyphColor: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.86)
                }
                MouseArea {
                    id: redoHover
                    anchors.fill: parent
                    hoverEnabled: bar.revealed && bar.canRedo
                    cursorShape: bar.canRedo ? Cursor.button() : Qt.ArrowCursor
                    onClicked: if (bar.canRedo) bar.redoRequested()
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
                    text: I18n.t(bar.languageMode, "退出")
                    font.pixelSize: 14
                    color: eHover.containsMouse ? "#FFD2D2" : Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.86)
                }
                MouseArea {
                    id: eHover
                    anchors.fill: parent
                    hoverEnabled: bar.revealed
                    cursorShape: Cursor.button()
                    onClicked: bar.exitRequested()
                }
            }
        }
    }

    // 画笔/橡皮工具选项弹层（gap #3 粗细 + gap #2 笔色）：pen/eraser 时从 pill 下方滑出。
    Rectangle {
        id: subPop
        readonly property bool isPen: bar.currentTool === "pen"
        readonly property bool active: bar.currentTool === "pen" || bar.currentTool === "eraser"
        anchors.top: pill.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: pill.horizontalCenter
        width: subRow.width + 24
        height: 46
        radius: 12
        visible: active && opacity > 0.01
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.Bezier
            easing.bezierCurve: bar.style ? bar.style.easeSnappy : [0.18, 0.9, 0.2, 1, 1, 1] } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(28 / 255, 32 / 255, 42 / 255, 0.94) }
            GradientStop { position: 1; color: Qt.rgba(16 / 255, 19 / 255, 28 / 255, 0.92) }
        }
        border.width: 1
        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.14)
        antialiasing: true
        HoverHandler { id: subPopHover }   // 让 barHovered 覆盖弹层，移上去不收灵动岛

        Row {
            id: subRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t(bar.languageMode, "粗细")
                color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.5)
                font.pixelSize: 12
            }
            // 三档粗细（细/中/粗）：点子设置笔/橡皮宽度，选中高亮。
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    readonly property real val: (subPop.isPen ? bar.penWidths : bar.eraserWidths)[index]
                    readonly property bool sel: Math.abs((subPop.isPen ? bar.penWidth : bar.eraserWidth) - val) < 0.01
                    width: 30; height: 30; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: sel ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
                               : wHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.width: sel ? 1 : 0
                    border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.40)
                    Rectangle {
                        anchors.centerIn: parent
                        width: [6, 11, 17][index]; height: width; radius: width / 2
                        color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.86)
                    }
                    MouseArea {
                        id: wHover
                        anchors.fill: parent
                        hoverEnabled: bar.revealed
                        cursorShape: Cursor.button()
                        onClicked: { if (subPop.isPen) bar.penWidth = val; else bar.eraserWidth = val }
                    }
                }
            }

            // —— 笔色（仅画笔；橡皮 destination-out 无色，不显）——
            Rectangle {
                visible: subPop.isPen
                width: 1; height: 24; radius: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.10)
            }
            Repeater {
                model: subPop.isPen ? (bar.style ? bar.style.memoInkPalette : [bar.inkColor]) : []
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: Qt.colorEqual(bar.inkColor, modelData)
                    width: 26; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    border.width: sel ? 2 : 0
                    border.color: bar.style ? bar.style.memoSelectRing : Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.58)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 18; height: 18; radius: 9
                        color: modelData
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.22)
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: bar.revealed
                        cursorShape: Cursor.button()
                        onClicked: bar.inkColor = modelData
                    }
                }
            }
        }
    }
}
