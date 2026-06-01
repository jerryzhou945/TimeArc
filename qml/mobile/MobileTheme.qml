import QtQuick

QtObject {
    id: theme

    property bool isDark: true

    readonly property color bg: isDark ? "#0C0D0F" : "#FAF7F2"
    readonly property color card: isDark ? "#15171A" : "#FFFFFF"
    readonly property color cardElevated: isDark ? "#1B1F24" : "#F4EFE8"
    readonly property color border: isDark ? "#2B3036" : "#E5DDD0"
    readonly property color textPrimary: isDark ? "#F4F4F5" : "#2A2318"
    readonly property color textSecondary: isDark ? "#A8ADB7" : "#6B5D4E"
    readonly property color textMuted: isDark ? "#6E7582" : "#A8967E"
    readonly property color accent: isDark ? "#8BA1C0" : "#6E8FB0"
    readonly property color green: isDark ? "#82AD8B" : "#5E9168"
    readonly property color amber: isDark ? "#C19B5C" : "#A87E3C"
    readonly property color red: isDark ? "#C98383" : "#B06868"
    readonly property color pill: isDark ? "#1B1F24" : "#EDE8E0"
    readonly property color pillText: isDark ? "#8BA1C0" : "#6E8FB0"
    readonly property color tabBarBg: isDark ? "#F00C0D0F" : "#F5FAF7F2"
    readonly property color tabBarBorder: isDark ? "#2B3036" : "#E5DDD0"
    readonly property color tabActive: isDark ? "#8BA1C0" : "#6E8FB0"
    readonly property color tabInactive: isDark ? "#6E7582" : "#A8967E"
    readonly property color shadowColor: isDark ? "#99000000" : "#1A503C1E"
    readonly property color glowColor: isDark ? "#668BA1C0" : "#406E8FB0"
    readonly property color warmGlowColor: isDark ? "#44C19B5C" : "#33A87E3C"

    function colorFor(key) {
        if (key === "accent")
            return accent
        if (key === "green")
            return green
        if (key === "amber")
            return amber
        if (key === "red")
            return red
        return textMuted
    }
}
