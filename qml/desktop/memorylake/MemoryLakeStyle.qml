import QtQuick

// 记忆湖统一色板。夜晚 = 设计稿深色霓虹原值（1:1）；白天 = 派生浅色映射。
// 布局尺寸、动画时长、交互逻辑两套主题完全一致，只换颜色与发光强度。
// 详见 docs/memory-lake-implementation-plan.md §5。
QtObject {
    id: style

    property bool night: true

    // 霓虹强调色（两套主题共用，白天略降发光）
    readonly property color aqua: "#9FE7EE"
    readonly property color violet: "#9B8BFF"
    readonly property color pink: "#D88AAC"

    // 整体舞台底（记忆窗口背景）
    readonly property color stageBg: night ? "#070A11" : "#F4EFE6"
    readonly property color stageGlow1: night ? Qt.rgba(0.62, 0.90, 0.93, 0.07)
                                              : Qt.rgba(0.62, 0.90, 0.93, 0.16)
    readonly property color stageGlow2: night ? Qt.rgba(0.61, 0.55, 1.0, 0.06)
                                              : Qt.rgba(0.61, 0.55, 1.0, 0.12)

    // 三栏面板（提高不透明度：左右栏会盖住滑到其后的非焦点卡牌，0.72 时卡牌清晰透出很违和；
    // QML 无逐面板实时背景模糊，故以更实的叠色来挡住后面的卡牌，仍保留一点点通透感）
    readonly property color panelBg: night ? Qt.rgba(0.043, 0.063, 0.106, 0.94)
                                            : Qt.rgba(1, 1, 1, 0.92)
    readonly property color panelBorder: night ? Qt.rgba(1, 1, 1, 0.075)
                                               : Qt.rgba(0.40, 0.34, 0.28, 0.22)
    readonly property color panelBorderStrong: night ? Qt.rgba(1, 1, 1, 0.13)
                                                     : Qt.rgba(0.40, 0.34, 0.28, 0.30)

    // 内层小卡（profile/overview/theme/usage/detail/time-tree/note）
    readonly property color cardBg: night ? Qt.rgba(1, 1, 1, 0.035)
                                          : Qt.rgba(1, 1, 1, 0.55)
    readonly property color cardBorder: night ? Qt.rgba(1, 1, 1, 0.065)
                                              : Qt.rgba(0.40, 0.34, 0.28, 0.18)

    // 记忆卡牌面
    readonly property color faceBg: night ? "#0D121D" : "#FBF7F0"
    readonly property color faceBorder: night ? Qt.rgba(1, 1, 1, 0.08)
                                             : Qt.rgba(0.40, 0.34, 0.28, 0.20)
    readonly property color faceBorderActive: night ? Qt.rgba(0.62, 0.90, 0.93, 0.55)
                                                   : Qt.rgba(0.40, 0.55, 0.52, 0.55)

    // 文字（接主题契约：白天用注入色，夜晚用设计稿值）
    property color injectedTextPrimary: "#2D2724"
    property color injectedTextSecondary: "#7C746D"
    readonly property color textPrimary: night ? Qt.rgba(1, 1, 1, 0.88) : injectedTextPrimary
    readonly property color textSecondary: night ? Qt.rgba(1, 1, 1, 0.56) : injectedTextSecondary
    readonly property color textTertiary: night ? Qt.rgba(1, 1, 1, 0.34)
                                               : Qt.rgba(0.40, 0.34, 0.28, 0.55)

    // 进度/数据条
    readonly property color trackBg: night ? Qt.rgba(1, 1, 1, 0.055)
                                           : Qt.rgba(0.40, 0.34, 0.28, 0.12)

    // 强调薄底（active 项 / pill）
    readonly property color accentSoft: night ? Qt.rgba(0.62, 0.90, 0.93, 0.075)
                                             : Qt.rgba(0.40, 0.55, 0.52, 0.16)
    readonly property color accentSoftBorder: night ? Qt.rgba(0.62, 0.90, 0.93, 0.17)
                                                   : Qt.rgba(0.40, 0.55, 0.52, 0.30)
    readonly property color accentText: night ? Qt.rgba(0.86, 0.96, 0.97, 0.88) : "#2F5C56"

    // 锁定（翻面）警示色
    readonly property color lockBg: night ? Qt.rgba(0.16, 0.11, 0.04, 0.52)
                                         : Qt.rgba(0.55, 0.42, 0.18, 0.20)
    readonly property color lockBorder: Qt.rgba(1, 0.84, 0.61, 0.22)
    readonly property color lockText: night ? Qt.rgba(1, 0.93, 0.80, 0.90) : "#7A5A1E"

    // APP 大背景图模糊层不透明度（.app-bg opacity .34）
    readonly property real ambientImageOpacity: night ? 0.34 : 0.22

    // 发光强度（白天显著降低）
    readonly property real glowStrength: night ? 1.0 : 0.45

    // 圆角
    readonly property int radiusPanel: 18
    readonly property int radiusCard: 18
    readonly property int radiusInner: 16
}
