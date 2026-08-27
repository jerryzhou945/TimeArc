.pragma library

var profiles = [
    {
        month: 1, season: "winter",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-01.jpg",
        accent: "#BFD9E6", accentInk: "#102A38",
        particleKind: "snow", particleCount: 24, layoutVariant: "quiet",
        eyebrow: "JANUARY · Winter Margins", title: "January\nTime freezes over",
        opening: "The year's first stretch of time slowly takes shape in the quiet."
    },
    {
        month: 2, season: "winter",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-02.jpg",
        accent: "#E7C9D2", accentInk: "#482A34",
        particleKind: "melt", particleCount: 18, layoutVariant: "letter",
        eyebrow: "FEBRUARY · A Faint Thaw", title: "February\nThe wind softens",
        opening: "Some habits returned quietly, without announcement, just before early spring."
    },
    {
        month: 3, season: "spring",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-03.jpg",
        accent: "#BFD7B4", accentInk: "#1D3824",
        particleKind: "rain", particleCount: 28, layoutVariant: "window",
        eyebrow: "MARCH · First Spring Rain", title: "March\nA greenhouse of time",
        opening: "The first stretch brightens after the rain, like a window just pushed open."
    },
    {
        month: 4, season: "spring",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-04.jpg",
        accent: "#F0C2CC", accentInk: "#542A35",
        particleKind: "petal", particleCount: 22, layoutVariant: "bloom",
        eyebrow: "APRIL · Blossom Shadows", title: "April\nTurned by the wind",
        opening: "Screens lit and dimmed, and the days passed like blossom shadows through your hands."
    },
    {
        month: 5, season: "spring",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-05.jpg",
        accent: "#F1D59C", accentInk: "#4B3513",
        particleKind: "dust", particleCount: 20, layoutVariant: "reading",
        eyebrow: "MAY · Long Pages of Light", title: "May\nLight on the desk",
        opening: "You spread your time across many small things, and read May long."
    },
    {
        month: 6, season: "summer",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-06.jpg",
        accent: "#B4E0C0", accentInk: "#153B2A",
        particleKind: "storm", particleCount: 30, layoutVariant: "rain",
        eyebrow: "JUNE · Echoes of the Rains", title: "June\nHearing time",
        opening: "The longest rain fell into the record, and deep into your focus."
    },
    {
        month: 7, season: "summer",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-07.jpg",
        accent: "#D8E89B", accentInk: "#304110",
        particleKind: "firefly", particleCount: 26, layoutVariant: "night",
        eyebrow: "JULY · Fireflies, Long Nights", title: "July\nLight in the evening air",
        opening: "Late-night use left small points of light; joined up, they are your summer nights."
    },
    {
        month: 8, season: "summer",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-08.jpg",
        accent: "#B6D9E2", accentInk: "#173A45",
        particleKind: "lateRain", particleCount: 30, layoutVariant: "lane",
        eyebrow: "AUGUST · The Way Home in Rain", title: "August\nThe rain moves slowly",
        opening: "The rush cools by evening, and time comes back along wet streets."
    },
    {
        month: 9, season: "autumn",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-09.jpg",
        accent: "#E8C876", accentInk: "#493512",
        particleKind: "grain", particleCount: 22, layoutVariant: "field",
        eyebrow: "SEPTEMBER · Wind Through the Wheat", title: "September\nTaking in the gold",
        opening: "The pattern grew clear, and many brief efforts came to something."
    },
    {
        month: 10, season: "autumn",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-10.jpg",
        accent: "#E8A66F", accentInk: "#4B2914",
        particleKind: "leaf", particleCount: 24, layoutVariant: "forest",
        eyebrow: "OCTOBER · A Letter from the Woods", title: "October\nThe wind wrote",
        opening: "Familiar apps met again, like overlapping footsteps on an autumn path."
    },
    {
        month: 11, season: "autumn",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-11.jpg",
        accent: "#D8CFA8", accentInk: "#3D3825",
        particleKind: "ginkgo", particleCount: 18, layoutVariant: "passage",
        eyebrow: "NOVEMBER · After the First Frost", title: "November\nThe light thins",
        opening: "The days quietened, and you still left time in a few familiar places."
    },
    {
        month: 12, season: "winter",
        sceneSource: "qrc:/qt/qml/time_arc/resources/features/monthly-recap/month-12.jpg",
        accent: "#D9E5EF", accentInk: "#243545",
        particleKind: "snow", particleCount: 30, layoutVariant: "home",
        eyebrow: "DECEMBER · Year-End Lights", title: "December\nBack under the lamp",
        opening: "The year's last stretch of time, caught gently by a familiar light."
    }
]

function forMonth(month) {
    var normalized = Math.max(1, Math.min(12, Number(month) || 1))
    return profiles[normalized - 1]
}
