import QtQuick
import QtQuick.Controls
import QtQuick.Window
import time_arc

ApplicationWindow {
    id: appWindow

    property bool runningOnAndroid: Qt.platform.os === "android"
    property bool useMobileShell: runningOnAndroid || mobilePreview || width <= 720
    property bool forceQuit: false
    // macOS 不参与「关闭即收进托盘」：红灯按平台惯例只关窗口，进程留在 Dock/菜单栏，
    // ⌘Q 或状态栏菜单才退出。Windows/Linux 维持原托盘行为。
    property bool hideToTrayOnClose: !(runningOnAndroid || mobilePreview
                                       || macSidebarChrome)
    readonly property bool macSidebarChrome: Qt.platform.os === "osx"
                                              && !mobilePreview
    readonly property bool memoOpen: shellLoader.item
                                     && ("memoOpen" in shellLoader.item)
                                     && shellLoader.item.memoOpen

    // Qt 6.9+ automatically pads ApplicationWindow.contentItem by the native
    // safe-area margins. On macOS our sidebar intentionally occupies that area
    // behind the window-owned traffic lights, so do not reserve the title inset.
    topPadding: runningOnAndroid
                ? 0 : (macSidebarChrome ? 0 : SafeArea.margins.top)
    bottomPadding: runningOnAndroid ? 0 : SafeArea.margins.bottom
    leftPadding: runningOnAndroid ? 0 : SafeArea.margins.left
    rightPadding: runningOnAndroid ? 0 : SafeArea.margins.right

    // Windows/其他桌面使用无边框自绘 chrome；macOS 保留有标题能力的原生窗口，
    // 再由 AppKit 把内容延伸到透明标题区。这样侧栏仍铺到顶边，但交通灯由系统窗口自己管理。
    // 移动预览（开发工具）保留原生边框，方便挪窗/关闭。
    // MinMaxButtonsHint：即便无边框，Windows 仍启用最小化动画 + Win+方向键贴靠。
    readonly property bool desktopChrome: !(runningOnAndroid || mobilePreview)
    readonly property bool frameless: desktopChrome && !macSidebarChrome
    readonly property int macWindowFlags:
        Qt.Window
        | Qt.WindowTitleHint
        | Qt.WindowSystemMenuHint
        | Qt.WindowMinMaxButtonsHint
        | Qt.WindowCloseButtonHint
        | Qt.WindowFullscreenButtonHint
        | Qt.ExpandedClientAreaHint
        | Qt.NoTitleBarBackgroundHint
    flags: macSidebarChrome
           ? macWindowFlags
           : (frameless
              ? (Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinMaxButtonsHint)
              : Qt.Window)
    // 自绘标题栏高度 = 各 shell 顶部为交互内容预留的高度（背景仍铺到顶边，保沉浸）。
    readonly property int chromeReserve: desktopChrome ? 40 : 0

    // 桌面默认 16:9（1440x810），可自由缩放、全屏铺满（不再锁 16:10——那会让 16:9 屏右侧露桌面）。
    // 最小取 1280x720（标准 16:9 下限）：记忆湖三栏需 ~1240px 宽中间卡牌才不会被左右栏遮住；
    // 960 宽时 300+310 两栏几乎贴合、中卡被遮（实测），故以 1280x720 作可用下限。
    width: useMobileShell ? 390 : 1440
    height: useMobileShell ? 844 : 810
    minimumWidth: useMobileShell ? 360 : 1280
    minimumHeight: useMobileShell ? 600 : 720
    visible: !startInTray
    title: qsTr("TimeArc")
    color: "#F6F1EA"
    font.family: Qt.platform.os === "windows"
                 ? "Microsoft YaHei UI"
                 : (Qt.platform.os === "android" ? "HarmonyOS Sans SC" : "PingFang SC")

    function restoreFromTray() {
        // macOS 上窗口可能已被真正关闭（平台窗口销毁），交给原生适配器重建再激活。
        if (macSidebarChrome && macAppLifecycle) {
            macAppLifecycle.restoreWindow()
            return
        }
        visible = true
        if (visibility === Window.Minimized)
            showNormal()
        raise()
        requestActivate()
    }

    // 状态栏「番茄钟 mm:ss」：浮窗长在窗口的 QML 树里，窗口不回来点了也看不见，
    // 故先复原窗口再让它显示。
    function showPomodoroFromTray() {
        restoreFromTray()
        if (shellLoader.item && shellLoader.item.menuShowPomodoro)
            shellLoader.item.menuShowPomodoro()
    }

    function quitFromTray() {
        forceQuit = true
        Qt.quit()
    }

    // G-WIN 恢复窗口位置：关闭时保存归一化几何（仅普通窗口态——无边框最大化的 visibility 报
    // FullScreen，跳过以免存成全屏尺寸），启动时按「启动时恢复上次位置」恢复。只写 UI 私有
    // 设置 KV，不动 usage/磁盘契约。移动预览不参与。
    Component.onCompleted: {
        // 交通灯常显（含备忘黑板打开时）：AppKit 把它们画在标题栏视图里，天然叠在 QML 内容
        // 之上，黑板不需要也不该把它们藏掉——最小化/缩放/关窗是窗口级能力，不随页面消失。
        // 黑板侧只负责让自己的左上角 chrome 躲开按钮带（见 MemoOverlay.macSidebarChrome）。
        if (macSidebarChrome && macTrafficLightsController)
            macTrafficLightsController.setVisible(true)
        if (mobilePreview || !settingsRepository) return;
        if (!settingsRepository.getBool("restore_window", true)) return;
        var w = parseInt(settingsRepository.getValue("window_width", ""));
        var h = parseInt(settingsRepository.getValue("window_height", ""));
        var px = parseInt(settingsRepository.getValue("window_x", ""));
        var py = parseInt(settingsRepository.getValue("window_y", ""));
        // 钳进当前屏幕：尺寸不超可用桌面、不低于最小；位置须落在虚拟桌面内（留可见余量），
        // 否则显示器变更/拔除后无边框窗口会飞出屏外且难拖回。
        if (!isNaN(w)) width = Math.max(minimumWidth, Math.min(w, Screen.desktopAvailableWidth));
        if (!isNaN(h)) height = Math.max(minimumHeight, Math.min(h, Screen.desktopAvailableHeight));
        if (!isNaN(px) && !isNaN(py)) {
            var maxX = Screen.virtualX + Screen.virtualWidth - 80;
            var maxY = Screen.virtualY + Screen.virtualHeight - 80;
            if (px >= Screen.virtualX && px <= maxX && py >= Screen.virtualY && py <= maxY) {
                x = px; y = py;
            }
        }
    }
    onClosing: function (close) {
        // 红灯在黑板上也可点，关窗随时可能落在两笔之间：先把备忘的 600ms 防抖存盘强制落地，
        // 否则「关窗口不退进程」这条路径会静静吃掉最后一笔（⌘Q / 收托盘同理）。
        if (shellLoader.item && shellLoader.item.flushMemoDoc)
            shellLoader.item.flushMemoDoc()
        if (!mobilePreview && settingsRepository && visibility === Window.Windowed) {
            settingsRepository.setValue("window_width", "" + Math.round(width));
            settingsRepository.setValue("window_height", "" + Math.round(height));
            settingsRepository.setValue("window_x", "" + Math.round(x));
            settingsRepository.setValue("window_y", "" + Math.round(y));
        }
        // macOS：红灯关窗口而非退出。全屏态必须先退出全屏再关，否则留下黑屏 Space；
        // beginWindowClose() 返回 false 表示本次关闭被推迟，动画结束后原生侧再关一次。
        if (macSidebarChrome && macAppLifecycle && !forceQuit) {
            close.accepted = macAppLifecycle.beginWindowClose()
            return
        }
        if (hideToTrayOnClose && !forceQuit) {
            close.accepted = false
            hide()
            if (shellLoader.item && shellLoader.item.notifyClosedToTray)
                shellLoader.item.notifyClosedToTray()
        }
    }

    Loader {
        id: shellLoader
        anchors.fill: parent
        sourceComponent: useMobileShell ? mobileShell : desktopShell
    }

    // macOS 应用菜单栏（屏幕顶端）。仅 macOS 激活：其他平台不创建任何
    // Qt.labs.platform.MenuBar，自绘 chrome 与托盘行为原样不变。
    Loader {
        id: macMenuBarLoader
        active: appWindow.macSidebarChrome
        sourceComponent: Component {
            MacMenuBar {
                hostWindow: appWindow
                hostShell: shellLoader.item
            }
        }
    }

    // macOS 额外的全屏键 ⌃⌘F。系统自己往「显示」菜单里注入的「进入全屏幕」一行、以及
    // 那一行的系统按键，原样保留（docs/macos-menu-bar-design.md §4.1）——这里只补一个
    // 等价键，不再画第二行菜单：同一条命令在同一张菜单里出现两次比缺个快捷键更糟。
    // Qt 在 macOS 上交换 Ctrl/Meta：Ctrl→⌘、Meta→⌃，故 "Ctrl+Meta+F" 即 ⌃⌘F。
    // 与菜单栏同样用 Loader 门控：Windows/Linux 一个对象也不创建。包一层 Item 是为了让
    // Shortcut 的 WindowShortcut 上下文能沿可视父链找到本窗口。
    Loader {
        active: appWindow.macSidebarChrome && macAppLifecycle
        sourceComponent: Component {
            Item {
                Shortcut {
                    sequences: ["Ctrl+Meta+F"]
                    onActivated: macAppLifecycle.toggleFullScreen()
                }
            }
        }
    }

    Component {
        id: desktopShell

        DesktopAppShell {
            anchors.fill: parent
            topReserve: appWindow.chromeReserve
            macSidebarChrome: appWindow.macSidebarChrome
            onTrayShowRequested: appWindow.restoreFromTray()
            onTrayQuitRequested: appWindow.quitFromTray()
        }
    }

    Component {
        id: mobileShell

        MobileAppShell {
            anchors.fill: parent
            topReserve: appWindow.chromeReserve
        }
    }

    // 自定义窗口 chrome（无边框时）：浮在所有 shell 之上、中心穿透。
    // 备忘黑板为全屏模态（自带退出 + 顶部工具条/档案袋），开启时让位隐藏，避免顶部冲突。
    WindowChrome {
        anchors.fill: parent
        window: appWindow
        barHeight: appWindow.chromeReserve
        iconSource: appWindow.macSidebarChrome
                    ? "" : Qt.resolvedUrl("../resources/app/TimeArc.svg")
        dark: shellLoader.item && ("prefersLightChrome" in shellLoader.item)
              ? shellLoader.item.prefersLightChrome : false
        showWindowControls: !appWindow.macSidebarChrome
        captionLeftInset: appWindow.macSidebarChrome ? 88 : 0
        visible: appWindow.frameless
                 && !appWindow.memoOpen
    }
}
