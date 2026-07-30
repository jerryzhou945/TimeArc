.pragma library

// 备忘 / 番茄全局快捷键的出厂默认值。
//
// 为什么单列一个文件：用它的有两处——DesktopAppShell（拿去绑 Shortcut）与
// DesktopProfilePage（键帽显示 + 读 KV 时的兜底）。两边各写一份字面量迟早会漂，
// 而这种漂移的表现是「设置页显示 N、实际生效的是 ⇧⌘N」，用户很难自己想明白。
//
// macOS 默认 ⇧⌘N / ⇧⌘P：菜单栏「显示」里本来就有这两条同名命令（MacMenuBar.qml），
// 出厂默认与之对齐，新用户不会一上来就拿到一个和打字抢键的裸字母。
// Windows/Linux 没有菜单栏，保持裸字母 N / P 不变。
//
// 文本用 Qt 可移植序列写法：Qt 在 macOS 上把 Ctrl 映射到 ⌘（同 MacMenuBar.qml 的
// "Ctrl+" 字面量），所以 "Ctrl+Shift+N" 在那边就是 ⇧⌘N。
function memoDefault() {
    return Qt.platform.os === "osx" ? "Ctrl+Shift+N" : "N";
}

function pomodoroDefault() {
    return Qt.platform.os === "osx" ? "Ctrl+Shift+P" : "P";
}

// which 为 "memo" / "pomo"，方便按当前编辑对象取默认值。
function defaultFor(which) {
    return which === "memo" ? memoDefault() : pomodoroDefault();
}

// 「停用」这件事在 macOS 上做不到：菜单行 显示 › 备忘黑板 / 番茄钟 自带 ⇧⌘N / ⇧⌘P 的
// key equivalent，那两行由 MacMenuBar 常驻、不受这里的键位设置管。存个空串只会得到
// 「设置里写着未设置、按下去照样开」的假象——上一版 memo_hotkey_n 开关就是这么废掉的。
// 所以 macOS 把删除键解释为「恢复出厂键位」，而出厂键位正是菜单行的那个键。
function canDisable() {
    return Qt.platform.os !== "osx";
}
