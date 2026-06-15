import QtQuick
import QtQuick.Controls
import "../memorylake"
import "../components/AppVisual.js" as AppVisual

// 记忆湖页面：1:1 复刻 MemoryLakeDesign/memory_lake_v25_win11_style.html 的窗口内部三栏。
// 阶段 A：三栏静态排版 + 灯光底子 + 主题。后续阶段补卡牌交互 / 丝滑滚动 / 月度回顾。
// 详见 docs/memory-lake-implementation-plan.md。
Item {
    id: root
    anchors.fill: parent
    clip: true

    // —— 主题契约（由 DesktopAppShell.applyThemeToLoadedPage 注入）——
    property bool nightMode: true
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FBF8F4"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"
    property string languageMode: "zh"

    // —— 当前选中的记忆 ——
    property int selectedIndex: 0
    property int flippedIndex: -1
    property int previewIndex: -1

    // 中栏今日结论（briefing）静止高度（设计稿 .today-briefing max-height 240，实测 ~200）；
    // 翻面锁定时折叠为 0，把空间让给卡区。
    readonly property real briefingH: 204
    // 实际占高 = 内容撑开后的高度（不低于 briefingH）。窄宽（最小窗口）下今日结论文本换行变高，
    // 卡区据此下移——配合 TodayConclusionCard.implicitHeight，底栏 chips 永不与上方文字叠印。
    readonly property real briefingActualH: Math.max(briefingH, briefing.implicitHeight)
    // 今日结论折叠系数（0=展开 / 1=翻面收起）。只对「翻面收起」缓动；内容驱动的高度变化（5s 刷新可能
    // 改文案）即时生效、不抖动——故 briefing 的 height/opacity/scale 与卡区 y 全由本系数线性插值，
    // 不再各自挂 Behavior（避免每次刷新触发 440ms 重排抖动）。
    property real briefCollapse: root.locked ? 1 : 0
    Behavior on briefCollapse { NumberAnimation { duration: 440; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy } }

    // 记忆湖·日视图模型：dailyCardService.memoryLakeDay 产出（后端组装，QML 只渲染）。
    // 取数走首页同款只读路径（usageStatManager），无数据走空态，绝不用 Mock 假数据冒充。
    property var dayModel: ({})
    readonly property var apps: (dayModel && dayModel.apps) ? dayModel.apps : []
    readonly property bool hasData: apps.length > 0
    readonly property var current: apps.length > 0
        ? apps[Math.max(0, Math.min(selectedIndex, apps.length - 1))] : null
    readonly property bool locked: flippedIndex >= 0

    readonly property var overview: (dayModel && dayModel.overview)
        ? dayModel.overview : ({ total: "0m", sub: "暂无记录" })
    readonly property var todayTheme: (dayModel && dayModel.todayTheme)
        ? dayModel.todayTheme
        : ({ kicker: "今日主题", title: "今天还很安静",
             desc: "还没有自动记录，开始使用后这里会生成今日主题。", ratio: 0 })

    // 今日结论 / 今日占比：后端在 memoryLakeDay 里组装好，QML 只渲染。
    readonly property var todayConclusion: (dayModel && dayModel.todayConclusion)
        ? dayModel.todayConclusion : ({})
    readonly property var usageShare: (dayModel && dayModel.usageShare)
        ? dayModel.usageShare : []

    // 请求切换导航页（shell 在 onLoaded 里连接；今日事项「日历」按钮用）。
    signal requestNavigate(string pageKey)

    // 排行：apps 已按时长降序 -> 身份索引序列（喂 UsageRankList）。
    readonly property var ranking: {
        var r = [];
        for (var i = 0; i < apps.length; i++) r.push(i);
        return r;
    }

    // 氛围大背景色：优先用当前 APP 图标主色（多色 blend），缺失退回 appColor 单色。
    readonly property color ambientColor: current
        ? AppVisual.modelAppColor(current)
        : (ml ? ml.aqua : "#9FE7EE")
    readonly property var ambientColors: (current && current.iconColors && current.iconColors.length > 0)
        ? current.iconColors
        : [ambientColor]
    readonly property bool hasAmbient: hasData

    function recomputeDayModel() {
        if (!usageStatManager || !dailyCardService) { root.dayModel = ({}); return; }
        root.dayModel = dailyCardService.memoryLakeDay(
            usageStatManager.activeSoftwareForRange("day"),
            usageStatManager.foregroundSegmentsForRange("day"));
    }

    // 月度回顾已拆为独立页面 DesktopMonthlyRecapPage（菜单底部「记忆湖」）。

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: if (usageStatManager) usageStatManager.refresh()
    }
    Connections {
        target: usageStatManager
        function onUsageStatsChanged() { root.recomputeDayModel(); }
    }
    Component.onCompleted: root.recomputeDayModel()

    function selectCard(i) {
        if (root.locked && i !== root.selectedIndex) return;
        root.previewIndex = -1;
        root.selectedIndex = Math.max(0, Math.min(apps.length - 1, i));
    }
    function toggleFlip(i) {
        root.flippedIndex = (root.flippedIndex === i) ? -1 : i;
    }

    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        injectedTextPrimary: root.themeTextPrimary
        injectedTextSecondary: root.themeTextSecondary
    }

    // —— 氛围灯光层（角向柔光 + 半透水面色；模糊大图已上移为整个 App 背景，见 Shell Issue 1）——
    AmbientBackground {
        anchors.fill: parent
        style: ml
    }

    // —— 布局：中间卡牌轮盘铺满占位符做背景层，左右玻璃面板浮在上层 ——
    Item {
        id: columns
        anchors.fill: parent
        anchors.margins: 4

        // ============ 左栏：浮在上层 ============
        GlassPanel {
            id: leftPanel
            width: 300
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 1
            style: ml

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // 用户卡（profile，L2）：135° aqua→violet 斜染 + 头像顶沿内高光
                FrostCard {
                    width: parent.width
                    height: 66
                    style: ml
                    radius: ml.radiusCard
                    tintTop: Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.08 * ml.glowStrength)
                    tintBottom: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.045 * ml.glowStrength)
                    Row {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 11
                        Rectangle {
                            width: 38; height: 38; radius: 14
                            anchors.verticalCenter: parent.verticalCenter
                            gradient: Gradient {
                                GradientStop { position: 0; color: ml.aqua }
                                GradientStop { position: 1; color: ml.violet }
                            }
                            // 头像顶沿内高光 inset 0 1px 白 .2（一条 1px Rectangle，L2）
                            Rectangle {
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 2 }
                                height: 1; color: Qt.rgba(1, 1, 1, 0.2)
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text { text: "Memory Lake"; color: ml.textPrimary; font.pixelSize: 18; font.bold: true }
                            Text { text: "电脑使用时间记录"; color: ml.textTertiary; font.pixelSize: 11 }
                        }
                    }
                }

                // 今日主题（theme）：占满整行（使用总览已移除——其总时数信息今日结论已含）。
                FrostCard {
                    width: parent.width
                    height: 124
                    style: ml
                    radius: ml.radiusCard
                    tintTop: Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.08 * ml.glowStrength)
                    tintBottom: Qt.rgba(1, 1, 1, 0.025)
                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 7
                        Text {
                            text: root.todayTheme.kicker; color: ml.aqua; font.pixelSize: 11; opacity: 0.9
                            font.capitalization: Font.AllUppercase; font.letterSpacing: 1.0
                        }
                        Text { text: root.todayTheme.title; color: ml.textPrimary; font.pixelSize: 19; font.bold: true }
                        Text {
                            width: parent.width
                            text: root.todayTheme.desc
                            color: ml.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: parent.width; height: 6; radius: 3
                            color: ml.trackBg
                            Rectangle {
                                width: parent.width * root.todayTheme.ratio
                                height: parent.height; radius: 3
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: ml.aqua }
                                    GradientStop { position: 1; color: ml.pink }
                                }
                            }
                        }
                    }
                }

                // 今日结论已移回中栏顶部（v88 .today-briefing）；左栏把腾出的空间给排行
                // （设计稿 usage-list-panel「给排行榜更多空间」）。
                // 排行（L4 纯霜膜 + 边缘光对；列表自身在 clip 容器内滚动）
                FrostCard {
                    width: parent.width
                    height: parent.height - 66 - 124 - 20
                    style: ml
                    radius: ml.radiusCard
                    Item {
                        anchors.fill: parent
                        anchors.margins: 13
                        clip: true
                        UsageRankList {
                            anchors.fill: parent
                            style: ml
                            languageMode: root.languageMode
                            apps: root.apps
                            ranking: root.ranking
                            selectedIndex: root.selectedIndex
                            locked: root.locked
                            onRequestSelect: function(cardIndex) { root.selectCard(cardIndex) }
                            onHoverCard: function(cardIndex) { if (!root.locked) root.previewIndex = cardIndex }
                            onUnhoverCard: root.previewIndex = -1
                        }
                    }
                }
            }
        }

        // ============ 中栏：包裹板（设计稿 .main-panel，与左右栏同款 GlassPanel 包裹大板块）============
        //               内含今日结论（上）+ 卡牌区暗箱（下半，翻面折叠让位）。
        GlassPanel {
            id: middlePanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: leftPanel.right
            anchors.right: rightPanel.left
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            z: 1
            style: ml

            Item {
                id: middleInner
                anchors.fill: parent
                anchors.margins: 14

            // 今日结论（设计稿 .today-briefing）：翻面锁定时折叠（「今日结论暂时收起」），把空间让给卡区。
            TodayConclusionCard {
                id: briefing
                x: 0; y: 0
                width: parent.width
                // height/opacity/scale 由 briefCollapse 线性驱动：展开=实际内容高(briefingActualH)，翻面收起→0。
                height: (1 - root.briefCollapse) * root.briefingActualH
                opacity: 1 - root.briefCollapse
                visible: opacity > 0.01
                style: ml
                model: root.todayConclusion
                todoRemaining: calendarSync.remaining
                transformOrigin: Item.Top
                scale: 1 - 0.03 * root.briefCollapse
            }

            // 卡牌区（设计稿 .cards-zone）：圆角暗箱；折叠时上移填满（容纳翻面 616 高卡）。
            Rectangle {
                id: cardsZone
                x: 0
                width: parent.width
                // 跟随 briefCollapse 与今日结论实际高一起插值（展开=briefingActualH+14，收起→0）。
                y: (1 - root.briefCollapse) * (root.briefingActualH + 14)
                height: parent.height - y
                radius: 26
                color: ml.cardsZoneBg
                border.width: 1
                border.color: root.locked
                    ? Qt.rgba(ml.glowCyan.r, ml.glowCyan.g, ml.glowCyan.b, 0.22)
                    : Qt.rgba(1, 1, 1, ml.night ? 0.08 : 0.04)
                antialiasing: true
                clip: true
                Behavior on border.color { ColorAnimation { duration: 300 } }

                // 顶沿 1px 内高光（玻璃上唇）。左右内缩半径，不越圆角。
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right
                              topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                    height: 1
                    color: ml.edgeHighlight
                }

                // 50% 处 aqua 装饰中线（设计稿 .cards-zone::before）。宽度钳到中心一小段并居中，
                // 避免大窗口下横贯空旷卡区、与卡牌一道读作扎眼「光线条」（左右内缩规避割裂画面）。
                Rectangle {
                    readonly property real lineW: Math.min(parent.width - 116, 420)
                    x: (parent.width - lineW) / 2; width: lineW
                    y: Math.round(parent.height * 0.5)
                    height: 1
                    visible: parent.width > 140
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(ml.glowCyan.r, ml.glowCyan.g, ml.glowCyan.b, 0.22) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                // 卡牌轮盘（铺满卡区；lane = 整个卡区，灯光/水位线限定卡区内）。
                CardCarousel {
                    id: centerCarousel
                    anchors.fill: parent
                    style: ml
                    languageMode: root.languageMode
                    apps: root.apps
                    selectedIndex: root.selectedIndex
                    flippedIndex: root.flippedIndex
                    previewIndex: root.previewIndex
                    onRequestSelect: function(i) { root.selectCard(i) }
                    onRequestToggleFlip: function(i) { root.toggleFlip(i) }
                    onHoverCard: function(i) { root.previewIndex = i }
                    onUnhoverCard: root.previewIndex = -1
                }

                // 卡区空态：今天还没有自动记录时给保守提示，不显假卡片。
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root.hasData
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "今天还没有自动记录"
                        color: ml.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "开始使用电脑后，这里会浮现今天的记忆卡片。"
                        color: ml.textSecondary
                        font.pixelSize: 13
                    }
                }
            }
            }
        }

        // ============ 右栏：浮在上层 ============
        GlassPanel {
            id: rightPanel
            width: 310
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 1
            style: ml

            // 右栏出现逻辑同步 v88（V71）：未翻面 = 今日事项(上) + 软件使用占比(下)，隐藏时间图；
            // 翻面 = 仅显示使用时间图，事项/占比隐藏。切换用 v88 rightSectionSwap 弹性入场。
            Item {
                anchors.fill: parent
                anchors.margins: 14

                // —— 未翻面：今日事项（顺序一/上）+ 今日软件使用占比（顺序二/下）——
                Item {
                    id: homeRight
                    anchors.fill: parent
                    readonly property bool active: !root.locked
                    visible: opacity > 0.01
                    opacity: 1
                    transform: [
                        Translate { id: homeTr; y: 0 },
                        Scale {
                            id: homeSc
                            origin.x: homeRight.width / 2; origin.y: homeRight.height / 2
                            xScale: 1; yScale: 1
                        }
                    ]
                    Component.onCompleted: opacity = active ? 1 : 0
                    onActiveChanged: active ? homeIn.restart() : homeOut.restart()

                    Column {
                        anchors.fill: parent
                        spacing: 14

                        // 顺序一：今日事项（与日历同步）
                        CalendarSyncList {
                            id: calendarSync
                            width: parent.width
                            height: Math.max(160, parent.height - 298 - 14)
                            style: ml
                            onOpenCalendar: root.requestNavigate("calendar")
                        }

                        // 顺序二：今日软件使用占比（霓虹甜甜圈 + 图例 + 洞察）
                        DailyUsageShare {
                            width: parent.width
                            height: 298
                            style: ml
                            share: root.usageShare
                            total: root.overview.total
                        }
                    }

                    SequentialAnimation {
                        id: homeIn
                        PropertyAction { target: homeTr; property: "y"; value: 14 }
                        PropertyAction { target: homeSc; property: "xScale"; value: 0.985 }
                        PropertyAction { target: homeSc; property: "yScale"; value: 0.985 }
                        PropertyAction { target: homeRight; property: "opacity"; value: 0.45 }
                        ParallelAnimation {
                            NumberAnimation { target: homeRight; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: homeTr; property: "y"; to: -3; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: [0.18, 0.9, 0.2, 1, 1, 1] }
                                    NumberAnimation { target: homeSc; property: "xScale"; to: 1.008; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: [0.18, 0.9, 0.2, 1, 1, 1] }
                                    NumberAnimation { target: homeSc; property: "yScale"; to: 1.008; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: [0.18, 0.9, 0.2, 1, 1, 1] }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: homeTr; property: "y"; to: 0; duration: 160; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: homeSc; property: "xScale"; to: 1; duration: 160; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: homeSc; property: "yScale"; to: 1; duration: 160; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                    NumberAnimation { id: homeOut; target: homeRight; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                }

                // —— 翻面：使用时间图填满；事项/占比隐藏 ——
                Item {
                    id: lockedRight
                    anchors.fill: parent
                    readonly property bool active: root.locked
                    visible: opacity > 0.01
                    opacity: 0
                    transform: [
                        Translate { id: lockTr; y: 0 },
                        Scale {
                            id: lockSc
                            origin.x: lockedRight.width / 2; origin.y: lockedRight.height / 2
                            xScale: 1; yScale: 1
                        }
                    ]
                    Component.onCompleted: opacity = active ? 1 : 0
                    onActiveChanged: active ? lockIn.restart() : lockOut.restart()

                    FrostCard {
                        anchors.fill: parent
                        style: ml
                        radius: ml.radiusCard
                        TimeRiver {
                            anchors.fill: parent
                            anchors.margins: 16
                            style: ml
                            app: root.current
                        }
                    }

                    SequentialAnimation {
                        id: lockIn
                        PropertyAction { target: lockTr; property: "y"; value: 14 }
                        PropertyAction { target: lockSc; property: "xScale"; value: 0.985 }
                        PropertyAction { target: lockSc; property: "yScale"; value: 0.985 }
                        PropertyAction { target: lockedRight; property: "opacity"; value: 0.45 }
                        ParallelAnimation {
                            NumberAnimation { target: lockedRight; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: lockTr; property: "y"; to: -3; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: [0.18, 0.9, 0.2, 1, 1, 1] }
                                    NumberAnimation { target: lockSc; property: "xScale"; to: 1.008; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: [0.18, 0.9, 0.2, 1, 1, 1] }
                                    NumberAnimation { target: lockSc; property: "yScale"; to: 1.008; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: [0.18, 0.9, 0.2, 1, 1, 1] }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: lockTr; property: "y"; to: 0; duration: 160; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: lockSc; property: "xScale"; to: 1; duration: 160; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: lockSc; property: "yScale"; to: 1; duration: 160; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                    NumberAnimation { id: lockOut; target: lockedRight; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                }
            }
        }
    }

}
