import QtQuick

QtObject {
    id: theme

    property color pageTop: "#EEF3E9"
    property color pageBottom: "#F7F0E4"
    property color panel: "#FFFDF7"
    property color panelSoft: "#F8F2E7"
    property color panelGlass: "#FFFDF9"
    property color cardStroke: "#E6DDCE"
    property color softStroke: "#EEE6D8"

    property color textPrimary: "#123A35"
    property color textSecondary: "#6E8076"
    property color textMuted: "#93A297"
    property color accentGreen: "#8FBEA3"
    property color accentGreenDeep: "#4D8D73"
    property color accentGreenSoft: "#CFE3D2"
    property color accentCream: "#F1E5BD"
    property color accentGold: "#D9BC6E"
    property color accentYellow: "#E7D98F"
    property color accentBlue: "#A9CCD5"
    property color accentLavender: "#CFC6DD"
    property color accentBlush: "#E6C8C8"
    property color shadow: "#A89372"
    property color onAccent: "#FFFFFF"
    property color headerStart: "#DDEADA"
    property color headerEnd: "#F4EACB"
    property color progressTrack: "#EAE1D2"
    property color segmentedTrack: "#EFE8DA"
    property color navPlusStart: "#9BC8A9"
    property color navPlusEnd: "#C9D99B"
    property color projectButtonEnd: "#BDD58B"
    property color toggleOff: "#E3DED3"
    property color barStart: "#A7CFB3"
    property color barEnd: "#DDE3B4"
    property color chartStudy: "#77B5BF"
    property color chartWork: "#9BC8A9"
    property color chartFun: "#D9C66E"
    property color chartOther: "#E3A85F"
    property color lakeCard: "#DDEADB"
    property color lakeSkyTop: "#EEF0D8"
    property color lakeSkyMid: "#CFE1C9"
    property color lakeSkyBottom: "#AFCFBE"
    property color lakeText: "#FFFDF7"
    property color lakeTextSoft: "#FFF7DD"
    property color lakeGauge: "#8FC8C0"

    property int pageMargin: 18
    property int radiusCard: 24
    property int radiusLarge: 30
    property int radiusPill: 18
    property int navHeight: 72
    property int bottomSafe: 12
    property int topSafe: 14

    property int fontHero: 34
    property int fontTitle: 24
    property int fontSection: 18
    property int fontBody: 14
    property int fontCaption: 12

    function tagColor(tag) {
        if (tag === "学习") return accentGreenSoft
        if (tag === "工作") return "#E8D9BE"
        if (tag === "运动") return "#C7DED0"
        if (tag === "娱乐") return accentBlush
        if (tag === "阅读") return accentBlue
        if (tag === "社交") return accentLavender
        if (tag === "生活") return "#DDE7C7"
        return "#E8E2D7"
    }

    function tagIcon(tag) {
        if (tag === "学习") return "◌"
        if (tag === "工作") return "□"
        if (tag === "运动") return "♧"
        if (tag === "娱乐") return "◇"
        if (tag === "阅读") return "▣"
        if (tag === "社交") return "✦"
        if (tag === "生活") return "⌂"
        return "•"
    }

    function appIconColor(name) {
        var lower = (name || "").toLowerCase()
        if (lower.indexOf("chrome") >= 0) return "#D9E5C0"
        if (lower.indexOf("code") >= 0 || lower.indexOf("studio") >= 0) return "#B9D5DE"
        if (lower.indexOf("discord") >= 0) return "#CECBE6"
        if (lower.indexOf("lock") >= 0) return "#BFD8CF"
        return accentGreenSoft
    }

    function chatColor(kind) {
        if (kind === "AI") return accentGreenSoft
        if (kind === "项目") return "#D9D1E5"
        if (kind === "记忆") return "#E7CACA"
        return "#F0DDAA"
    }
}
