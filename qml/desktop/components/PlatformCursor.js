.pragma library
// 平台光标（单一来源）：同一语义在 macOS 与 Windows/Linux 上映射到不同 shape。
// Windows/Linux 分支保持历史行为不变，只有 macOS 走 AppKit 惯例。
// （.pragma library 必须在文件前 128 字节内，见 TagPalette.js 同款说明）
//
// macOS 惯例依据（AppKit / HIG）：
//   button   —— 指针手（pointingHandCursor）在 macOS 上专指「链接」。原生按钮、开关、
//               滑块、弹出菜单、列表行一律保持箭头；见 Finder / 日历 / 系统设置。
//   disabled —— operationNotAllowedCursor 只在拖放落到非法目标时出现；禁用控件靠变暗
//               表达，指针仍是箭头。
//   grab     —— macOS 没有 SizeAll 对应的系统光标，Qt 会退回自带位图
//               （libqcocoa.dylib 内的 sizeallcursor.png，Windows/X11 造型），
//               故改用真实的 openHandCursor。
//   place    —— dragCopyCursor 的绿色 + 徽标表示「松手会复制正在拖动的东西」，
//               不适合做工具的静止悬停态；macOS 上落笔类工具用十字。
//
// 未纳入本表（已经是 macOS 原生的，勿动）：IBeam / Cross / SizeHor / SizeVer /
// SizeFDiag / SizeBDiag —— 这些在 cocoa 插件里都映射到真实 NSCursor。

function _mac() {
    return Qt.platform.os === "osx";
}

// 可点击控件（按钮 / 导航行 / 单元格 / 开关 / 滑块 / 下拉项 / 步进器）。
function button() {
    return _mac() ? Qt.ArrowCursor : Qt.PointingHandCursor;
}

// 当前不可用的控件。
function disabled() {
    return _mac() ? Qt.ArrowCursor : Qt.ForbiddenCursor;
}

// 抓取并移动对象（便签拖拽条 / 文字块 Alt 拖动 / 选区整体移动）。
function grab() {
    return _mac() ? Qt.OpenHandCursor : Qt.SizeAllCursor;
}

// 放置类工具的悬停态（备忘黑板「便签」工具）。
function place() {
    return _mac() ? Qt.CrossCursor : Qt.DragCopyCursor;
}
