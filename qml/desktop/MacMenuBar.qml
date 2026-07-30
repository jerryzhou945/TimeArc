import QtQuick
import QtQuick.Window
import Qt.labs.platform as Platform
import "components/I18n.js" as I18n

// macOS 应用菜单栏（屏幕顶端那条）。设计文档：docs/macos-menu-bar-design.md。
//
// 只在 macOS 存在：main.qml 用 appWindow.macSidebarChrome 门控 Loader，
// Windows/Linux 一个对象也不创建，继续用自绘 chrome + Qt.labs.platform 托盘。
//
// 为什么放 QML 而不是 C++ 的 QMenuBar：这里每条命令的目标都是 Shell 的 QML 状态
// （selectedIndex / memoOverlay / nightMode / languageMode），放 QML 可以直接调
// I18n.js 取三语文案，不必像 macos_status_bar_icon.cpp 那样另抄一份字符串表。
//
// 状态栏图标（T 字形）与本菜单栏分工：状态栏只管「窗口没了，把我放回去/退出」，
// 无论 TimeArc 是否在前台都可见；菜单栏管「TimeArc 在前台时能对它做什么」。
Platform.MenuBar {
    id: bar

    // main.qml 的 ApplicationWindow 与 shellLoader.item（DesktopAppShell）。
    // 名字刻意不叫 appWindow / shell：main.qml 那边的 id 就是 appWindow，
    // 写成 `appWindow: appWindow` 时右侧会先解析到本对象自己的同名属性，
    // 于是绑定成了自赋值、值恒为 null，所有依赖窗口的菜单项会一直置灰。
    property var hostWindow: null
    property var hostShell: null

    window: hostWindow

    // 红灯只关窗口、进程仍在，菜单栏因此比窗口活得久。这种状态下需要窗口或 Shell 的
    // 命令一律置灰，而不是顺手把窗口拉回来——误点一下就在用户当前 Space 弹出窗口更糟。
    // 「窗口」菜单里的 TimeArc 一行才是回来的入口。
    readonly property bool hasWindow: hostWindow !== null && hostWindow.visible
    readonly property bool hasShell: hostShell !== null
    // 备忘黑板是全屏模态：开着时换页置灰（底层页面要原样留在身后），只留它自己的开关。
    // 关窗不再置灰——交通灯在黑板上也常显，红灯可点而 ⌘W 置灰会让鼠标与键盘各说一套。
    readonly property bool memoOpen: hasShell && hostShell.memoOpen
    // 设置页的快捷键键帽正在等按键：整条菜单栏让位，否则 AppKit 会先把 ⌘ 组合当成 key
    // equivalent 执行掉（⌘Q 直接退应用），键帽永远等不到那一下。置灰的 NSMenuItem 不吃
    // 自己的 key equivalent，按键于是落回窗口，由键帽收下并给出「已被 X 占用」的提示。
    // 「编辑」菜单不必额外处理：焦点在键帽（不是文本控件）上，下面那些 editorCanXxx 本就为假。
    // 例外是 ⌃⌘F —— 与系统自己注入的「进入全屏幕」同键，那一行不是 Qt 建的，关不掉。
    readonly property bool capturing: hasShell && hostShell.hotkeyCapturing
    readonly property bool canNavigate: hasWindow && hasShell && !memoOpen && !capturing
    // 记忆卡翻面时不可开黑板：与字母快捷键同一个守卫（DesktopAppShell.memoLocked）。
    readonly property bool canToggleMemo: hasWindow && hasShell && !hostShell.memoLocked && !capturing
    // 番茄钟与备忘黑板已解耦：它不再是黑板的一部分，故不跟着记忆卡翻面锁一起置灰。
    readonly property bool canTogglePomodoro: hasWindow && hasShell && !capturing
    // 窗口类命令（关窗 / 最小化 / 缩放）：窗口在，且不在捕获态。
    readonly property bool canWindowCmd: hasWindow && !capturing
    // 统计导出导的是「当前视图的期次」，页面不在眼前就没有意义，故只在统计页可用。
    readonly property bool onStatsPage: pageIs("stats")

    // The menu bar is built before shellLoader has an item, so the fallback has
    // to read the stored language itself. A hardcoded "zh" here titled every
    // menu in Chinese for the first moments of an English/Japanese session —
    // long enough for AppKit to adopt the briefly-Chinese 编辑 menu, fill it
    // with Chinese rows and keep that title, while 显示/帮助 (matched later,
    // once the titles were right) got nothing.
    readonly property string lang: hasShell
                                   ? hostShell.languageMode
                                   : (settingsRepository
                                      ? settingsRepository.languageMode()
                                      : "en")

    function tr(source) {
        return I18n.menu(lang, source);
    }

    // Pinning AppKit's language has exactly one input: the shell's persisted
    // languageMode. `lang` above must never reach the native side — it carries
    // a pre-shell fallback, and a display fallback driving process-wide state
    // is what let a transient value get pinned. Startup is pinned once by
    // main.cpp from the same setting; this handles later changes only.
    Connections {
        target: bar.hostShell
        ignoreUnknownSignals: true
        function onLanguageModeChanged() {
            if (macMenuLocalizer)
                macMenuLocalizer.setLanguage(bar.hostShell.languageMode);
        }
    }

    function pageIs(key) {
        return hasShell && hostShell.selectedPage === key && !hostShell.showingTimerPage;
    }

    // 「编辑」菜单转发目标：Qt.labs.platform 没有剪切/拷贝/粘贴的原生 role，而 QML 的
    // TextInput 不是 NSResponder，系统的 cut:/copy: 送不到它，所以这几行自己转发给当前
    // 焦点控件。焦点不在文本控件上时下面的 canXxx 全为假，菜单项置灰。
    readonly property var editor: hostWindow ? hostWindow.activeFocusItem : null
    readonly property bool editorEditable: editor !== null && ("readOnly" in editor)
                                           && !editor.readOnly
    readonly property bool editorHasSelection: editor !== null && ("selectedText" in editor)
                                               && editor.selectedText.length > 0
    readonly property bool editorCanUndo: editor !== null && ("canUndo" in editor) && editor.canUndo
    readonly property bool editorCanRedo: editor !== null && ("canRedo" in editor) && editor.canRedo
    readonly property bool editorCanPaste: editor !== null && ("canPaste" in editor) && editor.canPaste
    readonly property bool editorCanSelectAll: editor !== null && ("selectAll" in editor)

    // 缩放（绿灯的非全屏语义）。全屏态不参与：那时窗口尺寸由系统管。
    function toggleZoom() {
        if (!hostWindow || hostWindow.visibility === Window.FullScreen)
            return;
        hostWindow.visibility = hostWindow.visibility === Window.Maximized ? Window.Windowed
                                                                         : Window.Maximized;
    }

    // 勾选态在菜单打开的那一刻推入，而不是绑定：Qt.labs.platform 的可勾选项在被点击时
    // 会自己写 checked，绑定会就此断掉、勾号从此定格。菜单不打开时不可见，推一次即可。
    // （macos_status_bar_icon.cpp 的 aboutToShow 重贴文案是同一套理由。）
    function syncViewChecks() {
        navMemoryLakeItem.checked = pageIs("memorylake");
        navCalendarItem.checked = pageIs("calendar");
        navStatsItem.checked = pageIs("stats");
        navRecapItem.checked = pageIs("recap");
        memoItem.checked = memoOpen;
        nightModeItem.checked = hasShell && hostShell.nightMode;
        langZhItem.checked = lang === "zh";
        langEnItem.checked = lang === "en";
        langJaItem.checked = lang === "ja";
    }

    function syncWindowChecks() {
        mainWindowItem.checked = hasWindow;
    }

    Platform.Menu {
        title: bar.tr("文件")

        // 这三行带 role：macOS 会把它们合并进左上角的 TimeArc 应用菜单（Qt 的
        // QCocoaMenuItem 接管应用菜单里现成的「关于」「设置…」「退出」三项），因此它们不会
        // 留在「文件」里显示。声明自己的退出项是为了走 quitFromTray()——默认的退出项
        // 绕过 forceQuit，会撞上 main.qml 里「关窗口不退进程」的 onClosing 拦截。
        //
        // 注意：合并后这三行的文案由 Qt Cocoa 接管。mergeText() 从 Qt Base 的
        // MAC_APPLICATION_MENU 目录取词；MacMenuLocalizer 把该目录同步到 language_mode。
        // 下面的 text 仍是角色合并前的回退值，shortcut 与 onTriggered 始终由这里提供。
        Platform.MenuItem {
            role: Platform.MenuItem.AboutRole
            text: bar.tr("关于 TimeArc")
            enabled: bar.hasShell && !bar.memoOpen && !bar.capturing
            onTriggered: {
                if (!bar.hasWindow && bar.hostWindow)
                    bar.hostWindow.restoreFromTray();
                bar.hostShell.menuOpenAbout();
            }
        }
        Platform.MenuItem {
            role: Platform.MenuItem.PreferencesRole
            text: bar.tr("设置…")
            shortcut: "Ctrl+,"
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuNavigateTo("settings")
        }
        Platform.MenuItem {
            role: Platform.MenuItem.QuitRole
            text: bar.tr("退出 TimeArc")
            shortcut: "Ctrl+Q"
            enabled: !bar.capturing
            onTriggered: {
                if (bar.hostWindow)
                    bar.hostWindow.quitFromTray();
            }
        }

        // 以下各行显式 NoRole：默认的 TextHeuristicRole 会按词头（settings/options/
        // quit…）猜测该不该并进应用菜单，而这里几条英文文案正好含这些词。
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("导出统计报告…")
            shortcut: "Ctrl+Shift+E"
            enabled: bar.canNavigate && bar.onStatsPage
            onTriggered: bar.hostShell.menuExportStatsReport()
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("导入设置…")
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuRunSettingsAction("openImportDialog")
        }
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("导出设置…")
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuRunSettingsAction("doExport")
        }
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("备份数据库…")
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuRunSettingsAction("doBackupDatabase")
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("关闭窗口")
            shortcut: "Ctrl+W"
            enabled: bar.canWindowCmd
            onTriggered: bar.hostWindow.close()
        }
    }

    Platform.Menu {
        title: bar.tr("编辑")

        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("撤销")
            shortcut: "Ctrl+Z"
            enabled: bar.editorCanUndo
            onTriggered: bar.editor.undo()
        }
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("重做")
            shortcut: "Ctrl+Shift+Z"
            enabled: bar.editorCanRedo
            onTriggered: bar.editor.redo()
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("剪切")
            shortcut: "Ctrl+X"
            enabled: bar.editorHasSelection && bar.editorEditable
            onTriggered: bar.editor.cut()
        }
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("复制")
            shortcut: "Ctrl+C"
            enabled: bar.editorHasSelection
            onTriggered: bar.editor.copy()
        }
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("粘贴")
            shortcut: "Ctrl+V"
            enabled: bar.editorCanPaste
            onTriggered: bar.editor.paste()
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("全选")
            shortcut: "Ctrl+A"
            enabled: bar.editorCanSelectAll
            onTriggered: bar.editor.selectAll()
        }
    }

    Platform.Menu {
        title: bar.tr("显示")
        onAboutToShow: bar.syncViewChecks()

        Platform.MenuItem {
            id: navMemoryLakeItem
            role: Platform.MenuItem.NoRole
            text: bar.tr("首页")
            shortcut: "Ctrl+1"
            checkable: true
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuNavigateTo("memorylake")
        }
        Platform.MenuItem {
            id: navCalendarItem
            role: Platform.MenuItem.NoRole
            text: bar.tr("日历")
            shortcut: "Ctrl+2"
            checkable: true
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuNavigateTo("calendar")
        }
        Platform.MenuItem {
            id: navStatsItem
            role: Platform.MenuItem.NoRole
            text: bar.tr("统计")
            shortcut: "Ctrl+3"
            checkable: true
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuNavigateTo("stats")
        }
        Platform.MenuItem {
            id: navRecapItem
            role: Platform.MenuItem.NoRole
            text: bar.tr("记忆湖")
            shortcut: "Ctrl+4"
            checkable: true
            enabled: bar.canNavigate
            onTriggered: bar.hostShell.menuNavigateTo("recap")
        }
        Platform.MenuSeparator {}

        // 备忘/番茄的字母键（默认 N / P，设置页可改）原样保留，这里是额外的等价键：
        // 单个字母做不了菜单快捷键——菜单会在焦点中的文本框看到按键之前就吃掉它，
        // 正是 Shell 里 Keys.onShortcutOverride 要解决的那个问题。
        Platform.MenuItem {
            id: memoItem
            role: Platform.MenuItem.NoRole
            text: bar.tr("备忘黑板")
            shortcut: "Ctrl+Shift+N"
            checkable: true
            enabled: bar.canToggleMemo
            onTriggered: bar.hostShell.menuToggleMemo()
        }
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("番茄钟")
            shortcut: "Ctrl+Shift+P"
            enabled: bar.canTogglePomodoro
            onTriggered: bar.hostShell.menuTogglePomodoro()
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            id: nightModeItem
            role: Platform.MenuItem.NoRole
            text: bar.tr("夜间模式")
            shortcut: "Ctrl+Shift+D"
            checkable: true
            enabled: bar.hasWindow && bar.hasShell && !bar.capturing
            onTriggered: bar.hostShell.menuToggleNightMode()
        }
        Platform.Menu {
            title: bar.tr("界面语言")

            // 语言名一律用该语言自己的写法（macOS 惯例），不随界面语言翻译。
            Platform.MenuItem {
                id: langZhItem
                role: Platform.MenuItem.NoRole
                text: "中文"
                checkable: true
                enabled: bar.hasWindow && bar.hasShell
                onTriggered: bar.hostShell.menuSetLanguage("zh")
            }
            Platform.MenuItem {
                id: langEnItem
                role: Platform.MenuItem.NoRole
                text: "English"
                checkable: true
                enabled: bar.hasWindow && bar.hasShell
                onTriggered: bar.hostShell.menuSetLanguage("en")
            }
            Platform.MenuItem {
                id: langJaItem
                role: Platform.MenuItem.NoRole
                text: "日本語"
                checkable: true
                enabled: bar.hasWindow && bar.hasShell
                onTriggered: bar.hostShell.menuSetLanguage("ja")
            }
        }
    }

    Platform.Menu {
        title: bar.tr("窗口")
        onAboutToShow: bar.syncWindowChecks()

        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("最小化")
            shortcut: "Ctrl+M"
            enabled: bar.canWindowCmd
            onTriggered: bar.hostWindow.showMinimized()
        }
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("缩放")
            enabled: bar.canWindowCmd
            onTriggered: bar.toggleZoom()
        }
        Platform.MenuSeparator {}

        // 窗口被红灯关掉后，这一行是菜单栏自己的回程（Dock 图标与状态栏菜单之外）。
        Platform.MenuItem {
            id: mainWindowItem
            role: Platform.MenuItem.NoRole
            text: "TimeArc"
            checkable: true
            onTriggered: {
                if (bar.hostWindow)
                    bar.hostWindow.restoreFromTray();
            }
        }
    }

    Platform.Menu {
        title: bar.tr("帮助")

        // 隐私可见性：TimeArc 只记录时间上下文且全部落在本地，「东西到底存在哪」
        // 应该是一次点击，而不是一句支持话术。
        Platform.MenuItem {
            role: Platform.MenuItem.NoRole
            text: bar.tr("在 Finder 中显示数据文件夹")
            enabled: databaseManager !== null
                     && typeof databaseManager.currentDatabaseLocationDir === "function"
            onTriggered: {
                var dir = "" + databaseManager.currentDatabaseLocationDir();
                if (dir.length > 0)
                    Qt.openUrlExternally("file://" + encodeURI(dir));
            }
        }
    }
}
