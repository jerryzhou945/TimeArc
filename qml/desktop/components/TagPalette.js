// 标签调色板（单一来源）：每个 tag 一份固定语义色「ink」+ 图标。
// 首页/日历/统计/计时四页的 tagColor() 与 TagChip 全部委托到这里，杜绝多份色表漂移。
// 语义：学习=violet 工作=amber 运动=green 娱乐=pink 阅读=sky 社交=coral 生活=mint 其他=steel。
// ink 直接用作 chip 文字 + 导色点；chip 底/边由 ink 低透明度派生（见 TagChip.qml）。
.pragma library

// 固定标签序列（单一来源）：便签 tag 选择器 / 日历 fixedTags 等共享，杜绝各处自带一份。
function tagList() {
    return ["学习", "工作", "运动", "娱乐", "阅读", "社交", "生活", "其他"];
}

function tagColor(tag) {
    if (tag === "学习") return "#B6A2FF"   // 紫罗兰：专注/智识
    if (tag === "工作") return "#F7C56A"   // 琥珀金：工作/产出
    if (tag === "运动") return "#3BE88C"   // 春绿：运动/活力
    if (tag === "娱乐") return "#FF93C9"   // 亮粉：娱乐/玩乐
    if (tag === "阅读") return "#6FB8FF"   // 天蓝：阅读/书墨
    if (tag === "社交") return "#FF9A6E"   // 珊瑚：社交/连接
    if (tag === "生活") return "#74EAC2"   // 薄荷：生活/平衡
    return "#AEB6C6"                       // 钢灰：其他（低饱和，永不抢戏）
}

function tagIcon(tag) {
    if (tag === "学习") return "✦"
    if (tag === "工作") return "▣"
    if (tag === "运动") return "●"
    if (tag === "娱乐") return "★"
    if (tag === "阅读") return "✎"
    if (tag === "社交") return "♥"
    if (tag === "生活") return "☀"
    return "•"
}
