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

    // —— 当前选中的记忆（阶段 B 接交互）——
    property int selectedIndex: 0
    readonly property var apps: Mock.apps
    readonly property var current: apps[selectedIndex]

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
                    TapHandler { onTapped: console.log("[memorylake] recap requested (阶段 D)") }
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
                        onRequestSelect: function(cardIndex) { root.selectedIndex = cardIndex }
                    }
                }
            }
        }

        // ============ 中栏（阶段 A 占位，阶段 B 接卡牌轮盘）============
        GlassPanel {
            id: centerPanel
            width: parent.width - 300 - 310 - 36
            height: parent.height
            style: ml

            Rectangle {
                anchors.fill: parent
                anchors.margins: 18
                radius: 18
                color: ml.night ? Qt.rgba(0.012, 0.027, 0.055, 0.58) : Qt.rgba(1, 1, 1, 0.30)
                border.width: 1
                border.color: ml.cardBorder
                clip: true

                // 中线
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 90
                    anchors.rightMargin: 90
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(0.62, 0.90, 0.93, 0.12) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                // wheel-tip
                Rectangle {
                    x: 26; y: 22
                    width: tipText.width + 22; height: 34; radius: 17
                    color: Qt.rgba(0, 0, 0, ml.night ? 0.18 : 0.06)
                    border.width: 1
                    border.color: ml.cardBorder
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: "滚轮 / 左侧排行切换当前 APP，悬停预览"
                        color: ml.textTertiary
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "卡牌轮盘 · 阶段 B 接入"
                    color: ml.textTertiary
                    font.pixelSize: 13
                }
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
                Rectangle {
                    width: parent.width
                    height: 250
                    radius: 18
                    color: ml.cardBg
                    border.width: 1
                    border.color: ml.cardBorder
                    clip: true
                    Column {
                        anchors.fill: parent
                        Text {
                            x: 15; topPadding: 14
                            width: parent.width - 30
                            text: root.current.name + " · 使用时间分布"
                            color: ml.textPrimary; font.pixelSize: 16; font.bold: true
                            elide: Text.ElideRight
                        }
                        Item {
                            width: parent.width; height: 104
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: Mock.imagePath(root.current.image)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: ml.night ? Qt.rgba(0.012, 0.027, 0.055, 0.86) : Qt.rgba(1, 1, 1, 0.4) }
                                }
                            }
                        }
                        Column {
                            x: 15; width: parent.width - 30; topPadding: 12; spacing: 6
                            Text { text: root.current.type + " · " + root.current.time; color: ml.textTertiary; font.pixelSize: 12 }
                            Text { text: root.current.mood; color: ml.textPrimary; font.pixelSize: 21; font.bold: true }
                            Text {
                                width: parent.width
                                text: root.current.analysis
                                color: ml.textSecondary; font.pixelSize: 13; wrapMode: Text.WordWrap
                                maximumLineCount: 2; elide: Text.ElideRight
                            }
                        }
                    }
                }

                // 使用时间图（阶段 B 接 TimeRiver 组件）
                Rectangle {
                    width: parent.width
                    height: parent.height - 250 - 76 - 28
                    radius: 18
                    color: ml.cardBg
                    border.width: 1
                    border.color: ml.cardBorder
                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Item {
                            width: parent.width; height: 18
                            Text { anchors.left: parent.left; text: "使用时间图 · 时间河流"; color: ml.textPrimary; font.pixelSize: 16; font.bold: true }
                            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "几点到几点"; color: ml.textTertiary; font.pixelSize: 11 }
                        }
                        Rectangle {
                            width: parent.width
                            height: parent.height - 28
                            radius: 16
                            color: ml.night ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.25)
                            border.width: 1
                            border.color: ml.cardBorder
                            Text {
                                anchors.centerIn: parent
                                text: "时间河流 · 阶段 B 接入"
                                color: ml.textTertiary; font.pixelSize: 12
                            }
                        }
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
                        text: "点击中心记忆查看分析。翻面后会暂时锁定当前记忆。"
                        color: ml.textSecondary; font.pixelSize: 13; wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
