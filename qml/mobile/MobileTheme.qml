import QtQuick

QtObject {
    id: theme

    property bool isDark: true
    property bool reducedMotion: false

    readonly property string fontFamily: Qt.platform.os === "windows"
                                         ? "Microsoft YaHei UI"
                                         : (Qt.platform.os === "android"
                                            ? "HarmonyOS Sans SC"
                                            : "PingFang SC")
    readonly property string numberFontFamily: Qt.platform.os === "windows"
                                               ? "Bahnschrift"
                                               : (Qt.platform.os === "android"
                                                  ? "Roboto"
                                                  : "DIN Alternate")

    readonly property color bg: isDark ? "#111317" : "#F5F6F8"
    readonly property color defaultCanvasTop:
        isDark ? "#182126" : "#F4F7F7"
    readonly property color defaultCanvasMiddle:
        isDark ? "#162326" : "#EAF1F1"
    readonly property color defaultCanvasBottom:
        isDark ? "#10171A" : "#E2EAEB"
    readonly property color surface: isDark ? "#1A1D22" : "#FFFFFF"
    readonly property color surfaceRaised: isDark ? "#23272D" : "#ECEFF2"
    readonly property color textPrimary: isDark ? "#F2F4F6" : "#17191D"
    readonly property color textSecondary: isDark ? "#C4CAD1" : "#4F5862"
    readonly property color textMuted: isDark ? "#9BA4AD" : "#626B74"
    readonly property color line: isDark ? "#30353B" : "#DCE1E6"
    readonly property color accent: "#2D7780"
    readonly property color accentBright: isDark ? "#78C7CE" : "#245F66"
    readonly property color accentSoft: isDark ? "#29484C" : "#DAEEF0"
    readonly property color memoryBrown: "#2D2724"
    readonly property color memoryBrownRaised: "#423A36"
    readonly property color memoryInk: "#F7F2ED"
    readonly property color memoryCopy: "#CFC3BA"
    readonly property color progressTrack: isDark ? "#394047" : "#D7DDE2"
    readonly property color tabActive: isDark ? "#FFFFFF" : "#17191D"
    readonly property color tabInactive: isDark ? "#A8B0B8" : "#66707A"
    readonly property color contentClear:
        isDark ? "#24070B0D" : "#78FFFFFF"
    readonly property color contentWash:
        isDark ? "#40070B0D" : "#98FFFFFF"
    readonly property color contentStrong:
        isDark ? "#70070B0D" : "#C8FFFFFF"
    readonly property color timelineLine:
        isDark ? "#4DFFFFFF" : "#6617191D"
    readonly property color wallpaperInk:
        isDark ? "#F7F8FA" : "#17191D"
    readonly property color wallpaperMuted:
        isDark ? "#DCE2E7" : "#343B43"
    readonly property color tabBarBg: contentStrong
    readonly property color tabBarBorder: timelineLine
    readonly property color wallpaperVeil: isDark ? "#22080A0D" : "#70FFFFFF"
    readonly property color wallpaperPageVeil:
        isDark ? "#30080A0D" : "#80FFFFFF"
    readonly property color glass: contentClear
    readonly property color glassStrong: contentStrong
    readonly property color glassLine: timelineLine
    readonly property color scrim: "#A8000000"
    readonly property color error: isDark ? "#FFB4AB" : "#A63D42"
    readonly property color success: isDark ? "#9CD5B2" : "#276A4B"
    readonly property color notificationRed: "#FF3B30"
    // 旧移动组件的兼容别名；页面迁移完成后仍保留为统一 token。
    readonly property color card: surface
    readonly property color cardElevated: surfaceRaised
    readonly property color cardSoft: surfaceRaised
    readonly property color border: line
    readonly property color borderSoft: line
    readonly property color accentText: accentBright
    readonly property color accentBorder: withAlpha(accent, 0.42)
    readonly property color green: success
    readonly property color amber: textMuted
    readonly property color red: error
    readonly property color pill: accentSoft
    readonly property color pillText: accentBright
    readonly property color shadowColor: isDark ? "#88000000" : "#22000000"
    readonly property color glowColor: withAlpha(accentBright, 0.36)
    readonly property color rankTrack: progressTrack
    readonly property color overlay: isDark ? "#C0111317" : "#D9FFFFFF"

    readonly property int controlHeight: 44
    readonly property int cardRadius: 16
    readonly property int controlRadius: 10
    readonly property int fastDuration: reducedMotion ? 0 : 180
    readonly property int normalDuration: reducedMotion ? 0 : 260

    function withAlpha(colorValue, alphaValue) {
        return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, alphaValue)
    }

    function panelColor(wallpaperActive, strong) {
        if (!wallpaperActive)
            return strong ? withAlpha(surface, 0.72)
                          : withAlpha(surface, 0.42)
        return strong ? contentStrong : contentClear
    }
}
