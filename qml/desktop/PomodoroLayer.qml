import QtQuick
import QtQuick.Controls
import "memorylake"

// 番茄钟层：浮窗 + 完成庆祝 + 完成时的通知/庆祝策略，Shell 的同级层。
//
// 为什么从 MemoOverlay 里搬出来：番茄钟和备忘黑板之间没有任何数据关系，它只是当初
// 照 v88 的黑板做替换时长在了黑板的子树里。代价是旧的 MemoOverlay.togglePomodoro()
// 必须先 `open = true` 才能让浮窗可见——快捷键/菜单开番茄，用户得到的是一整块黑板，
// 而且黑板被记忆卡翻面锁住时番茄跟着一起打不开。现在浮窗与黑板同级，任何页面下都能开。
//
// 浮窗的持久化键仍是 memoryLakeMemoPomodoro（见 PomodoroWidget），沿用旧键是为了不丢
// 用户在途的那一程；键名里的 Memo 从此只是历史。
Item {
    id: layer

    property MemoryLakeStyle style
    property string languageMode: "zh"
    property var store: null            // UI 私有持久化后端（Shell 注入 settingsRepository）
    // 设置页键帽正在等按键时让出 Esc：那里 Esc 是「取消捕获」，不该被这里抢走。
    property bool escapeEnabled: true

    readonly property bool shown: pomodoro.shown
    readonly property bool running: pomodoro.running

    // 番茄钟完成 → 通知 Shell（系统通知；不受结束庆祝开关影响）。
    signal finished(string title)

    function toggle() { pomodoro.shown = !pomodoro.shown; }
    function show() { pomodoro.shown = true; }
    function hide() { pomodoro.shown = false; }

    function _pickVariant() {
        var v = ["FOCUS COMPLETE", "GOOD SESSION", "MEMORY SAVED", "WELL DONE"];
        return v[Math.floor(Math.random() * v.length)];
    }

    // Esc 收起：先庆祝弹层，再浮窗。**不停表**——收起只是收起视图，那一程还在跑，
    // 再按快捷键就能把它调回来。Esc 是个太容易误按的键，不该用来销毁一程专注。
    function dismiss() {
        if (pomodoroComplete.shown) { pomodoroComplete.shown = false; return; }
        pomodoro.shown = false;
    }

    // 为什么用 Shortcut 而不是 Keys.onPressed：备忘黑板打开时是它持焦（MemoOverlay 的
    // focus: open + Keys.onPressed 里 Esc 关黑板）。Qt 的快捷键先于按键送到聚焦项——
    // 黑板没实现 Keys.onShortcutOverride，于是番茄开着时这条先吃掉 Esc，黑板收不到；
    // 番茄一收起本条即失效，Esc 原样落回黑板。两者都开时「先退番茄」由此成立，
    // 也不必让任何一方知道另一方存在。全平台一致：这条不经 macOS 菜单栏。
    Shortcut {
        sequences: ["Esc"]
        enabled: layer.escapeEnabled && (pomodoro.shown || pomodoroComplete.shown)
        onActivated: layer.dismiss()
    }

    // 层本身不吃事件（Item 无命中区域），只有浮窗和庆祝弹层各自的 MouseArea 生效，
    // 因此铺满整窗不会挡住底下的页面交互；浮窗的拖动钳制也正好按整窗算。
    anchors.fill: parent

    PomodoroWidget {
        id: pomodoro
        style: layer.style
        languageMode: layer.languageMode
        shown: false
    }

    // 完成由引擎判定（单一探测器，功能文 G7/C13）；庆祝文案是展示用词，留在 QML。
    Connections {
        target: pomodoroManager
        function onFinished() {
            layer.finished(pomodoro.title);          // #3 系统通知（不受结束庆祝开关影响）
            // #2 结束庆祝可在设置页关闭（pomodoro_celebrate）；关则静默完成，不弹全屏庆祝。
            if (layer.store && layer.store.getBool && !layer.store.getBool("pomodoro_celebrate", true))
                return;
            pomodoroComplete.variant = layer._pickVariant();
            pomodoroComplete.shown = true;
        }
    }
    PomodoroCompleteOverlay {
        id: pomodoroComplete
        style: layer.style
        languageMode: layer.languageMode
        onClosed: pomodoroComplete.shown = false
    }
}
