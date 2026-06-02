// 记忆湖演示数据（阶段一：写死，1:1 对应设计稿 memory_lake_v25_win11_style.html）。
// 阶段二会换成 usageStatManager / frontmostRepository 的真实数据，详见
// docs/memory-lake-implementation-plan.md §4。
.pragma library

// 卡牌按 DOM 顺序（与设计稿一致）。times: [开始, 结束, 宽px, y%]。
var apps = [
    {
        name: "8幡出口", type: "Game · Horror Walking Sim", time: "2.6h", progress: 1.00,
        image: "exit8.png", mood: "循环探索",
        analysis: "今天使用时间最长。游玩集中在 20:10 到 22:45，中间只有短暂暂停。系统判断这是一次连续的沉浸式探索体验。",
        launches: "3 次", longest: "70 min",
        times: [["19:40", "20:05", 38, 25], ["20:10", "21:20", 122, 48], ["21:35", "22:45", 118, 68]]
    },
    {
        name: "千恋万花", type: "Game · Visual Novel", time: "2.1h", progress: 0.81,
        image: "senren.png", mood: "剧情阅读",
        analysis: "使用时段主要在下午和深夜。系统把它识别为低操作频率、高阅读连续性的剧情体验。",
        launches: "4 次", longest: "50 min",
        times: [["14:10", "15:00", 82, 34], ["15:15", "15:55", 66, 48], ["23:00", "23:35", 56, 76]]
    },
    {
        name: "P3R", type: "Game · JRPG", time: "1.2h", progress: 0.46,
        image: "p3r.png", mood: "章节推进",
        analysis: "这段使用更像一次章节推进。时间集中在傍晚，使用长度中等，但连续性较高。",
        launches: "2 次", longest: "42 min",
        times: [["17:30", "18:12", 72, 45], ["18:22", "18:50", 48, 56]]
    },
    {
        name: "ELDEN RING", type: "Game · Action RPG", time: "1.8h", progress: 0.69,
        image: "elden.png", mood: "高强度战斗",
        analysis: "使用集中在晚间。系统识别到更高的操作密度，所以它更像一次高强度挑战。",
        launches: "2 次", longest: "70 min",
        times: [["21:05", "21:40", 62, 54], ["22:00", "23:10", 124, 73]]
    },
    {
        name: "Figma", type: "Creative App · Design", time: "48m", progress: 0.31,
        image: "desktop.png", mood: "界面整理",
        analysis: "Figma 使用集中在下午，属于短时间的设计整理与局部调整。",
        launches: "4 次", longest: "25 min",
        times: [["13:20", "14:08", 78, 31]]
    },
    {
        name: "VS Code", type: "Work App · Coding", time: "36m", progress: 0.23,
        image: "desktop.png", mood: "轻量开发",
        analysis: "VS Code 的使用较短，更像配合设计原型进行局部修补。",
        launches: "5 次", longest: "18 min",
        times: [["16:05", "16:41", 58, 42]]
    },
    {
        name: "Discord", type: "Social · Chat", time: "29m", progress: 0.19,
        image: "desktop.png", mood: "碎片交流",
        analysis: "Discord 由多个短片段组成，它更像背景沟通，而不是主要任务。",
        launches: "9 次", longest: "12 min",
        times: [["12:40", "12:48", 20, 28], ["19:10", "19:22", 25, 51], ["23:20", "23:29", 18, 79]]
    },
    {
        name: "Chrome", type: "Browser · Search", time: "21m", progress: 0.13,
        image: "desktop.png", mood: "资料查找",
        analysis: "Chrome 使用时间较短，主要用于查询与资料跳转。",
        launches: "6 次", longest: "11 min",
        times: [["11:20", "11:30", 24, 22], ["15:00", "15:11", 24, 47]]
    },
    {
        name: "Notion", type: "Note · Planning", time: "16m", progress: 0.10,
        image: "desktop.png", mood: "记录整理",
        analysis: "Notion 使用时间较短，主要承担记录和整理功能。",
        launches: "2 次", longest: "16 min",
        times: [["10:10", "10:26", 34, 18]]
    }
];

// 排行榜顺序（按时长降序）：对应卡牌下标。
var ranking = [0, 1, 3, 2, 4, 5, 6, 7, 8];

// 左栏概览 / 今日主题。
var overview = { total: "8.9h", sub: "今日 · 42 次切换" };
var todayTheme = {
    kicker: "今日主题", title: "游戏沉浸",
    desc: "游戏类占比最高，晚间有明显连续使用段。", ratio: 0.73
};

// 右栏时间刻度。
var timeRuler = ["10:00", "14:00", "18:00", "22:00"];
var timeAxis = [
    { label: "10:00", y: 0.18 }, { label: "16:00", y: 0.42 },
    { label: "20:00", y: 0.66 }, { label: "24:00", y: 0.86 }
];

// 月度回顾 11 屏（1:1 对应设计稿 summary-slide）。
// type 决定布局模板；bgIndex 指向 apps 下标的封面图（-1 = 无）；transition 决定转场。
var recap = {
    headerLeft: "Memory Lake Monthly Recap · 2026.06",
    headerRight: "滚轮 / 按钮逐步播放 · APP 一个一个登场",
    modeNote: "首次播放会按顺序展开，点击画面可加速。看完后右侧目录会解锁。",
    slides: [
        {
            step: "月度封面", kicker: "01 · 月度封面", type: "cover", bgIndex: -1, transition: "zoom",
            title: "六月的记忆湖\n从一段长时间沉浸开始。",
            subtitle: "这不是单纯的使用时间统计，而是一段设备使用轨迹。系统会按软件、时段、趋势和变化，把这个月的行为一点点展开。",
            metrics: [
                { label: "月度总使用", value: "118.6h" },
                { label: "最高类别", value: "游戏 64%" },
                { label: "最活跃时段", value: "20:00–24:00" }
            ]
        },
        {
            step: "月初到月末", kicker: "02 · 月初到月末", type: "monthMap", bgIndex: -1, transition: "rise",
            title: "你的使用强度在月末明显抬升。",
            subtitle: "月初的使用比较分散。到月中以后，游戏和设计软件的使用段开始变长。月末出现连续使用高峰。",
            monthMap: [
                { h: 0.30, value: "3.1h", day: "Jun 01" }, { h: 0.45, value: "4.4h", day: "Jun 04" },
                { h: 0.38, value: "3.8h", day: "Jun 07" }, { h: 0.55, value: "5.3h", day: "Jun 10" },
                { h: 0.70, value: "6.6h", day: "Jun 15" }, { h: 0.84, value: "7.9h", day: "Jun 22" },
                { h: 0.96, value: "8.7h", day: "Jun 28" }
            ]
        },
        {
            step: "8幡出口", kicker: "03 · 第一个主角", type: "poster", bgIndex: 0, transition: "zoom",
            posterTitle: "8幡出口", posterSub: "31h · 本月最长使用",
            title: "它不是卡牌，而是一段夜间循环。",
            subtitle: "8幡出口在本月留下最深的时间痕迹。它集中出现在夜间，单次连续时长很高。系统把它识别为“循环探索型沉浸”。",
            stats: [
                { label: "最长连续", value: "92m" }, { label: "主要时段", value: "20:10–23:00" },
                { label: "关键词", value: "探索 / 循环" }
            ]
        },
        {
            step: "千恋万花", kicker: "04 · 第二个主角", type: "split", bgIndex: 1, transition: "wipe",
            title: "千恋万花像一条慢速阅读的河。",
            subtitle: "它不像动作游戏那样产生高频操作。它更像一段安静的阅读时间，常出现在任务结束后的放松时段。",
            stats: [
                { label: "月度时长", value: "25h" }, { label: "平均单次", value: "46m" },
                { label: "使用性格", value: "剧情 / 放松" }
            ]
        },
        {
            step: "ELDEN RING", kicker: "05 · 第三个主角", type: "orbit", bgIndex: 3, transition: "rotate",
            title: "ELDEN RING 是本月的高强度重力场。",
            subtitle: "它不一定占用最长总时长，但每次出现都把注意力密度拉高。",
            orbit: [
                { a: -25, value: "21h", label: "月度使用" }, { a: 35, value: "78m", label: "最长连续" },
                { a: 105, value: "Jun 22", label: "高峰日期" }, { a: 185, value: "挑战", label: "月度关键词" }
            ]
        },
        {
            step: "P3R", kicker: "06 · 第四个主角", type: "article", bgIndex: 2, transition: "rise",
            title: "P3R 的时间更像一本章节日志。",
            articleTitle: "稳定推进，而不是爆发。",
            articleBody: "P3R 在本月没有占据最高时长，但出现得很稳定。系统把它识别为“章节推进型使用”：每次打开都有明确目标，结束也比较自然。",
            stats: [
                { label: "使用节奏", value: "稳定" }, { label: "平均单次", value: "38m" },
                { label: "关键词", value: "推进 / 日常" }
            ]
        },
        {
            step: "一天里的轨迹", kicker: "07 · 一天里的轨迹", type: "timeline", bgIndex: -1, transition: "wipe",
            title: "这些软件并不是随机出现的。",
            subtitle: "从时间段来看，白天更偏向工具和沟通，晚上更偏向游戏和长时间沉浸。",
            strips: [
                { tag: "下午 · 创作与资料", apps: "Figma / VS Code / Chrome", segs: [[0.18, 0.24], [0.46, 0.12]] },
                { tag: "傍晚 · 章节推进", apps: "P3R", segs: [[0.52, 0.18]] },
                { tag: "夜间 · 长段沉浸", apps: "8幡出口 / 千恋万花 / ELDEN RING", segs: [[0.68, 0.13], [0.82, 0.15]] }
            ]
        },
        {
            step: "趋势变化", kicker: "08 · 趋势变化", type: "trend", bgIndex: -1, transition: "rotate",
            title: "月末出现明显高峰，使用重心向游戏偏移。",
            subtitle: "这条曲线模拟本月每日总使用时长。你可以把它看作湖面水位。越往后，游戏类软件把水位推得越高。"
        },
        {
            step: "月度关键词", kicker: "09 · 月度关键词", type: "keywords", bgIndex: -1, transition: "rise",
            title: "这个月的关键词不是效率，而是沉浸。",
            subtitle: "系统根据软件类别、连续使用时长、启动次数和时间段生成关键词。它们代表这个月最常出现的使用状态。",
            keywords: ["沉浸", "夜间游戏", "剧情阅读", "Boss 挑战", "设计整理", "碎片沟通", "连续使用"],
            major: "沉浸"
        },
        {
            step: "相比上月", kicker: "10 · 对比上个月", type: "comparison", bgIndex: -1, transition: "wipe",
            title: "相比上个月，游戏更集中，创作更短促。",
            comparisons: [
                { label: "游戏类时间", change: "+23%", down: false, desc: "主要由 8幡出口、千恋万花、ELDEN RING 拉高。" },
                { label: "创作类时间", change: "-12%", down: true, desc: "Figma 和 VS Code 使用变短，更像阶段性调整。" },
                { label: "社交碎片", change: "+8%", down: false, desc: "Discord 出现次数更多，但单次使用时长较短。" }
            ]
        },
        {
            step: "月度标签", kicker: "11 · 月度记录片", type: "ticket", bgIndex: -1, transition: "ticket",
            title: "六月标签已经生成。",
            subtitle: "这张标签像一张设备使用的“票根”，把本月的主要时间、最高类别和变化保存下来。",
            ticket: { title: "六月\n记忆标签", rows: ["总使用 118.6h", "最高类别：游戏", "关键词：沉浸", "较上月 +23%"] }
        }
    ]
};

function imagePath(file) {
    return Qt.resolvedUrl("../../../resources/memorylake/" + file);
}
