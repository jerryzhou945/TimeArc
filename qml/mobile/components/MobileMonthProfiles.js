.pragma library

var profiles = [
    {
        month: 1, season: "winter",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-01.jpg",
        accent: "#BFD9E6", accentInk: "#102A38",
        particleKind: "snow", particleCount: 24, layoutVariant: "quiet",
        eyebrow: "JANUARY · 冬日留白", title: "一月\n时间结冰",
        opening: "新年的第一段时间，在安静里慢慢有了形状。"
    },
    {
        month: 2, season: "winter",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-02.jpg",
        accent: "#E7C9D2", accentInk: "#482A34",
        particleKind: "melt", particleCount: 18, layoutVariant: "letter",
        eyebrow: "FEBRUARY · 微光解冻", title: "二月\n风开始软",
        opening: "一些习惯没有声张，却在早春之前悄悄返场。"
    },
    {
        month: 3, season: "spring",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-03.jpg",
        accent: "#BFD7B4", accentInk: "#1D3824",
        particleKind: "rain", particleCount: 28, layoutVariant: "window",
        eyebrow: "MARCH · 春雨初醒", title: "三月\n时间温室",
        opening: "第一段时间从雨后亮起，像一扇刚被推开的窗。"
    },
    {
        month: 4, season: "spring",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-04.jpg",
        accent: "#F0C2CC", accentInk: "#542A35",
        particleKind: "petal", particleCount: 22, layoutVariant: "bloom",
        eyebrow: "APRIL · 花影经过", title: "四月\n被风翻页",
        opening: "屏幕亮起又熄灭，日子像花影一样从手边经过。"
    },
    {
        month: 5, season: "spring",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-05.jpg",
        accent: "#F1D59C", accentInk: "#4B3513",
        particleKind: "dust", particleCount: 20, layoutVariant: "reading",
        eyebrow: "MAY · 日光长页", title: "五月\n光落在桌上",
        opening: "你把时间铺在许多小事上，也把五月读得很长。"
    },
    {
        month: 6, season: "summer",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-06.jpg",
        accent: "#B4E0C0", accentInk: "#153B2A",
        particleKind: "storm", particleCount: 30, layoutVariant: "rain",
        eyebrow: "JUNE · 雨季回声", title: "六月\n听见时间",
        opening: "最长的一场雨落在记录里，也落在你专注的深处。"
    },
    {
        month: 7, season: "summer",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-07.jpg",
        accent: "#D8E89B", accentInk: "#304110",
        particleKind: "firefly", particleCount: 26, layoutVariant: "night",
        eyebrow: "JULY · 萤火长夜", title: "七月\n晚风有光",
        opening: "深夜的使用留下微小亮点，连起来就是你的夏夜。"
    },
    {
        month: 8, season: "summer",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-08.jpg",
        accent: "#B6D9E2", accentInk: "#173A45",
        particleKind: "lateRain", particleCount: 30, layoutVariant: "lane",
        eyebrow: "AUGUST · 暮雨回程", title: "八月\n雨走得很慢",
        opening: "忙碌在傍晚降温，时间沿着湿润的街道回到身边。"
    },
    {
        month: 9, season: "autumn",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-09.jpg",
        accent: "#E8C876", accentInk: "#493512",
        particleKind: "grain", particleCount: 22, layoutVariant: "field",
        eyebrow: "SEPTEMBER · 风吹麦浪", title: "九月\n收下金色",
        opening: "规律开始变得清晰，许多短暂的投入有了收获。"
    },
    {
        month: 10, season: "autumn",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-10.jpg",
        accent: "#E8A66F", accentInk: "#4B2914",
        particleKind: "leaf", particleCount: 24, layoutVariant: "forest",
        eyebrow: "OCTOBER · 林间来信", title: "十月\n风写了信",
        opening: "常用的应用再次相遇，像秋日小径上重叠的脚步。"
    },
    {
        month: 11, season: "autumn",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-11.jpg",
        accent: "#D8CFA8", accentInk: "#3D3825",
        particleKind: "ginkgo", particleCount: 18, layoutVariant: "passage",
        eyebrow: "NOVEMBER · 初霜之后", title: "十一月\n光变得薄",
        opening: "日子安静下来，你仍在一些熟悉的地方留下时间。"
    },
    {
        month: 12, season: "winter",
        sceneSource: "qrc:/time_arc/resources/mobile/monthly/month-12.jpg",
        accent: "#D9E5EF", accentInk: "#243545",
        particleKind: "snow", particleCount: 30, layoutVariant: "home",
        eyebrow: "DECEMBER · 年末灯火", title: "十二月\n回到灯下",
        opening: "这一年的最后一段时间，被熟悉的光温柔接住。"
    }
]

function forMonth(month) {
    var normalized = Math.max(1, Math.min(12, Number(month) || 1))
    return profiles[normalized - 1]
}

