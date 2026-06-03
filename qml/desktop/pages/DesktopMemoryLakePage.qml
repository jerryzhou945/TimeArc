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

    // —— 当前选中的记忆 ——
    property int selectedIndex: 0
    property int flippedIndex: -1
    property int previewIndex: -1

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
        ? AppVisual.appColor(current.appId, current.name, current.path)
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

                // 用户卡
                Rectangle {
                    width: parent.width
                    height: 66
                    radius: 19
                    color: ml.cardBg
                    border.width: 1
                    border.color: ml.cardBorder
                    Row {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 11
                        Rectangle {
                            width: 38; height: 38; radius: 14
                            anchors.verticalCenter: parent.verticalCenter
                            border.width: 2
                            border.color: Qt.rgba(1, 1, 1, 0.32)
                            gradient: Gradient {
                                GradientStop { position: 0; color: ml.aqua }
                                GradientStop { position: 1; color: ml.violet }
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

                // 概览 + 今日主题
                Row {
                    width: parent.width
                    height: 124
                    spacing: 10

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: parent.height
                        radius: 19
                        color: ml.cardBg
                        border.width: 1
                        border.color: ml.cardBorder
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 5
                            Text { text: "使用总览"; color: ml.aqua; font.pixelSize: 11; opacity: 0.85 }
                            Text { text: root.overview.total; color: ml.textPrimary; font.pixelSize: 27; font.bold: true }
                            Text { text: root.overview.sub; color: ml.textTertiary; font.pixelSize: 11 }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: parent.height
                        radius: 19
                        color: ml.cardBg
                        border.width: 1
                        border.color: ml.cardBorder
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 5
                            Text { text: root.todayTheme.kicker; color: ml.aqua; font.pixelSize: 11; opacity: 0.85 }
                            Text { text: root.todayTheme.title; color: ml.textPrimary; font.pixelSize: 17; font.bold: true }
                            Text {
                                width: parent.width
                                text: root.todayTheme.desc
                                color: ml.textSecondary
                                font.pixelSize: 11
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
                }

                // 今日结论（替换原月度回顾 CTA 位置；月度回顾已独立成页）
                TodayConclusionCard {
                    width: parent.width
                    height: 150
                    style: ml
                    model: root.todayConclusion
                    todoRemaining: calendarSync.remaining
                }

                // 排行
                Rectangle {
                    width: parent.width
                    height: parent.height - 66 - 124 - 150 - 30
                    radius: 22
                    clip: true
                    color: ml.cardBg
                    border.width: 1
                    border.color: ml.cardBorder
                    UsageRankList {
                        anchors.fill: parent
                        anchors.margins: 13
                        style: ml
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

        // ============ 中栏：卡牌轮盘 = 占位符背景层（铺满、无边框，在最底层）============
        CardCarousel {
            id: centerCarousel
            anchors.fill: parent
            z: 0
            style: ml
            apps: root.apps
            selectedIndex: root.selectedIndex
            flippedIndex: root.flippedIndex
            previewIndex: root.previewIndex
            onRequestSelect: function(i) { root.selectCard(i) }
            onRequestToggleFlip: function(i) { root.toggleFlip(i) }
            onHoverCard: function(i) { root.previewIndex = i }
            onUnhoverCard: root.previewIndex = -1
        }

        // 中栏空态：今天还没有自动记录时给保守提示，不显假卡片。
        Column {
            anchors.centerIn: parent
            z: 0
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

        // ============ 右栏：浮在上层 ============
        GlassPanel {
            id: rightPanel
            width: 310
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 1
            style: ml

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // 今日软件使用占比（饼图 + 图例）
                DailyUsageShare {
                    width: parent.width
                    height: 226
                    style: ml
                    share: root.usageShare
                    total: root.overview.total
                }

                // 使用时间图 · 时间河流（仍按当前选中 APP）
                Rectangle {
                    width: parent.width
                    height: Math.max(120, parent.height - 226 - 196 - 28)
                    radius: 18
                    color: ml.cardBg
                    border.width: 1
                    border.color: ml.cardBorder
                    TimeRiver {
                        anchors.fill: parent
                        anchors.margins: 16
                        style: ml
                        app: root.current
                    }
                }

                // 今日事项（与日历同步）
                CalendarSyncList {
                    id: calendarSync
                    width: parent.width
                    height: 196
                    style: ml
                    onOpenCalendar: root.requestNavigate("calendar")
                }
            }
        }
    }

}
