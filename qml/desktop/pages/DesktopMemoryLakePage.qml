import QtQuick
import QtQuick.Controls
import "../memorylake"
import "../memorylake/MemoryLakeMock.js" as Mock

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
    readonly property var apps: Mock.apps
    readonly property var current: apps[selectedIndex]
    readonly property bool locked: flippedIndex >= 0

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

    // —— 氛围灯光层 ——
    AmbientBackground {
        anchors.fill: parent
        style: ml
        appImage: Mock.imagePath(root.current.image)
    }

    // —— 三栏 ——
    Row {
        id: columns
        anchors.fill: parent
        anchors.margins: 4
        spacing: 18

        // ============ 左栏 ============
        GlassPanel {
            id: leftPanel
            width: 300
            height: parent.height
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
                            Text { text: Mock.overview.total; color: ml.textPrimary; font.pixelSize: 27; font.bold: true }
                            Text { text: Mock.overview.sub; color: ml.textTertiary; font.pixelSize: 11 }
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
                            Text { text: Mock.todayTheme.kicker; color: ml.aqua; font.pixelSize: 11; opacity: 0.85 }
                            Text { text: Mock.todayTheme.title; color: ml.textPrimary; font.pixelSize: 17; font.bold: true }
                            Text {
                                width: parent.width
                                text: Mock.todayTheme.desc
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
                                    width: parent.width * Mock.todayTheme.ratio
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

                // 月度回顾 CTA
                Rectangle {
                    id: recapCta
                    width: parent.width
                    height: 92
                    radius: 19
                    color: ctaHover.hovered ? Qt.rgba(1, 1, 1, ml.night ? 0.065 : 0.20) : ml.cardBg
                    border.width: 1
                    border.color: ctaHover.hovered ? Qt.rgba(0.62, 0.90, 0.93, 0.28) : Qt.rgba(0.62, 0.90, 0.93, 0.16)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5
                        Text { text: "MONTHLY RECAP"; color: ml.aqua; font.pixelSize: 11; opacity: 0.8 }
                        Text { text: "查看月度记忆回顾"; color: ml.textPrimary; font.pixelSize: 18; font.bold: true }
                        Text {
                            width: parent.width
                            text: "按顺序回放这个月的主要软件、趋势变化和关键词。"
                            color: ml.textSecondary; font.pixelSize: 11; wrapMode: Text.WordWrap
                            maximumLineCount: 2; elide: Text.ElideRight
                        }
                        Text { text: "开始回顾 →"; color: ml.accentText; font.pixelSize: 12; font.bold: true }
                    }
                    HoverHandler { id: ctaHover }
                    TapHandler { onTapped: recap.open() }
                }

                // 排行
                Rectangle {
                    width: parent.width
                    height: parent.height - 66 - 124 - 92 - 30
                    radius: 22
                    color: ml.cardBg
                    border.width: 1
                    border.color: ml.cardBorder
                    UsageRankList {
                        anchors.fill: parent
                        anchors.margins: 13
                        style: ml
                        apps: root.apps
                        ranking: Mock.ranking
                        selectedIndex: root.selectedIndex
                        locked: root.locked
                        onRequestSelect: function(cardIndex) { root.selectCard(cardIndex) }
                        onHoverCard: function(cardIndex) { if (!root.locked) root.previewIndex = cardIndex }
                        onUnhoverCard: root.previewIndex = -1
                    }
                }
            }
        }

        // ============ 中栏：卡牌轮盘 ============
        GlassPanel {
            id: centerPanel
            width: parent.width - 300 - 310 - 36
            height: parent.height
            style: ml

            CardCarousel {
                anchors.fill: parent
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
        }

        // ============ 右栏（阶段 A 静态，阶段 B 跟随选中）============
        GlassPanel {
            id: rightPanel
            width: 310
            height: parent.height
            style: ml

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // 详情卡
                DetailPanel {
                    width: parent.width
                    height: 250
                    style: ml
                    app: root.current
                }

                // 使用时间图 · 时间河流
                Rectangle {
                    width: parent.width
                    height: parent.height - 250 - 76 - 28
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

                // note
                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 18
                    color: ml.cardBg
                    border.width: 1
                    border.color: ml.cardBorder
                    Text {
                        anchors.fill: parent
                        anchors.margins: 14
                        text: root.locked ? "当前记忆已翻面并锁定。再次点击卡牌取消翻面后即可切换。"
                                          : "点击中心记忆查看分析。翻面后会暂时锁定当前记忆。"
                        color: ml.textSecondary; font.pixelSize: 13; wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    // —— 月度回顾覆盖层（盖住三栏）——
    RecapOverlay {
        id: recap
        anchors.fill: parent
        style: ml
        apps: root.apps
    }
}
