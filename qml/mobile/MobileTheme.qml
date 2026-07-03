import QtQuick

QtObject {
    id: theme

    property bool isDark: true

    readonly property string fontFamily: Qt.platform.os === "windows"
                                         ? "Microsoft YaHei UI"
                                         : (Qt.platform.os === "android" ? "Noto Sans CJK SC" : "PingFang SC")

    readonly property color bg: isDark ? "#060A10" : "#F7F9FC"
    readonly property color bgTop: isDark ? "#0B2740" : "#EAF3FA"
    readonly property color bgMid: isDark ? "#081A2A" : "#F3F7FB"
    readonly property color bgBottom: isDark ? "#060A10" : "#FFFFFF"
    readonly property color card: isDark ? "#0F1722" : "#FFFFFF"
    readonly property color cardElevated: isDark ? "#162131" : "#EEF3F8"
    readonly property color cardSoft: isDark ? "#101C2A" : "#F4F7FA"
    readonly property color border: isDark ? "#263342" : "#D6E0EA"
    readonly property color borderSoft: isDark ? "#1C2734" : "#E6ECF2"
    readonly property color textPrimary: isDark ? "#F6F8FB" : "#101820"
    readonly property color textSecondary: isDark ? "#B8C6D4" : "#4A5A68"
    readonly property color textMuted: isDark ? "#7B8A99" : "#8190A0"
    readonly property color accent: isDark ? "#9ED9F6" : "#256E9B"
    readonly property color accentText: isDark ? "#DDF6FF" : "#0E4F72"
    readonly property color accentSoft: isDark ? "#163044" : "#DDF0FA"
    readonly property color accentBorder: isDark ? "#31566B" : "#B8D8E8"
    readonly property color green: isDark ? "#8EC6A3" : "#2F7B58"
    readonly property color amber: isDark ? "#AAB4C2" : "#667789"
    readonly property color red: isDark ? "#D28D96" : "#B45463"
    readonly property color pill: isDark ? "#132233" : "#EAF1F7"
    readonly property color pillText: isDark ? "#DDF6FF" : "#1E668F"
    readonly property color tabBarBg: isDark ? "#F0060A10" : "#F8FFFFFF"
    readonly property color tabBarBorder: isDark ? "#1F2B38" : "#DDE6EF"
    readonly property color tabActive: isDark ? "#DDF6FF" : "#165A83"
    readonly property color tabInactive: isDark ? "#667586" : "#8A99A8"
    readonly property color shadowColor: isDark ? "#AA000000" : "#1F1C2833"
    readonly property color glowColor: isDark ? "#669ED9F6" : "#33256E9B"
    readonly property color rankTrack: isDark ? "#263343" : "#DDE7F0"
    readonly property color overlay: isDark ? "#B0060A10" : "#CCFFFFFF"

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
