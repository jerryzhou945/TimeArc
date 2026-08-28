.pragma library
// 标签调色板（单一来源）：每个 tag 一份固定语义色「ink」+ 图标。
// 首页/日历/统计/计时四页的 tagColor() 与 TagChip 全部委托到这里，杜绝多份色表漂移。
// 语义：Study=violet Work=amber Exercise=green Entertainment=pink
// Reading=sky Social=coral Life=mint Other=steel。标签名随 English-first 改为英文源串，
// 显示时由 I18n 翻译；这里匹配的是源串，不是显示名。
// ink 直接用作 chip 文字 + 导色点；chip 底/边由 ink 低透明度派生（见 TagChip.qml）。
// （.pragma library 必须在文件前 128 字节内，否则 Qt CMake 仍会告警，见 Qt6QmlMacros.cmake LIMIT_INPUT 128）

// 固定标签序列（单一来源）：便签 tag 选择器 / 日历 fixedTags 等共享，杜绝各处自带一份。
// 与 DatabaseManager::insertDefaultTags() 和 ProjectManager::kFixedTags 必须一致。
function tagList() {
    return ["Study", "Work", "Exercise", "Entertainment", "Reading", "Social", "Life", "Other"];
}

function tagColor(tag) {
    if (tag === "Study") return "#B6A2FF"   // 紫罗兰：专注/智识
    if (tag === "Work") return "#F7C56A"   // 琥珀金：工作/产出
    if (tag === "Exercise") return "#3BE88C"   // 春绿：运动/活力
    if (tag === "Entertainment") return "#FF93C9"   // 亮粉：娱乐/玩乐
    if (tag === "Reading") return "#6FB8FF"   // 天蓝：阅读/书墨
    if (tag === "Social") return "#FF9A6E"   // 珊瑚：社交/连接
    if (tag === "Life") return "#74EAC2"   // 薄荷：生活/平衡
    return "#AEB6C6"                       // 钢灰：其他（低饱和，永不抢戏）
}

function tagIcon(tag) {
    if (tag === "Study") return "✦"
    if (tag === "Work") return "▣"
    if (tag === "Exercise") return "●"
    if (tag === "Entertainment") return "★"
    if (tag === "Reading") return "✎"
    if (tag === "Social") return "♥"
    if (tag === "Life") return "☀"
    return "•"
}
